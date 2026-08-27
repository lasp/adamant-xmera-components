--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameters_Memory_Region;
with Oe_State_Ephem_Parameter_Table;
with Oe_State_Ephem_Algorithm_C; use Oe_State_Ephem_Algorithm_C;

-- Orbital element state ephemeris algorithm. Computes spacecraft Cartesian
-- state (position and velocity) from Chebyshev polynomial fits of classical
-- orbital elements. The algorithm's configuration (central body gravitational
-- parameter and per-arc Chebyshev coefficients) is delivered as a single
-- Oe_State_Ephem_Parameter_Table payload via a Parameter_Table_Forwarder
-- upstream; the component validates the bytes and the configuration when the
-- upload arrives, stages it in a heap-resident config object via the shim's
-- incremental builder interface, and applies it to the algorithm on the next
-- tick.
package Component.Oe_State_Ephem.Implementation is

   -- The component class instance record:
   type Instance is new Oe_State_Ephem.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the algorithm with a default parameter table. The component
   -- applies the default to the C++ algorithm immediately so that ticks
   -- arriving before any uploaded table is received still produce
   -- deterministic output.
   --
   -- Init Parameters:
   -- Default_Table : Oe_State_Ephem_Parameter_Table.T_Access - Pointer to a
   -- packed parameter table applied to the algorithm at startup. The
   -- component derefs it once during Init to push values into the C++
   -- algorithm; passing by access avoids any large by-value copy on the
   -- env task's stack at Init_Components time. Default_Table is overridden
   -- by any subsequent successful Set delivered via the parameter-region
   -- pathway.
   --
   overriding procedure Init (Self : in out Instance; Default_Table : not null Oe_State_Ephem_Parameter_Table.T_Access);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- Staging area for parameter tables, held in a heap-resident configuration
   -- object behind the shim's opaque config handle (allocated once at Init and
   -- reused, via reset, for every upload). The Service handler (forwarder task)
   -- builds a format-valid upload into the config through the shim's
   -- incremental interface (reset, scalars, then one arc at a time), and every
   -- one of those calls is validated by the algorithm's own configuration
   -- rules, so a rejected table is reported synchronously on the upload and
   -- only configurations the algorithm will accept are ever marked staged; the
   -- tick task then applies the staged configuration, which cannot fail.
   -- Holding the staging table behind the handle keeps it out of the component
   -- record entirely, and no step of staging or applying puts more than one
   -- ~1 KB arc on any task's stack.
   protected type Staged_Table is
      -- Allocate the config staging object and construct the algorithm from
      -- Default_Table, staging and validating it internally. The default comes
      -- from the assembly rather than the ground, so a configuration the
      -- algorithm would reject is a wiring error: asserted, not reported. Call
      -- exactly once, from the component's Init.
      procedure Init (Default_Table : in Oe_State_Ephem_Parameter_Table.T; Alg : out Oe_State_Ephem_Algorithm_Access);
      -- Build Table into the staging config and mark it staged (reporting
      -- Valid => True) only when every value is accepted by the algorithm's
      -- configuration rules, which is what keeps the throwing Create/Set_Config
      -- unreachable. A rejected table reports Valid => False and leaves nothing
      -- staged, including any earlier staged-but-unapplied table (the staging
      -- config is single and latest-wins).
      procedure Stage_If_Valid (Table : in Oe_State_Ephem_Parameter_Table.T; Valid : out Boolean);
      -- Push the staged configuration to the already-constructed algorithm via
      -- Set_Config and clear the staged flag. No-op with Applied => False when
      -- nothing is staged.
      procedure Apply_If_Staged (Alg : in Oe_State_Ephem_Algorithm_Access; Applied : out Boolean);
      -- Release the config staging object (teardown hygiene for unit tests).
      procedure Destroy;
   private
      -- The heap-resident staging config; see the type comment above.
      Config : Oe_State_Ephem_Config_Access := null;
      Is_Staged : Boolean := False;
   end Staged_Table;

   -- The component class instance record:
   type Instance is new Oe_State_Ephem.Base_Instance with record
      Alg : Oe_State_Ephem_Algorithm_Access := null;
      -- The staging area (see Staged_Table above); the staged table itself lives
      -- on the heap behind the shim's opaque config handle.
      Staged_Parameters : Staged_Table;
      -- Scratch for Get_Pointer dumps: filled from the algorithm's actual
      -- configuration on each dump request, so the algorithm remains the single
      -- source of truth and the component keeps no copy of the applied table.
      Dump_Buffer : Oe_State_Ephem_Parameter_Table.T;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time. Also applies the staged parameter
   -- table (if any) to the algorithm before evaluating.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- Inbound parameter table memory region from an upstream
   -- Parameter_Table_Forwarder; returns the operation status (Success,
   -- Parameter_Error, etc) synchronously. The forwarder has already stripped
   -- the parameter table header; the region contains only the
   -- Oe_State_Ephem_Parameter_Table payload bytes.
   overriding function Parameters_Memory_Region_T_Service (Self : in out Instance; Arg : in Parameters_Memory_Region.T) return Parameters_Memory_Region_Release.T;

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;
   -- This procedure is called when a Event_T_Send message is dropped due to a full queue.
   overriding procedure Event_T_Send_Dropped (Self : in out Instance; Arg : in Event.T) is null;

end Component.Oe_State_Ephem.Implementation;
