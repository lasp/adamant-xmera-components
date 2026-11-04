--------------------------------------------------------------------------------
-- Solar_Array_Reference Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with Ada.Numerics;
with Ada.Real_Time;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Packed_F32.Assertion; use Packed_F32.Assertion;
with Packed_F32;
with Packed_F32x3;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Solar_Array_Reference_Enums; use Solar_Array_Reference_Enums;
with Solar_Array_Reference_Parameters;

package body Solar_Array_Reference_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Array axes, attitudes, and sun directions from the Python reference test
   -- (_tests/test_solarArrayReference.py). The reference test gives the sun direction
   -- in the inertial frame; the body frame directions below are that vector rotated by
   -- the corresponding body attitude.
   Drive_Axis : constant Packed_F32x3.T := [1.0, 0.0, 0.0];
   Surface_Normal : constant Packed_F32x3.T := [0.0, 1.0, 0.0];
   Alignment_Threshold : constant Packed_F32.T := (Value => 0.1);
   Zero_Attitude : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   Auto_Track : constant Tracking_Mode.E := Tracking_Mode.Auto_Track;
   Specified_Angle : constant Tracking_Mode.E := Tracking_Mode.Specified_Angle;
   Attitude_A : constant Packed_F32x3.T := [0.1, 0.2, 0.3];
   Reference_A : constant Packed_F32x3.T := [0.3, 0.2, 0.1];
   Attitude_B : constant Packed_F32x3.T := [0.5, 0.4, 0.3];
   Reference_B : constant Packed_F32x3.T := [0.9, 0.7, 0.8];
   -- Inertial x and z sun directions seen from attitude A and attitude B.
   Sun_X_From_A : constant Packed_F32x3.T := [0.1997537704, -0.6709756848, 0.7140658664];
   Sun_Z_From_A : constant Packed_F32x3.T := [-0.3447214528, 0.6340412435, 0.6922129886];
   Sun_X_From_B : constant Packed_F32x3.T := [0.1111111111, 0.4444444444, 0.8888888889];
   Sun_Z_From_B : constant Packed_F32x3.T := [0.1777777778, 0.8711111111, -0.4577777778];

   -- The reference angles are computed in double precision; the single precision
   -- algorithm agrees to a few parts in a million.
   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply the axes and the alignment threshold. The array axes are the
   -- same in every case.
   procedure Apply_Configuration (Self : in out Instance; Threshold : in Packed_F32.T) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Solar_Array_Reference_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Drive_Axis (Drive_Axis)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Surface_Normal (Surface_Normal)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold (Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Stage the mode and the angles and return the validation status. The update is
   -- only sent when the set is valid.
   function Stage_Mode_And_Angles (Self : in out Instance; Mode : in Tracking_Mode.E; Specified : in Short_Float; Offset : in Short_Float) return Parameter_Enums.Parameter_Update_Status.E is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Solar_Array_Reference_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Mode ((Value => Mode))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Specified_Array_Angle ((Value => Specified))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Offset_Angle ((Value => Offset))), Success);
      return T.Validate_Parameters;
   end Stage_Mode_And_Angles;

   -- Set the mode and the angles, which the algorithm must accept.
   procedure Set_Mode_And_Angles (Self : in out Instance; Mode : in Tracking_Mode.E; Specified : in Short_Float; Offset : in Short_Float) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Parameter_Update_Status_Assert.Eq (Stage_Mode_And_Angles (Self, Mode, Specified, Offset), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Set_Mode_And_Angles;

   -- Map the attitude, the reference, and the sun direction to identifiers the tester
   -- does not serve, so any fetch of them fails the tick's assertion.
   procedure Map_Attitude_Inputs_Unavailable (Self : in out Instance) is
      Never : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Time_Span_Zero;
   begin
      Self.Tester.Component_Instance.Map_Data_Dependencies (
         Navigation_Attitude_Id => 10, Navigation_Attitude_Stale_Limit => Never,
         Attitude_Reference_Id => 11, Attitude_Reference_Stale_Limit => Never,
         Sun_Direction_Body_Id => 12, Sun_Direction_Body_Stale_Limit => Never);
   end Map_Attitude_Inputs_Unavailable;

   -- Send one tick and expect it to fail an assertion without publishing anything.
   procedure Send_Tick_And_Expect_Assertion (Self : in out Instance; Message : in String) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
      Published_Before : constant Natural := T.Reference_Angle_History.Get_Count;
   begin
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, Message);
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Reference_Angle_History.Get_Count, Published_Before);
   end Send_Tick_And_Expect_Assertion;

   -- Send one tick, without a new mode or angles, with the given attitude, reference,
   -- and sun direction, and check the published reference angle.
   procedure Send_Tick_And_Check (
      Self : in out Instance;
      Tick_Number : in Natural;
      Attitude : in Packed_F32x3.T;
      Reference : in Packed_F32x3.T;
      Sun_Body : in Packed_F32x3.T;
      Expected_Angle : in Short_Float
   ) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Navigation_Attitude := (Time_Tag => 0.0, Sigma_Bn => Attitude, Omega_Bn_B => [0.0, 0.0, 0.0], Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]);
      T.Attitude_Reference := (Sigma_Rn => Reference, Omega_Rn_N => [0.0, 0.0, 0.0], Domega_Rn_N => [0.0, 0.0, 0.0]);
      T.Sun_Direction_Body := Sun_Body;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Reference_Angle_History.Get_Count, Tick_Number);
      Packed_F32_Assert.Eq (T.Reference_Angle_History.Get (Tick_Number), (Value => Expected_Angle), Epsilon => Epsilon);
   end Send_Tick_And_Check;

   -- Set the mode and angles, send one tick with the given attitude, reference, and
   -- sun direction, and check the published reference angle.
   procedure Set_Tick_And_Check (
      Self : in out Instance;
      Tick_Number : in Natural;
      Mode : in Tracking_Mode.E;
      Specified : in Short_Float;
      Offset : in Short_Float;
      Attitude : in Packed_F32x3.T;
      Reference : in Packed_F32x3.T;
      Sun_Body : in Packed_F32x3.T;
      Expected_Angle : in Short_Float
   ) is
   begin
      Set_Mode_And_Angles (Self, Mode, Specified, Offset);
      Send_Tick_And_Check (Self, Tick_Number, Attitude, Reference, Sun_Body, Expected_Angle);
   end Set_Tick_And_Check;

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

   -- Run the algorithm on the sun tracking cases of the Python reference test to ensure
   -- the Ada to C to C++ integration is sound. The expected angles are computed
   -- independently from the reference model: the sun direction is carried into the
   -- reference attitude and the angle turns the surface normal toward it.
   overriding procedure Test (Self : in out Instance) is
   begin
      Apply_Configuration (Self, Threshold => Alignment_Threshold);
      Set_Tick_And_Check (Self, 1, Auto_Track, 0.0, 0.0, Attitude_A, Reference_A, Sun_X_From_A, 1.4252804701);
      Set_Tick_And_Check (Self, 2, Auto_Track, 0.0, 0.0, Attitude_A, Reference_A, Sun_Z_From_A, 0.2144368067);
      Set_Tick_And_Check (Self, 3, Auto_Track, 0.0, 0.0, Attitude_B, Reference_B, Sun_X_From_B, 0.3706993963);
      Set_Tick_And_Check (Self, 4, Auto_Track, 0.0, 0.0, Attitude_B, Reference_B, Sun_Z_From_B, -1.0129138132);
   end Test;

   -- Check the aligned sun fallback to the retained angle, the offset in sun tracking
   -- mode, and the specified angle mode against the Python reference model.
   overriding procedure Test_Tracking_Mode_Variants (Self : in out Instance) is
   begin
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- With the sun along the drive axis the array has no preferred angle, so the
      -- reference holds the angle from the previous tick, which starts at zero:
      Set_Tick_And_Check (Self, 1, Auto_Track, 0.0, 0.0, Zero_Attitude, Zero_Attitude, Drive_Axis, 0.0);

      -- The offset is added to the tracked angle:
      Set_Tick_And_Check (Self, 2, Auto_Track, 0.0, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5144368067);

      -- Back along the drive axis, the reference holds the tracked angle. The offset is
      -- not added a second time:
      Set_Tick_And_Check (Self, 3, Auto_Track, 0.0, 0.3, Zero_Attitude, Zero_Attitude, Drive_Axis, 0.5144368067);

      -- The specified angle mode ignores the attitude and sun inputs and the offset:
      Set_Tick_And_Check (Self, 4, Specified_Angle, 0.5, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);
      Set_Tick_And_Check (Self, 5, Specified_Angle, -2.0, 2.0, Attitude_A, Reference_A, Sun_Z_From_A, -2.0);

      -- The specified angle is retained too, so it is what the aligned sun falls back to:
      Set_Tick_And_Check (Self, 6, Auto_Track, 0.0, 0.0, Zero_Attitude, Zero_Attitude, Drive_Axis, -2.0);
   end Test_Tracking_Mode_Variants;

   -- The reset connector zeroes the reference angle the algorithm retains, so an
   -- aligned sun falls back to zero afterwards. The configuration is left in place.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- Track the sun with an offset, so the retained angle and the configuration are
      -- both away from their defaults:
      Set_Tick_And_Check (Self, 1, Auto_Track, 0.0, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5144368067);

      -- Without a new mode, an aligned sun falls back to the retained angle:
      Send_Tick_And_Check (Self, 2, Zero_Attitude, Zero_Attitude, Drive_Axis, 0.5144368067);

      -- After a reset it falls back to zero:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Send_Tick_And_Check (Self, 3, Zero_Attitude, Zero_Attitude, Drive_Axis, 0.0);

      -- The configuration survived the reset: the offset is still applied.
      Send_Tick_And_Check (Self, 4, Attitude_A, Reference_A, Sun_Z_From_A, 0.5144368067);
   end Test_Reset;

   -- The mode and angles change rarely, so most ticks arrive without a new set. The
   -- last set must stay in effect on them, and an update of the array axes and
   -- threshold alone must leave it in place rather than restore the defaults.
   overriding procedure Test_Mode_Retained (Self : in out Instance) is
   begin
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- A mode and angles configure the algorithm:
      Set_Tick_And_Check (Self, 1, Specified_Angle, 0.5, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);

      -- A tick without a new set keeps them:
      Send_Tick_And_Check (Self, 2, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);

      -- An update of the axes and threshold alone keeps them too:
      Apply_Configuration (Self, Threshold => (Value => 0.2));
      Send_Tick_And_Check (Self, 3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);
   end Test_Mode_Retained;

   -- The algorithm requires unit and orthogonal array axes, an alignment threshold
   -- in [1e-3, pi/2], and angles in [-pi, pi]. Validation is the only guard keeping a
   -- rejected value out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Solar_Array_Reference_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Drive_Axis (Drive_Axis)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Surface_Normal (Surface_Normal)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold (Alignment_Threshold)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Mode ((Value => Auto_Track))), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Specified_Array_Angle ((Value => 0.0))), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Offset_Angle ((Value => 0.0))), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A drive axis that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Drive_Axis ([2.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A surface normal that is not orthogonal to the drive axis is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Surface_Normal ([0.7071067812, 0.7071067812, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An alignment threshold below the minimum is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A specified angle outside [-pi, pi] is rejected, in either mode:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Specified_Array_Angle ((Value => 4.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Mode ((Value => Specified_Angle))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Specified_Array_Angle ((Value => -4.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An offset angle outside [-pi, pi] is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Offset_Angle ((Value => -4.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite drive axis is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Drive_Axis (Drive_Axis);
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

   -- The angles are validated by the algorithm alone, so the line it draws is the
   -- line the ground sees. Ask it about both bounds and the first value outside
   -- each, as the specified angle and as the offset angle at once.
   overriding procedure Test_Angle_Range (Self : in out Instance) is
      -- The bounds are pi rounded to the nearest Short_Float, which lies just above pi.
      Upper : constant Short_Float := Short_Float (Ada.Numerics.Pi);
      Lower : constant Short_Float := -Upper;
      Just_Above : constant Short_Float := Short_Float'Succ (Upper);
      Just_Below : constant Short_Float := Short_Float'Pred (Lower);
   begin
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- Both bounds are accepted:
      Parameter_Update_Status_Assert.Eq (Stage_Mode_And_Angles (Self, Specified_Angle, Lower, Lower), Success);
      Parameter_Update_Status_Assert.Eq (Stage_Mode_And_Angles (Self, Specified_Angle, Upper, Upper), Success);

      -- The first value outside each bound is rejected:
      Parameter_Update_Status_Assert.Eq (Stage_Mode_And_Angles (Self, Specified_Angle, Just_Above, Just_Above), Validation_Error);
      Parameter_Update_Status_Assert.Eq (Stage_Mode_And_Angles (Self, Specified_Angle, Just_Below, Just_Below), Validation_Error);
   end Test_Angle_Range;

   -- In the specified angle mode the algorithm reads none of the attitude inputs, so
   -- the tick does not fetch them. With them unavailable the specified angle mode
   -- still runs the algorithm and publishes the specified angle. Switching to the sun
   -- tracking mode then needs them, so the tick fails its assertion.
   overriding procedure Test_Specified_Angle_Without_Attitude (Self : in out Instance) is
   begin
      Map_Attitude_Inputs_Unavailable (Self);
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- The specified angle mode publishes the specified angle, wrapped by the
      -- algorithm, without the attitude inputs:
      Set_Tick_And_Check (Self, 1, Specified_Angle, 0.5, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);
      Set_Tick_And_Check (Self, 2, Specified_Angle, -2.0, 0.0, Attitude_A, Reference_A, Sun_Z_From_A, -2.0);

      -- The sun tracking mode fetches them and fails its assertion:
      Set_Mode_And_Angles (Self, Auto_Track, 0.0, 0.0);
      Send_Tick_And_Expect_Assertion (Self, "The sun tracking mode should have failed an assertion without the attitude inputs.");
   end Test_Specified_Angle_Without_Attitude;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- The dependencies are only fetched in the sun tracking mode:
      Set_Mode_And_Angles (Self, Auto_Track, 0.0, 0.0);
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Reference_Angle_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Solar_Array_Reference_Tests.Implementation;
