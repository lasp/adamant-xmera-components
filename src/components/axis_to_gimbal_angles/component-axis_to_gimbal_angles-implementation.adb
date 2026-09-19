--------------------------------------------------------------------------------
-- Axis_To_Gimbal_Angles Component Implementation Body
--------------------------------------------------------------------------------

with Axis_To_Gimbal_Angles_Output.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Axis_To_Gimbal_Angles.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the axis to gimbal angles algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
      -- The mount attitude crosses by pointer, so it needs an object to point at.
      Sigma_Mb_C : aliased constant Packed_F32x3_Record.C.U_C :=
         (Value => Packed_F32x3.C.To_C (Self.Sigma_Mb));
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Sigma_Mb  => Sigma_Mb_C'Access,
         Theta_Max => Self.Theta_Max.Value);
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
      -- The thrust direction is produced by the thrust vectoring component earlier in
      -- the same tick, so any other status indicates that this component is not wired
      -- up correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Direction : Packed_F32x3.T;
      Direction_Status : constant Data_Dependency_Status.E :=
         Self.Get_Thrust_Direction (Value => Direction, Stale_Reference => Arg.Time);
      pragma Assert (Direction_Status = Success);

      -- The direction crosses by pointer, so it needs an object to point at.
      Direction_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Direction));
   begin
      -- Apply any pending parameter update (e.g. a new mount attitude or travel):
      Self.Update_Parameters;

      -- Solve for the gimbal angles and publish them with the direction they achieve.
      -- Update is qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Gimbal_Command (
         Arg.Time,
         Axis_To_Gimbal_Angles_Output.C.Pack (
            Axis_To_Gimbal_Angles_Algorithm_C.Update (Self.Alg, Thrust_Hat_B => Direction_C'Access))
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
   --    Parameters for the Axis To Gimbal Angles component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- The mount attitude crosses by pointer, so it needs an object to point at.
      Sigma_Mb_C : aliased constant Packed_F32x3_Record.C.U_C :=
         (Value => Packed_F32x3.C.To_C (Self.Sigma_Mb));
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Sigma_Mb  => Sigma_Mb_C'Access,
         Theta_Max => Self.Theta_Max.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sigma_Mb : in Packed_F32x3.U;
      Theta_Max : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- The mount attitude crosses by pointer, so it needs an object to point at. It is
      -- filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Sigma_Mb_C : aliased Packed_F32x3_Record.C.U_C;
   begin
      Sigma_Mb_C := (Value => Packed_F32x3.C.To_C (Sigma_Mb));
      if Validate_Config (
         Sigma_Mb  => Sigma_Mb_C'Access,
         Theta_Max => Theta_Max.Value)
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
   --    Data dependencies for the Axis To Gimbal Angles component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Axis_To_Gimbal_Angles.Implementation;
