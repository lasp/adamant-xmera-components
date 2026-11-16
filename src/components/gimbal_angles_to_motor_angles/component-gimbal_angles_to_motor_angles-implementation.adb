--------------------------------------------------------------------------------
-- Gimbal_Angles_To_Motor_Angles Component Implementation Body
--------------------------------------------------------------------------------

with Axis_To_Gimbal_Angles_Output;
with Gimbal_Angles_To_Motor_Angles_Output.C;
with Packed_F32x9x9;
with Spline_Coefficients.C;

package body Component.Gimbal_Angles_To_Motor_Angles.Implementation is

   -- The spline coefficient tables of the two motors. The shim takes each by pointer,
   -- so they are held together where a caller can pass 'Access of each field.
   type Coefficient_Tables is record
      Motor_1 : aliased Spline_Coefficients.C.U_C;
      Motor_2 : aliased Spline_Coefficients.C.U_C;
   end record;

   -- Marshal the coefficient rows of the two motors into their tables. Init,
   -- Update_Parameters_Action, and Validate_Parameters all marshal the same values,
   -- so it is done in one place.
   function To_Tables (Motor_1_Rows : in Packed_F32x9x9.U; Motor_2_Rows : in Packed_F32x9x9.U) return Coefficient_Tables is
      (Motor_1 => Spline_Coefficients.C.To_C ((Value => Motor_1_Rows)),
       Motor_2 => Spline_Coefficients.C.To_C ((Value => Motor_2_Rows)));

   -- Marshal the tables from the current values of the coefficient row parameters.
   function Parameter_Tables (Self : in Instance) return Coefficient_Tables is
      (To_Tables (
         Motor_1_Rows => [
            Self.Motor_1_Coefficients_Row_0, Self.Motor_1_Coefficients_Row_1, Self.Motor_1_Coefficients_Row_2,
            Self.Motor_1_Coefficients_Row_3, Self.Motor_1_Coefficients_Row_4, Self.Motor_1_Coefficients_Row_5,
            Self.Motor_1_Coefficients_Row_6, Self.Motor_1_Coefficients_Row_7, Self.Motor_1_Coefficients_Row_8],
         Motor_2_Rows => [
            Self.Motor_2_Coefficients_Row_0, Self.Motor_2_Coefficients_Row_1, Self.Motor_2_Coefficients_Row_2,
            Self.Motor_2_Coefficients_Row_3, Self.Motor_2_Coefficients_Row_4, Self.Motor_2_Coefficients_Row_5,
            Self.Motor_2_Coefficients_Row_6, Self.Motor_2_Coefficients_Row_7, Self.Motor_2_Coefficients_Row_8]));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the gimbal angles to motor angles algorithm with the default
   -- parameter values.
   overriding procedure Init (Self : in out Instance) is
      Tables : aliased constant Coefficient_Tables := Parameter_Tables (Self);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Steps_Per_Revolution => Self.Steps_Per_Revolution.Value,
         Half_Diagonal_Tip    => Self.Half_Diagonal_Tip.Value,
         Half_Diagonal_Tilt   => Self.Half_Diagonal_Tilt.Value,
         Theta_Max            => Self.Theta_Max.Value,
         Motor_1_Coefficients => Tables.Motor_1'Access,
         Motor_2_Coefficients => Tables.Motor_2'Access);
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
      -- The gimbal angles are produced by the axis to gimbal angles component earlier
      -- in the same tick, so any other status indicates that this component is not
      -- wired up correctly in the algorithm execution order. That should never happen,
      -- so we assert.
      Gimbal : Axis_To_Gimbal_Angles_Output.T;
      Gimbal_Status : constant Data_Dependency_Status.E :=
         Self.Get_Gimbal_Command (Value => Gimbal, Stale_Reference => Arg.Time);
      pragma Assert (Gimbal_Status = Success);

      -- Compute the motor angles. Update is qualified because Parameter_Enums also
      -- declares one.
      Motor_Angles : constant Gimbal_Angles_To_Motor_Angles_Output.T := Gimbal_Angles_To_Motor_Angles_Output.C.Pack (
         Gimbal_Angles_To_Motor_Angles_Algorithm_C.Update (
            Self.Alg,
            Gimbal_Angle_1 => Gimbal.Gimbal_Angle_1,
            Gimbal_Angle_2 => Gimbal.Gimbal_Angle_2));
   begin
      -- Publish each motor angle as its own data product:
      Self.Data_Product_T_Send (Self.Data_Products.Motor_1_Angle (Arg.Time, (Value => Motor_Angles.Motor_Angle_1)));
      Self.Data_Product_T_Send (Self.Data_Products.Motor_2_Angle (Arg.Time, (Value => Motor_Angles.Motor_Angle_2)));
   end Tick_T_Recv_Sync;

   -- Apply any pending parameter update and clear the last computed motor angles.
   -- Called on GNC state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update first, so the reset starts from the
      -- configuration the component runs with next:
      Self.Update_Parameters;
      Re_Initialize (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging, validating, updating, discarding, or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Gimbal Angles To Motor Angles component. The default rhombus
   --    and spline coefficients are a fit of an example gimbal-to-motor-steps lookup
   --    table.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm. The algorithm keeps its last computed
   -- motor angles.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Tables : aliased constant Coefficient_Tables := Parameter_Tables (Self);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Steps_Per_Revolution => Self.Steps_Per_Revolution.Value,
         Half_Diagonal_Tip    => Self.Half_Diagonal_Tip.Value,
         Half_Diagonal_Tilt   => Self.Half_Diagonal_Tilt.Value,
         Theta_Max            => Self.Theta_Max.Value,
         Motor_1_Coefficients => Tables.Motor_1'Access,
         Motor_2_Coefficients => Tables.Motor_2'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Steps_Per_Revolution : in Packed_U32.U;
      Half_Diagonal_Tip : in Packed_F32.U;
      Half_Diagonal_Tilt : in Packed_F32.U;
      Theta_Max : in Packed_F32.U;
      Motor_1_Coefficients_Row_0 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_1 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_2 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_3 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_4 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_5 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_6 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_7 : in Packed_F32x9.U;
      Motor_1_Coefficients_Row_8 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_0 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_1 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_2 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_3 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_4 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_5 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_6 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_7 : in Packed_F32x9.U;
      Motor_2_Coefficients_Row_8 : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Tables : aliased Coefficient_Tables;
   begin
      Tables := To_Tables (
         Motor_1_Rows => [
            Motor_1_Coefficients_Row_0, Motor_1_Coefficients_Row_1, Motor_1_Coefficients_Row_2,
            Motor_1_Coefficients_Row_3, Motor_1_Coefficients_Row_4, Motor_1_Coefficients_Row_5,
            Motor_1_Coefficients_Row_6, Motor_1_Coefficients_Row_7, Motor_1_Coefficients_Row_8],
         Motor_2_Rows => [
            Motor_2_Coefficients_Row_0, Motor_2_Coefficients_Row_1, Motor_2_Coefficients_Row_2,
            Motor_2_Coefficients_Row_3, Motor_2_Coefficients_Row_4, Motor_2_Coefficients_Row_5,
            Motor_2_Coefficients_Row_6, Motor_2_Coefficients_Row_7, Motor_2_Coefficients_Row_8]);
      if Validate_Config (
         Steps_Per_Revolution => Steps_Per_Revolution.Value,
         Half_Diagonal_Tip    => Half_Diagonal_Tip.Value,
         Half_Diagonal_Tilt   => Half_Diagonal_Tilt.Value,
         Theta_Max            => Theta_Max.Value,
         Motor_1_Coefficients => Tables.Motor_1'Access,
         Motor_2_Coefficients => Tables.Motor_2'Access)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the set here keeps
      -- that from unwinding into the Parameters component.
      -- TODO: The generated validation of the staged bytes should reject a non-finite
      -- value, but GNAT Pro 25.2 evaluates 'Valid on an element of a packed float array
      -- with a non native Scalar_Storage_Order on the unswapped bytes, so at staging a
      -- NaN or infinity passes. FSF GCC fixed this in 60f5887173a4. Once the compiler
      -- fix arrives this handler is unreachable and can go, along with the injection in
      -- the parameter rejection test.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Gimbal Angles To Motor Angles component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Gimbal_Angles_To_Motor_Angles.Implementation;
