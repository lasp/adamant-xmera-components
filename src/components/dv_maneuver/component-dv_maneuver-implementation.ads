--------------------------------------------------------------------------------
-- Dv_Maneuver Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameter_Update;
with Packed_F32x3;
with Packed_F64;
with Dv_Maneuver_Algorithm_C; use Dv_Maneuver_Algorithm_C;

-- Delta-V burn executor. Commands the configured body force while a burn executes
-- and zero once it is complete, and publishes the burn state. The burn times, the
-- commanded delta-V and the body force are parameters. The times and the delta-V
-- are set by the state manager when a burn is commanded, and the algorithm
-- validates them before they are applied. The burn starts at the first tick after
-- the component is built or reset, and completes when the accumulated delta-V
-- reaches the commanded one after the minimum burn time, or when the maximum burn
-- time is reached. Complete is terminal until the next reset, so the assembly
-- fires the reset when the burn is to start and ticks the component only while the
-- burn state is in use. Wraps the DvManeuverAlgorithm C++ algorithm via its C shim.
package Component.Dv_Maneuver.Implementation is

   -- The component class instance record:
   type Instance is new Dv_Maneuver.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V burn executor with the control period and the default
   -- parameter values, a stand-in burn which the first burn command replaces.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Long_Float - [s] Time between two
   -- algorithm updates. The burn time advances by this much per tick, so it must
   -- equal the rate at which the component is scheduled. Fixed by the assembly, so it
   -- is not a runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Long_Float);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Dv_Maneuver.Base_Instance with record
      Alg : Dv_Maneuver_Algorithm_Access := null;
      -- [s] Time between two algorithm updates, supplied by the assembly at
      -- initialization. The default keeps the configuration valid for the generated
      -- parameter default check, which runs before Init.
      Control_Period : Basic_Types.Positive_Long_Float := 0.2;
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
   -- Advance the burn one step and publish the force command and the burn state.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- Restart the burn at the next tick. The assembly fires this when the burn is to
   -- start.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Dv Maneuver component. The body force depends on the
   --    thrusters in use, so it is set for a mission phase rather than per burn. The
   --    burn times and the commanded delta-V define a burn, so they are set when a
   --    burn is commanded, before the burn is started with the reset. The defaults
   --    form a valid configuration and stand in until then.

   -- Invalid parameter handler. This procedure is called when a parameter's type is found to be invalid:
   -- Null: the staging code rejects the value and returns an error status to the
   -- requester, which reports the offending parameter ID to the ground. That is sufficient, and
   -- we avoid adding per-component event overhead to these algorithm components.
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is null;
   -- This procedure is called when the parameters of a component have been updated. The default implementation of this
   -- subprogram in the implementation package is a null procedure. However, this procedure can, and should be implemented if
   -- something special needs to happen after a parameter update. Examples of this might be copying certain parameters to
   -- hardware registers, or performing other special functionality that only needs to be performed after parameters have
   -- been updated.
   overriding procedure Update_Parameters_Action (Self : in out Instance);
   -- This function is called when the parameter operation type is "Validate". The default implementation of this
   -- subprogram in the implementation package is a function that returns "Valid". However, this function can, and should be
   -- overridden if something special needs to happen to further validate a parameter. Examples of this might be validation of
   -- certain parameters beyond individual type ranges, or performing other special functionality that only needs to be
   -- performed after parameters have been validated. Note that range checking is performed during staging, and does not need
   -- to be implemented here. This function is also called through Assert_Valid_Parameter_Defaults from Set_Id_Bases and from
   -- unit test setup, before the component is connected or initialized, to check the compiled-in default parameter values. The
   -- implementation must therefore be a pure function of the passed-in parameter values, with no dependence on Init state and
   -- no connector invocations.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Cmd_Force_B : in Packed_F32x3.U;
      Min_Time : in Packed_F64.U;
      Max_Time : in Packed_F64.U;
      Cmd_Dv_N : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Dv Maneuver component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Dv_Maneuver.Implementation;
