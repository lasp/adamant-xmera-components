--------------------------------------------------------------------------------
-- Dv_Accumulation Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Dv_Accumulation_Algorithm_C; use Dv_Accumulation_Algorithm_C;

-- Delta-V accumulation. Integrates the majority voted body frame acceleration that
-- gravity does not cause, one sample per tick over the control period, into the
-- delta-V accumulated since the last reset, and publishes it for the burn executor.
-- The first sample after a reset starts the accumulation window and is not
-- integrated, so the accumulated delta-V is the integral over the time elapsed
-- since then. The accelerometer bias is a data dependency, which the state manager
-- publishes from the command that set the burn up, and is subtracted from each
-- sample. Wraps the DvAccumulationAlgorithm C++ algorithm via its C shim.
package Component.Dv_Accumulation.Implementation is

   -- The component class instance record:
   type Instance is new Dv_Accumulation.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V accumulation algorithm with the control period.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates, the integration step of each sample, so it must equal the
   -- rate at which the component is scheduled. Fixed by the assembly, so it is not a
   -- runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Dv_Accumulation.Base_Instance with record
      Alg : Dv_Accumulation_Algorithm_Access := null;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   -- Null method which can be implemented to provide some component
   -- set up code. This method is generally called by the assembly
   -- main.adb after all component initialization and tasks have been started.
   -- Some activities need to only be run once at startup, but cannot be run
   -- safely until everything is up and running, i.e. command registration, initial
   -- data product updates. This procedure should be implemented to do these things
   -- if necessary.
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Integrate the acceleration of this tick and publish the accumulated delta-V.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- Zero the accumulated delta-V and start a new accumulation window at the next
   -- tick. The assembly fires this when a burn is set up, before the burn executor
   -- is started.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Dv Accumulation component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Dv_Accumulation.Implementation;
