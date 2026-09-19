--------------------------------------------------------------------------------
-- Thrust_Vectoring Component Implementation Body
--------------------------------------------------------------------------------

with Cmd_Torque_Body;
with Cmd_Torque_Body.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Thrust_Vectoring.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thrust vectoring algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
      -- The thrust point and center of mass cross by pointer, so they need objects to
      -- point at.
      R_Mb_B_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.To_C (Self.R_Mb_B));
      R_Cb_B_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.To_C (Self.R_Cb_B));
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         R_Mb_B => R_Mb_B_C'Access,
         Thrust => Self.Thrust.Value,
         R_Cb_B => R_Cb_B_C'Access);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The torque request is produced by the control law earlier in the same tick,
      -- so any other status indicates that this component is not wired up correctly in
      -- the algorithm execution order. That should never happen, so we assert.
      Torque : Cmd_Torque_Body.T;
      Torque_Status : constant Data_Dependency_Status.E :=
         Self.Get_Torque_Request (Value => Torque, Stale_Reference => Arg.Time);
      pragma Assert (Torque_Status = Success);

      -- The request crosses by pointer, so it needs an object to point at.
      Torque_C : aliased constant Packed_F32x3_Record.C.U_C :=
         (Value => Cmd_Torque_Body.C.Unpack (Torque).Torque_Request_Body);
   begin
      -- Apply any pending parameter update (e.g. a new center of mass):
      Self.Update_Parameters;

      -- Point the thrust and publish its direction. Update is qualified because
      -- Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Thrust_Direction (
         Arg.Time,
         Packed_F32x3.C.Pack (Thrust_Vectoring_Algorithm_C.Update (Self.Alg, Lreq_B => Torque_C'Access).Value)
      ));
   end Tick_T_Recv_Sync;

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
   --    Parameters for the Thrust Vectoring component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- The thrust point and center of mass cross by pointer, so they need objects to
      -- point at.
      R_Mb_B_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.To_C (Self.R_Mb_B));
      R_Cb_B_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.To_C (Self.R_Cb_B));
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         R_Mb_B => R_Mb_B_C'Access,
         Thrust => Self.Thrust.Value,
         R_Cb_B => R_Cb_B_C'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      R_Mb_B : in Packed_F32x3.U;
      Thrust : in Packed_F32.U;
      R_Cb_B : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- The thrust point and center of mass cross by pointer, so they need objects to
      -- point at. They are filled in below, inside the handled part of the function,
      -- so that a conversion that raises is caught here.
      R_Mb_B_C : aliased Packed_F32x3_Record.C.U_C;
      R_Cb_B_C : aliased Packed_F32x3_Record.C.U_C;
   begin
      R_Mb_B_C := (Value => Packed_F32x3.C.To_C (R_Mb_B));
      R_Cb_B_C := (Value => Packed_F32x3.C.To_C (R_Cb_B));
      if Validate_Config (
         R_Mb_B => R_Mb_B_C'Access,
         Thrust => Thrust.Value,
         R_Cb_B => R_Cb_B_C'Access)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the set here keeps
      -- that from unwinding into the Parameters component.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Thrust Vectoring component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Thrust_Vectoring.Implementation;
