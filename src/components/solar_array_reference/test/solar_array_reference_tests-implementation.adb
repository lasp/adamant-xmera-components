--------------------------------------------------------------------------------
-- Solar_Array_Reference Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with Ada.Real_Time;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Packed_F32.Assertion; use Packed_F32.Assertion;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Interfaces;
with Packed_Array_Angle;
with Packed_Array_Angle.Validation;
with Packed_Tracking_Mode;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Solar_Array_Reference_Enums; use Solar_Array_Reference_Enums;
with Solar_Array_Reference_Algorithm_C;
with Solar_Array_Reference_Parameters;
with Solar_Array_Reference_Types; use Solar_Array_Reference_Types;
with Sys_Time;

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
   Auto_Track : constant Packed_Tracking_Mode.T := (Value => Tracking_Mode.Auto_Track);
   Specified_Angle : constant Packed_Tracking_Mode.T := (Value => Tracking_Mode.Specified_Angle);
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

   -- Stage and apply the axes and the alignment threshold. The array axes are the same
   -- in every case.
   procedure Apply_Configuration (Self : in out Instance; Threshold : in Packed_F32.T) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Solar_Array_Reference_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Drive_Axis (Drive_Axis)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Surface_Normal (Surface_Normal)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold (Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Give only the commanded dependencies a stale limit, so they alone come back Stale
   -- once the tick time runs ahead of the product time.
   procedure Map_Commands_With_Stale_Limit (Self : in out Instance) is
      Never : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Time_Span_Zero;
      One_Second : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
   begin
      Self.Tester.Component_Instance.Map_Data_Dependencies (
         Navigation_Attitude_Id => 0, Navigation_Attitude_Stale_Limit => Never,
         Attitude_Reference_Id => 1, Attitude_Reference_Stale_Limit => Never,
         Sun_Direction_Body_Id => 2, Sun_Direction_Body_Stale_Limit => Never,
         Tracking_Mode_Id => 3, Tracking_Mode_Stale_Limit => One_Second,
         Specified_Array_Angle_Id => 4, Specified_Array_Angle_Stale_Limit => One_Second,
         Offset_Angle_Id => 5, Offset_Angle_Stale_Limit => One_Second);
   end Map_Commands_With_Stale_Limit;

   -- Send one tick at the given time, well ahead of the commands so they come back
   -- stale, with the given attitude, reference, and sun direction, and check the
   -- published reference angle.
   procedure Send_Stale_Tick_And_Check (
      Self : in out Instance;
      Tick_Number : in Natural;
      Tick_Time : in Sys_Time.T;
      Attitude : in Packed_F32x3.T;
      Reference : in Packed_F32x3.T;
      Sun_Body : in Packed_F32x3.T;
      Expected_Angle : in Short_Float
   ) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Timestamp_Override := (Seconds => 1, Subseconds => 0);
      T.Navigation_Attitude := (Time_Tag => 0.0, Sigma_Bn => Attitude, Omega_Bn_B => [0.0, 0.0, 0.0], Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]);
      T.Attitude_Reference := (Sigma_Rn => Reference, Omega_Rn_N => [0.0, 0.0, 0.0], Domega_Rn_N => [0.0, 0.0, 0.0]);
      T.Sun_Direction_Body := Sun_Body;
      T.Tick_T_Send ((Time => Tick_Time, Count => 0));
      Natural_Assert.Eq (T.Reference_Angle_History.Get_Count, Tick_Number);
      Packed_F32_Assert.Eq (T.Reference_Angle_History.Get (Tick_Number), (Value => Expected_Angle), Epsilon => Epsilon);
   end Send_Stale_Tick_And_Check;

   -- Command the mode and angles, send one tick with the given attitude, reference, and
   -- sun direction, and check the published reference angle.
   procedure Send_Tick_And_Check (
      Self : in out Instance;
      Tick_Number : in Natural;
      Mode : in Packed_Tracking_Mode.T;
      Specified : in Short_Float;
      Offset : in Short_Float;
      Attitude : in Packed_F32x3.T;
      Reference : in Packed_F32x3.T;
      Sun_Body : in Packed_F32x3.T;
      Expected_Angle : in Short_Float
   ) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Tracking_Mode := Mode;
      T.Specified_Array_Angle := (Value => Specified);
      T.Offset_Angle := (Value => Offset);
      T.Navigation_Attitude := (Time_Tag => 0.0, Sigma_Bn => Attitude, Omega_Bn_B => [0.0, 0.0, 0.0], Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]);
      T.Attitude_Reference := (Sigma_Rn => Reference, Omega_Rn_N => [0.0, 0.0, 0.0], Domega_Rn_N => [0.0, 0.0, 0.0]);
      T.Sun_Direction_Body := Sun_Body;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Reference_Angle_History.Get_Count, Tick_Number);
      Packed_F32_Assert.Eq (T.Reference_Angle_History.Get (Tick_Number), (Value => Expected_Angle), Epsilon => Epsilon);
   end Send_Tick_And_Check;

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
      Send_Tick_And_Check (Self, 1, Auto_Track, 0.0, 0.0, Attitude_A, Reference_A, Sun_X_From_A, 1.4252804701);
      Send_Tick_And_Check (Self, 2, Auto_Track, 0.0, 0.0, Attitude_A, Reference_A, Sun_Z_From_A, 0.2144368067);
      Send_Tick_And_Check (Self, 3, Auto_Track, 0.0, 0.0, Attitude_B, Reference_B, Sun_X_From_B, 0.3706993963);
      Send_Tick_And_Check (Self, 4, Auto_Track, 0.0, 0.0, Attitude_B, Reference_B, Sun_Z_From_B, -1.0129138132);
   end Test;

   -- Check the aligned sun fallback to the retained angle, the offset in sun tracking
   -- mode, and the commanded angle mode against the Python reference model.
   overriding procedure Test_Tracking_Mode_Variants (Self : in out Instance) is
   begin
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- With the sun along the drive axis the array has no preferred angle, so the
      -- reference holds the angle from the previous tick, which starts at zero:
      Send_Tick_And_Check (Self, 1, Auto_Track, 0.0, 0.0, Zero_Attitude, Zero_Attitude, Drive_Axis, 0.0);

      -- The commanded offset is added to the tracked angle:
      Send_Tick_And_Check (Self, 2, Auto_Track, 0.0, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5144368067);

      -- Back along the drive axis, the reference holds the tracked angle. The offset is
      -- not added a second time:
      Send_Tick_And_Check (Self, 3, Auto_Track, 0.0, 0.3, Zero_Attitude, Zero_Attitude, Drive_Axis, 0.5144368067);

      -- The commanded angle mode ignores the attitude and sun inputs and the offset:
      Send_Tick_And_Check (Self, 4, Specified_Angle, 0.5, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);
      Send_Tick_And_Check (Self, 5, Specified_Angle, -2.0, 2.0, Attitude_A, Reference_A, Sun_Z_From_A, -2.0);

      -- The commanded angle is retained too, so it is what the aligned sun falls back to:
      Send_Tick_And_Check (Self, 6, Auto_Track, 0.0, 0.0, Zero_Attitude, Zero_Attitude, Drive_Axis, -2.0);
   end Test_Tracking_Mode_Variants;

   -- The reset connector zeroes the reference angle the algorithm retains, so an
   -- aligned sun falls back to zero afterwards. The configuration is left in place.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Map_Commands_With_Stale_Limit (Self);
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- Track the sun with an offset, so the retained angle and the configuration are
      -- both away from their defaults:
      Send_Tick_And_Check (Self, 1, Auto_Track, 0.0, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5144368067);

      -- With the commands stale, an aligned sun falls back to the retained angle:
      Send_Stale_Tick_And_Check (Self, 2, (Seconds => 100, Subseconds => 0), Zero_Attitude, Zero_Attitude, Drive_Axis, 0.5144368067);

      -- After a reset it falls back to zero:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Send_Stale_Tick_And_Check (Self, 3, (Seconds => 101, Subseconds => 0), Zero_Attitude, Zero_Attitude, Drive_Axis, 0.0);

      -- The configuration survived the reset: the offset is still applied.
      Send_Stale_Tick_And_Check (Self, 4, (Seconds => 102, Subseconds => 0), Attitude_A, Reference_A, Sun_Z_From_A, 0.5144368067);
   end Test_Reset;

   -- The mode and angles are commanded sporadically, so on most ticks they come back
   -- stale. A stale command must leave the last configuration in place, and a
   -- parameter update in the meantime must reapply that configuration rather than
   -- the defaults.
   overriding procedure Test_Stale_Command (Self : in out Instance) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Map_Commands_With_Stale_Limit (Self);
      Apply_Configuration (Self, Threshold => Alignment_Threshold);

      -- A fresh command configures the algorithm:
      Send_Tick_And_Check (Self, 1, Specified_Angle, 0.5, 0.3, Attitude_A, Reference_A, Sun_Z_From_A, 0.5);

      -- The commands go stale: the products are stamped in the past and the tick runs
      -- well ahead of them. Different commanded values are offered, and ignored:
      T.Tracking_Mode := Auto_Track;
      T.Specified_Array_Angle := (Value => 1.0);
      T.Offset_Angle := (Value => 1.0);
      Send_Stale_Tick_And_Check (Self, 2, (Seconds => 100, Subseconds => 0), Attitude_A, Reference_A, Sun_Z_From_A, 0.5);

      -- A parameter update reapplies the last command rather than the defaults:
      Apply_Configuration (Self, Threshold => (Value => 0.2));
      Send_Stale_Tick_And_Check (Self, 3, (Seconds => 101, Subseconds => 0), Attitude_A, Reference_A, Sun_Z_From_A, 0.5);
   end Test_Stale_Command;

   -- The algorithm requires unit and orthogonal array axes and an alignment threshold
   -- in [1e-3, pi/2]. Validation is the only guard keeping a rejected value out of the
   -- throwing Set_Config, so exercise it directly.
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

   -- The commanded angles are not validated by this component: their type carries the
   -- range the algorithm accepts, so the command that sets them is rejected at receipt
   -- instead. That only holds if the Ada bounds are exactly the algorithm's, so ask
   -- the algorithm's own predicate about both bounds and the first value outside
   -- each, and check that the record validation, which is what command receipt runs,
   -- draws the same line.
   overriding procedure Test_Array_Angle_Range (Self : in out Instance) is
      Ignore : Instance renames Self;
      Axis : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Drive_Axis));
      Normal : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Surface_Normal));
      Just_Above : constant Short_Float := Short_Float'Succ (Array_Angle'Last);
      Just_Below : constant Short_Float := Short_Float'Pred (Array_Angle'First);

      -- Whether the algorithm accepts the angle as both the specified and the offset angle.
      function Accepted_By_Algorithm (Angle : in Short_Float) return Boolean is
         (Boolean (Solar_Array_Reference_Algorithm_C.Validate_Config (
            Drive_Axis            => Axis'Access,
            Surface_Normal        => Normal'Access,
            Alignment_Threshold   => Alignment_Threshold.Value,
            Tracking_Mode         => Tracking_Mode.C.Specified_Angle,
            Specified_Array_Angle => Angle,
            Offset_Angle          => Angle)));

      -- Whether the record validation accepts the angle. The bytes are built through
      -- the unconstrained record, because a value outside the range cannot be written
      -- into the constrained one.
      function Accepted_By_Validation (Angle : in Short_Float) return Boolean is
         Errant_Field : Interfaces.Unsigned_32;
      begin
         return Packed_Array_Angle.Validation.Valid (Packed_F32.Serialization.To_Byte_Array ((Value => Angle)), Errant_Field);
      end Accepted_By_Validation;
   begin
      -- Both bounds are accepted, so the type reaches everything the algorithm allows:
      Boolean_Assert.Eq (Accepted_By_Algorithm (Array_Angle'First), True);
      Boolean_Assert.Eq (Accepted_By_Algorithm (Array_Angle'Last), True);
      Boolean_Assert.Eq (Accepted_By_Validation (Array_Angle'First), True);
      Boolean_Assert.Eq (Accepted_By_Validation (Array_Angle'Last), True);

      -- The first value outside each bound is rejected by both, so the type allows
      -- nothing the algorithm would refuse:
      Boolean_Assert.Eq (Accepted_By_Algorithm (Just_Above), False);
      Boolean_Assert.Eq (Accepted_By_Algorithm (Just_Below), False);
      Boolean_Assert.Eq (Accepted_By_Validation (Just_Above), False);
      Boolean_Assert.Eq (Accepted_By_Validation (Just_Below), False);
   end Test_Array_Angle_Range;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Solar_Array_Reference.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
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
