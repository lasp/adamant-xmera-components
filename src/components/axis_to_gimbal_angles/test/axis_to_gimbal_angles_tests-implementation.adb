--------------------------------------------------------------------------------
-- Axis_To_Gimbal_Angles Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Axis_To_Gimbal_Angles_Output;
with Axis_To_Gimbal_Angles_Output.Assertion; use Axis_To_Gimbal_Angles_Output.Assertion;
with Axis_To_Gimbal_Angles_Parameters;
with Packed_F32;
with Packed_F32x3;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Axis_To_Gimbal_Angles_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The gimbal mount is rotated 5 degrees about x and then 10 degrees about y
   -- relative to the body, as in the Python reference test
   -- (_tests/test_axisToGimbalAngles.py), expressed as an MRP.
   Rotated_Mount : constant Packed_F32x3.T := [0.0217784627, 0.0436401156, 0.0019053686];
   Aligned_Mount : constant Packed_F32x3.T := [0.0, 0.0, 0.0];

   -- Largest deflections, 60 and 15 degrees.
   Wide_Travel : constant Packed_F32.T := (Value => 1.0471975512);
   Narrow_Travel : constant Packed_F32.T := (Value => 0.2617993878);

   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a configuration.
   procedure Apply_Configuration (Self : in out Instance; Sigma_Mb : in Packed_F32x3.T; Theta_Max : in Packed_F32.T) is
      T : Component.Axis_To_Gimbal_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Axis_To_Gimbal_Angles_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Mb (Sigma_Mb)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max (Theta_Max)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Tick once with the given request and check the published gimbal command.
   procedure Tick_And_Expect (
      Self : in out Instance;
      Tick_Number : in Natural;
      Request : in Packed_F32x3.T;
      Expected : in Axis_To_Gimbal_Angles_Output.T
   ) is
      T : Component.Axis_To_Gimbal_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Thrust_Direction := Request;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Gimbal_Command_History.Get_Count, Tick_Number);
      Axis_To_Gimbal_Angles_Output_Assert.Eq (T.Gimbal_Command_History.Get (Tick_Number), Expected, Epsilon => Epsilon);
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

   -- Recover known gimbal angle pairs from requests built from them, as in the Python
   -- reference test, to ensure the Ada to C to C++ integration is sound. Each request
   -- is the thrust axis for a known angle pair, rotated into the body frame through
   -- the rotated mount. The second request is also scaled by 137, which must not
   -- change the angles. The achieved direction is the request as a unit vector.
   overriding procedure Test (Self : in out Instance) is
   begin
      Apply_Configuration (Self, Rotated_Mount, Wide_Travel);

      -- Angles 12 degrees and -7.5 degrees:
      Tick_And_Expect (Self, 1,
         Request => [0.0426819189, -0.2906256575, 0.9558843973],
         Expected => (Gimbal_Angle_1 => 0.2094395102, Gimbal_Angle_2 => -0.1308996939,
                      Thrust_Hat_B => [0.0426819189, -0.2906256575, 0.9558843973]));

      -- Angles -18.25 degrees and 9.75 degrees, request scaled by 137:
      Tick_And_Expect (Self, 2,
         Request => [44.0278924719, 31.4944870492, 125.8516665364],
         Expected => (Gimbal_Angle_1 => -0.3185225885, Gimbal_Angle_2 => 0.1701696021,
                      Thrust_Hat_B => [0.3213714779, 0.2298867668, 0.9186253032]));
   end Test;

   -- Check that a request beyond the travel is pulled back onto the cone of the
   -- largest deflection, and that a request with no direction leaves the gimbal at
   -- neutral. The mount is aligned with the body so the angles read directly.
   overriding procedure Test_Deflection_Limit (Self : in out Instance) is
   begin
      Apply_Configuration (Self, Aligned_Mount, Narrow_Travel);

      -- A request 90 degrees off the neutral axis is pulled back to 15 degrees, all of
      -- it in the second gimbal angle:
      Tick_And_Expect (Self, 1,
         Request => [1.0, 0.0, 0.0],
         Expected => (Gimbal_Angle_1 => 0.0, Gimbal_Angle_2 => Narrow_Travel.Value,
                      Thrust_Hat_B => [0.2588190451, 0.0, 0.9659258263]));

      -- A request with no direction leaves the gimbal at neutral, firing along the
      -- un-deflected axis:
      Tick_And_Expect (Self, 2,
         Request => [0.0, 0.0, 0.0],
         Expected => (Gimbal_Angle_1 => 0.0, Gimbal_Angle_2 => 0.0, Thrust_Hat_B => [0.0, 0.0, 1.0]));

      -- A request inside the travel is achieved exactly:
      Tick_And_Expect (Self, 3,
         Request => [0.0, -0.1736481777, 0.9848077530],
         Expected => (Gimbal_Angle_1 => 0.1745329252, Gimbal_Angle_2 => 0.0,
                      Thrust_Hat_B => [0.0, -0.1736481777, 0.9848077530]));
   end Test_Deflection_Limit;

   -- The algorithm requires a finite mount attitude and a largest deflection strictly
   -- between 0 and 90 degrees. Validation is the only guard keeping a rejected value
   -- out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Axis_To_Gimbal_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Axis_To_Gimbal_Angles_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Mb (Rotated_Mount)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max (Wide_Travel)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A largest deflection of zero is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A largest deflection of 90 degrees is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max ((Value => 1.5707963268))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative largest deflection is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max ((Value => -0.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite mount attitude is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Sigma_Mb (Rotated_Mount);
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
      T : Component.Axis_To_Gimbal_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Gimbal_Command_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Axis_To_Gimbal_Angles_Tests.Implementation;
