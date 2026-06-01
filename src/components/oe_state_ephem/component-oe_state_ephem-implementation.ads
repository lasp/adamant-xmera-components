--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameters_Memory_Region;
with Oe_State_Ephem_Parameter_Table;
with Oe_State_Ephem_Algorithm_C; use Oe_State_Ephem_Algorithm_C;
with Protected_Variables;

-- Orbital element state ephemeris algorithm. Computes spacecraft Cartesian
-- state (position and velocity) from Chebyshev polynomial fits of classical
-- orbital elements. The algorithm's configuration (central body gravitational
-- parameter and per-arc Chebyshev coefficients) is delivered as a single
-- Oe_State_Ephem_Parameter_Table payload via a Parameter_Table_Forwarder
-- upstream; the component validates the bytes, stages them on a protected
-- area, and applies them to the algorithm on the next tick.
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

   -- Generic protected staging area instantiated for the parameter table.
   -- The Service handler (forwarder task) calls Stage when a validated
   -- payload arrives; the tick task drains it via Copy_From_Staged just
   -- before evaluating the algorithm.
   package Staged_Table_Pkg is new Protected_Variables.Generic_Staged_Variable
      (T => Oe_State_Ephem_Parameter_Table.T);

   -- The component class instance record:
   type Instance is new Oe_State_Ephem.Base_Instance with record
      Alg : Oe_State_Ephem_Algorithm_Access := null;
      Staged_Parameters : Staged_Table_Pkg.Staged_Variable;
      -- Dedicated dump buffer. Service handler's Get_Pointer fills this
      -- in-place from the C++ algorithm getters and returns its address.
      Dump_Buffer : Oe_State_Ephem_Parameter_Table.T;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time. Also drains the staged parameter
   -- table (if any) and applies it to the algorithm before evaluating.
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
