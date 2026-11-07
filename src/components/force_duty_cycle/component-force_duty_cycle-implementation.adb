--------------------------------------------------------------------------------
-- Force_Duty_Cycle Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Force_Duty_Cycle.Implementation is

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
   -- Apply one control period of the duty cycle to the commanded force.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The commanded force is produced by the burn executor earlier in the same
      -- tick, so any other status indicates that this component is not wired up
      -- correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Force_Dep : Cmd_Force_Body.T;
      Force_Status : constant Data_Dependency_Status.E :=
         Self.Get_Commanded_Force (Value => Force_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Force_Status = Success);

      -- The force vector crosses the FFI boundary as the three float record the
      -- shared binding takes. It crosses by pointer, so it needs an object to point at.
      Force_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Force_Dep.Force_Request_Body));
   begin
      -- Apply any pending parameter update (e.g. a new cadence):
      Self.Update_Parameters;

      -- Apply this control period of the duty cycle to the force and publish it. Update
      -- is qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Gated_Force (
         Arg.Time,
         (Force_Request_Body => Packed_F32x3.C.Pack (Vector_Duty_Cycle_Algorithm_C.Update (Self.Alg, Input_Vector => Force_C'Access).Value))
      ));
   end Tick_T_Recv_Sync;

   -- Restart the duty cycle at the beginning of its on window. The assembly fires
   -- this on a state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update first, so the reset starts from the
      -- configuration the component runs with next:
      Self.Update_Parameters;
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
   --    Parameters for the Force Duty Cycle component.
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
   --    Data dependencies for the Force Duty Cycle component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Force_Duty_Cycle.Implementation;
