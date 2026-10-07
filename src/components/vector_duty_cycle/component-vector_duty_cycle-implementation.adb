--------------------------------------------------------------------------------
-- Vector_Duty_Cycle Component Implementation Body
--------------------------------------------------------------------------------

with Cmd_Torque_Body.C;

package body Component.Vector_Duty_Cycle.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the duty cycle with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         On_Periods  => Self.On_Periods.Value,
         Off_Periods => Self.Off_Periods.Value);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Apply one control period of the duty cycle to the commanded torque.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The commanded torque is produced by momentum management earlier in the same
      -- tick, so any other status indicates that this component is not wired up
      -- correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Torque_Dep : Cmd_Torque_Body.T;
      Torque_Status : constant Data_Dependency_Status.E :=
         Self.Get_Commanded_Torque (Value => Torque_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Torque_Status = Success);

      -- The torque record is exactly the vector the shim takes, so the dependency
      -- crosses the FFI boundary unpacked, with no intermediate array. It crosses by
      -- pointer, so it needs an object to point at.
      Torque_C : aliased constant Cmd_Torque_Body.C.U_C := Cmd_Torque_Body.C.Unpack (Torque_Dep);
   begin
      -- Apply any pending parameter update (e.g. a new cadence):
      Self.Update_Parameters;

      -- Apply this control period of the duty cycle to the torque and publish it. Update
      -- is qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Gated_Torque (
         Arg.Time,
         Cmd_Torque_Body.C.Pack (Vector_Duty_Cycle_Algorithm_C.Update (Self.Alg, Input_Vector => Torque_C'Access))
      ));
   end Tick_T_Recv_Sync;

   -- Restart the duty cycle at the beginning of its on window. The assembly fires
   -- this on a state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Restarts the position in the cycle only; the configuration is untouched.
      Re_Initialize (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Vector Duty Cycle component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm. The position in the cycle is kept, so the
   -- new cycle length takes effect without restarting the cycle.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         On_Periods  => Self.On_Periods.Value,
         Off_Periods => Self.Off_Periods.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary. Both parameters are integers
   -- that cross the boundary as they are, so no marshalling here can raise.
   overriding function Validate_Parameters (
      Self : in out Instance;
      On_Periods : in Packed_U32.U;
      Off_Periods : in Packed_U32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
   begin
      if Validate_Config (
         On_Periods  => On_Periods.Value,
         Off_Periods => Off_Periods.Value)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Vector Duty Cycle component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Vector_Duty_Cycle.Implementation;
