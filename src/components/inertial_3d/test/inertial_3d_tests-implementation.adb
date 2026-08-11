--------------------------------------------------------------------------------
-- Inertial_3d Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Basic_Types;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Component.Inertial_3d.Implementation.Tester;
with Att_Ref;
with Inertial_3d_Parameters;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Inertial_3d_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Call component init here.
      Self.Tester.Component_Instance.Init;

      -- Call the component set up method that the assembly would normally call.
      Self.Tester.Component_Instance.Set_Up;
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      -- Free component heap:
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Inertial_3d_Parameters.Instance;

      -- The reference attitude is now configuration rather than a per-tick input,
      -- so each case is delivered as a parameter update. The algorithm holds the
      -- MRP and returns it unchanged, so the published reference must echo the
      -- configured value with zero reference rates.
      type Test_Case is record
         Sigma_Input : Packed_F32x3.T;
      end record;

      Test_Cases : constant array (1 .. 2) of Test_Case := [
         (Sigma_Input => [0.0, 0.0, 0.0]),
         (Sigma_Input => [0.1, -0.2, 0.3])
      ];

      Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      Epsilon : constant := 1.0E-6;
   begin
      for I in Test_Cases'Range loop
         -- Configure the reference attitude for this case.
         Parameter_Update_Status_Assert.Eq (
            T.Stage_Parameter (Params.Sigma_Rn (Test_Cases (I).Sigma_Input)), Success);
         Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
         Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

         -- Trigger the component execution.
         T.Tick_T_Send (((0, 0), 0));

         -- Ensure output was published.
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, I);

         declare
            Output : constant Att_Ref.T := T.Attitude_Reference_History.Get (I);
         begin
            Packed_F32x3_Assert.Eq (Output.Sigma_Rn, Test_Cases (I).Sigma_Input, Epsilon => Epsilon);
            Packed_F32x3_Assert.Eq (Output.Omega_Rn_N, Zero_Vector, Epsilon => Epsilon);
            Packed_F32x3_Assert.Eq (Output.Domega_Rn_N, Zero_Vector, Epsilon => Epsilon);
         end;
      end loop;
   end Test;

   -- The algorithm's Inertial3DConfig requires a finite MRP. A non-finite value is
   -- not expressible as a packed-record field range, so it survives staging and is
   -- caught only by the algorithm's own validator; Validate_Parameters must refuse
   -- it so it never reaches the throwing Set_Config. The non-finite value is
   -- injected by overwriting the parameter buffer with the IEEE-754 single-
   -- precision +infinity pattern, mimicking a ground upload.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Inertial_3d_Parameters.Instance;
      Valid_Sigma : constant Packed_F32x3.T := [0.1, -0.2, 0.3];
      Param : Parameter.T := Params.Sigma_Rn (Valid_Sigma);
   begin
      -- The baseline value is accepted.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- Make the first MRP component +infinity (0x7F800000, big endian).
      Param.Buffer (Param.Buffer'First) := Basic_Types.Byte (16#7F#);
      Param.Buffer (Param.Buffer'First + 1) := Basic_Types.Byte (16#80#);
      Param.Buffer (Param.Buffer'First + 2) := Basic_Types.Byte (16#00#);
      Param.Buffer (Param.Buffer'First + 3) := Basic_Types.Byte (16#00#);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring a finite value makes the set acceptable again, so the rejection
      -- was caused by the perturbed value rather than by sticky staging state.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Rn (Valid_Sigma)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Inertial_3d_Tests.Implementation;
