--------------------------------------------------------------------------------
-- Thrust_Vectoring Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Thrust_Vectoring_Parameters;

package body Thrust_Vectoring_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The geometry of the Python reference test (_tests/test_thrustVectoring.py): the
   -- thrust point 1.4 m up the body z axis, a 10 N thrust, and the center of mass
   -- offset from the body origin. The expected directions were evaluated with the
   -- algorithm's closed form solve in double precision.
   Thrust_Point : constant Packed_F32x3.T := [0.0, 0.1, 1.4];
   Thrust : constant Packed_F32.T := (Value => 10.0);
   Center_Of_Mass : constant Packed_F32x3.T := [0.05, 0.02, 0.1];

   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Tick once with the given torque request and check the published direction.
   procedure Tick_And_Expect (Self : in out Instance; Tick_Number : in Natural; Request : in Packed_F32x3.T; Expected : in Packed_F32x3.T) is
      T : Component.Thrust_Vectoring.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Torque_Request := (Torque_Request_Body => Request);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Thrust_Direction_History.Get_Count, Tick_Number);
      Packed_F32x3_Assert.Eq (T.Thrust_Direction_History.Get (Tick_Number), Expected, Epsilon => Epsilon);
   end Tick_And_Expect;

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
      -- Free the C++ algorithm heap:
      Self.Tester.Component_Instance.Destroy;
      -- Free component heap:
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Point the thrust for a zero, a small, and a saturating torque request to ensure
   -- the Ada to C to C++ integration is sound. A zero request fires the thrust from
   -- the thrust point through the center of mass. A small request tilts it slightly
   -- off that line. A request far beyond the 13 Nm the geometry can deliver saturates,
   -- so the thrust lies entirely perpendicular to the moment arm.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Thrust_Vectoring.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thrust_Vectoring_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Mb_B (Thrust_Point)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust (Thrust)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Cb_B (Center_Of_Mass)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- No torque requested:
      Tick_And_Expect (Self, 1,
         Request => [0.0, 0.0, 0.0],
         Expected => [0.038360662253, -0.061377059605, -0.997377218582]);

      -- A 0.05 Nm request:
      Tick_And_Expect (Self, 2,
         Request => [0.036369648373, -0.018184824186, 0.029095718698],
         Expected => [0.036831945068, -0.064245375168, -0.997254200087]);

      -- A 4 Nm request about the body y axis:
      Tick_And_Expect (Self, 3,
         Request => [0.0, 4.0, 0.0],
         Expected => [0.342597180465, -0.058426840796, -0.937663839663]);

      -- A 5 Nm request in the same direction as the small one, which is more than the
      -- geometry can deliver about its perpendicular:
      Tick_And_Expect (Self, 4,
         Request => [3.636964837267, -1.818482418633, 2.909571869813],
         Expected => [-0.116576621737, -0.344903711186, -0.931370668034]);
   end Test;

   -- The algorithm requires finite positions, a positive thrust, and a center of mass
   -- clear of the thrust point. Validation is the only guard keeping a rejected value
   -- out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Thrust_Vectoring.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thrust_Vectoring_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Mb_B (Thrust_Point)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust (Thrust)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Cb_B (Center_Of_Mass)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A zero thrust is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative thrust is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust ((Value => -10.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A center of mass at the thrust point is rejected, since no direction is defined:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Cb_B (Thrust_Point)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite thrust point is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.R_Mb_B (Thrust_Point);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Thrust_Vectoring.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Thrust_Direction_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Thrust_Vectoring_Tests.Implementation;
