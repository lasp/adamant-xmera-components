--------------------------------------------------------------------------------
-- Gimbal_Angles_To_Motor_Angles Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with Ada.Numerics;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Gimbal_Angles_To_Motor_Angles_Parameters;
with Packed_F32;
with Packed_F32.Assertion; use Packed_F32.Assertion;
with Packed_F32x9;
with Packed_U32;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Gimbal_Angles_To_Motor_Angles_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The tests use the linear configuration of the algorithm's own unit tests. Its
   -- surfaces have known values: motor 1 is Surface_Scale * v steps and motor 2 is
   -- Surface_Scale * u steps, where u = tip / Half_Diagonal_Tip + tilt /
   -- Half_Diagonal_Tilt and v = tip / Half_Diagonal_Tip - tilt / Half_Diagonal_Tilt.
   -- The two motors have different surfaces, so a swap of the motors or of u and v
   -- is caught.
   Steps_Per_Revolution : constant := 628;   -- [steps] Motor steps per 2*pi rad
   Half_Diagonal_Tip : constant := 0.3;      -- [rad] Largest gimbal tip angle
   Half_Diagonal_Tilt : constant := 0.45;    -- [rad] Largest gimbal tilt angle
   Theta_Max : constant := 0.24;             -- [rad] Largest requested thrust cone angle
   Surface_Scale : constant := 1_000.0;      -- [steps] Surface value at u = 1 or v = 1

   -- [rad/step] The algorithm multiplies the steps of each surface by this to get
   -- the motor angle, so 100 steps is about 1 rad.
   Step_Angle : constant := 2.0 * Ada.Numerics.Pi / Steps_Per_Revolution;

   -- [rad] One degree. The requests are written in degrees, as in the algorithm's
   -- unit tests.
   Deg : constant := Ada.Numerics.Pi / 180.0;

   -- [rad] Tolerance on a motor angle, a tenth of a motor step.
   Epsilon : constant := 0.1 * Step_Angle;

   -- The two motor angles of one tick.
   type Motor_Angles is record
      Motor_1 : Short_Float; -- [rad]
      Motor_2 : Short_Float; -- [rad]
   end record;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- [-] The coefficient at this index along u or v that makes a cubic spline equal
   -- to the coordinate itself. The spline has six intervals on [-1, 1].
   function Greville (Index : in Natural) return Short_Float is
      (-1.0 + (2.0 / 6.0) * Short_Float (Index - 1));

   -- Stage the linear configuration and apply it with a reset. The offsets [steps]
   -- are added to every coefficient of a motor, which adds them to its surface.
   procedure Apply_Linear_Configuration (
      Self : in out Instance;
      Offset_1 : in Short_Float := 0.0;
      Offset_2 : in Short_Float := 0.0
   ) is
      T : Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Gimbal_Angles_To_Motor_Angles_Parameters.Instance;
      -- Motor 1 changes along v, the second index, so all of its rows are the same.
      -- Motor 2 changes along u, the first index, so each of its rows is constant.
      Motor_1_Row : constant Packed_F32x9.T := [for J in Packed_F32x9.T'Range => Offset_1 + Surface_Scale * Greville (J)];
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Steps_Per_Revolution ((Value => Steps_Per_Revolution))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Half_Diagonal_Tip ((Value => Half_Diagonal_Tip))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Half_Diagonal_Tilt ((Value => Half_Diagonal_Tilt))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max ((Value => Theta_Max))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_0 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_1 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_2 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_3 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_4 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_5 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_6 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_7 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_8 (Motor_1_Row)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_0 ([others => Offset_2 + Surface_Scale * Greville (0)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_1 ([others => Offset_2 + Surface_Scale * Greville (1)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_2 ([others => Offset_2 + Surface_Scale * Greville (2)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_3 ([others => Offset_2 + Surface_Scale * Greville (3)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_4 ([others => Offset_2 + Surface_Scale * Greville (4)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_5 ([others => Offset_2 + Surface_Scale * Greville (5)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_6 ([others => Offset_2 + Surface_Scale * Greville (6)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_7 ([others => Offset_2 + Surface_Scale * Greville (7)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_8 ([others => Offset_2 + Surface_Scale * Greville (8)])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Apply_Linear_Configuration;

   -- [rad] The motor angles of the linear configuration for gimbal angles [rad]
   -- inside the rhombus.
   function Linear_Angles (
      Tip : in Short_Float;
      Tilt : in Short_Float;
      Offset_1 : in Short_Float := 0.0;
      Offset_2 : in Short_Float := 0.0
   ) return Motor_Angles is
      U : constant Short_Float := Tip / Half_Diagonal_Tip + Tilt / Half_Diagonal_Tilt;
      V : constant Short_Float := Tip / Half_Diagonal_Tip - Tilt / Half_Diagonal_Tilt;
   begin
      return (Motor_1 => (Offset_1 + Surface_Scale * V) * Step_Angle, Motor_2 => (Offset_2 + Surface_Scale * U) * Step_Angle);
   end Linear_Angles;

   -- Tick once with the given gimbal angles [rad] and check the published motor
   -- angles [rad].
   procedure Tick_And_Expect (
      Self : in out Instance;
      Tick_Number : in Natural;
      Tip : in Short_Float;
      Tilt : in Short_Float;
      Expected : in Motor_Angles
   ) is
      T : Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Gimbal_Command := (Gimbal_Angle_1 => Tip, Gimbal_Angle_2 => Tilt);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2 * Tick_Number);
      Natural_Assert.Eq (T.Motor_1_Angle_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Motor_2_Angle_History.Get_Count, Tick_Number);
      Packed_F32_Assert.Eq (T.Motor_1_Angle_History.Get (Tick_Number), (Value => Expected.Motor_1), Epsilon => Epsilon);
      Packed_F32_Assert.Eq (T.Motor_2_Angle_History.Get (Tick_Number), (Value => Expected.Motor_2), Epsilon => Epsilon);
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

      -- Call component init here. This builds the algorithm from the default parameter
      -- values, so every test also checks that the defaults form a valid configuration.
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

   -- Compute the motor angles for known gimbal angles with the linear configuration
   -- of the algorithm's own unit tests, whose surfaces have known values, to ensure
   -- the Ada to C to C++ integration is sound. The first request gives about 97 and
   -- 252 steps, which is 0.97 and 2.52 rad. The requests are in different spline
   -- intervals, so a coefficient row or column in the wrong place changes a result.
   overriding procedure Test (Self : in out Instance) is
   begin
      Apply_Linear_Configuration (Self);
      Tick_And_Expect (Self, 1, Tip => 3.0 * Deg, Tilt => 2.0 * Deg, Expected => Linear_Angles (3.0 * Deg, 2.0 * Deg));
      Tick_And_Expect (Self, 2, Tip => 0.0, Tilt => 0.0, Expected => (Motor_1 => 0.0, Motor_2 => 0.0));
      Tick_And_Expect (Self, 3, Tip => -4.0 * Deg, Tilt => 6.0 * Deg, Expected => Linear_Angles (-4.0 * Deg, 6.0 * Deg));
      Tick_And_Expect (Self, 4, Tip => 8.0 * Deg, Tilt => -5.0 * Deg, Expected => Linear_Angles (8.0 * Deg, -5.0 * Deg));
   end Test;

   -- Check that a request outside the addressable rhombus keeps the last computed
   -- motor angles, and that before a first valid request and after a reset it gives
   -- the motor angles at zero gimbal angles. The surfaces are offset by 250 and -400
   -- steps, so the motor angles at zero gimbal angles are not zero. A tip of 25
   -- degrees is outside the rhombus, which reaches about 17 degrees on the tip axis.
   overriding procedure Test_Outside_Rhombus (Self : in out Instance) is
      T : Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
      Offset_1 : constant Short_Float := 250.0;  -- [steps]
      Offset_2 : constant Short_Float := -400.0; -- [steps]
      Zero_Gimbal_Angles : constant Motor_Angles := Linear_Angles (0.0, 0.0, Offset_1, Offset_2);
      Inside_Angles : constant Motor_Angles := Linear_Angles (3.0 * Deg, 2.0 * Deg, Offset_1, Offset_2);
   begin
      Apply_Linear_Configuration (Self, Offset_1, Offset_2);

      -- No motor angles were computed yet, so a request outside the rhombus gives the
      -- motor angles at zero gimbal angles:
      Tick_And_Expect (Self, 1, Tip => 25.0 * Deg, Tilt => 0.0, Expected => Zero_Gimbal_Angles);

      -- A request inside the rhombus is computed:
      Tick_And_Expect (Self, 2, Tip => 3.0 * Deg, Tilt => 2.0 * Deg, Expected => Inside_Angles);

      -- Requests outside the rhombus now keep the computed motor angles:
      Tick_And_Expect (Self, 3, Tip => 25.0 * Deg, Tilt => 0.0, Expected => Inside_Angles);
      Tick_And_Expect (Self, 4, Tip => 10.0 * Deg, Tilt => 20.0 * Deg, Expected => Inside_Angles);

      -- A reset clears them:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Tick_And_Expect (Self, 5, Tip => 25.0 * Deg, Tilt => 0.0, Expected => Zero_Gimbal_Angles);
   end Test_Outside_Rhombus;

   -- Check that a reset, not a tick, applies a parameter update. Twice the steps per
   -- revolution is half the step angle, so the same request gives half the motor
   -- angles.
   overriding procedure Test_Parameter_Update (Self : in out Instance) is
      T : Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Gimbal_Angles_To_Motor_Angles_Parameters.Instance;
      Twice_The_Steps : constant := 2 * Steps_Per_Revolution; -- [steps]
      Angles : constant Motor_Angles := Linear_Angles (3.0 * Deg, 2.0 * Deg);
      Half_Angles : constant Motor_Angles := (Motor_1 => Angles.Motor_1 / 2.0, Motor_2 => Angles.Motor_2 / 2.0);
   begin
      Apply_Linear_Configuration (Self);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Steps_Per_Revolution ((Value => Twice_The_Steps))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- A tick still runs with the steps per revolution of the last reset:
      Tick_And_Expect (Self, 1, Tip => 3.0 * Deg, Tilt => 2.0 * Deg, Expected => Angles);

      -- The reset applies the update:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Tick_And_Expect (Self, 2, Tip => 3.0 * Deg, Tilt => 2.0 * Deg, Expected => Half_Angles);
   end Test_Parameter_Update;

   -- The algorithm requires steps per revolution in [1, 100000], half-diagonals in
   -- (0, pi/2], a cone angle that fits inside the rhombus, and coefficients in
   -- [-100000, 100000]. Validation is the only guard keeping a rejected value out of
   -- the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Gimbal_Angles_To_Motor_Angles_Parameters.Instance;

      -- Values of the reference configuration that the cases below perturb.
      Steps : constant Packed_U32.T := (Value => Steps_Per_Revolution); -- [steps]
      Tip : constant Packed_F32.T := (Value => Half_Diagonal_Tip);     -- [rad]
      Tilt : constant Packed_F32.T := (Value => Half_Diagonal_Tilt);   -- [rad]
      Cone : constant Packed_F32.T := (Value => Theta_Max);            -- [rad]
      Flat_Row : constant Packed_F32x9.T := [others => 100.0];         -- [steps]

      -- Stage a known-good value for every parameter a case perturbs, so each
      -- rejection below is caused by the single perturbed value rather than by
      -- leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Steps_Per_Revolution (Steps)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Half_Diagonal_Tip (Tip)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Half_Diagonal_Tilt (Tilt)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Theta_Max (Cone)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_1_Coefficients_Row_0 (Flat_Row)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_2_Coefficients_Row_8 (Flat_Row)), Success);
      end Stage_Valid_Configuration;

      -- Stage the reference configuration with one parameter replaced and check that
      -- validation rejects the set.
      procedure Expect_Rejected (Par : in Parameter.T) is
      begin
         Stage_Valid_Configuration;
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
         Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);
      end Expect_Rejected;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- Zero steps per revolution, and more than 100000, are rejected:
      Expect_Rejected (Params.Steps_Per_Revolution ((Value => 0)));
      Expect_Rejected (Params.Steps_Per_Revolution ((Value => 100_001)));

      -- A half-diagonal of zero, and one of 1.6 rad, beyond 90 degrees, are rejected:
      Expect_Rejected (Params.Half_Diagonal_Tip ((Value => 0.0)));
      Expect_Rejected (Params.Half_Diagonal_Tilt ((Value => 1.6)));

      -- A cone angle of zero, and one that does not fit inside the rhombus, are
      -- rejected. The largest circle in the reference rhombus has a radius of about
      -- 0.2496 rad.
      Expect_Rejected (Params.Theta_Max ((Value => 0.0)));
      Expect_Rejected (Params.Theta_Max ((Value => 0.26)));

      -- A coefficient beyond 100000 steps is rejected, in the first row of motor 1
      -- and in the last row of motor 2:
      Expect_Rejected (Params.Motor_1_Coefficients_Row_0 ([0 => 100_001.0, others => 100.0]));
      Expect_Rejected (Params.Motor_2_Coefficients_Row_8 ([8 => -100_001.0, others => 100.0]));

      -- A non-finite coefficient is rejected. The value is injected as raw bytes
      -- because the compiler will not let a non-finite Short_Float be written as a
      -- literal, and because that is how one would arrive: as bytes from the ground.
      -- Staging accepts it, and converting it for the algorithm raises, which
      -- validation reports as a rejection.
      declare
         Par : Parameter.T := Params.Motor_1_Coefficients_Row_0 (Flat_Row);
      begin
         -- Overwrite the first of the nine big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Expect_Rejected (Par);
      end;

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Motor_1_Angle_History.Get_Count, 0);
      Natural_Assert.Eq (T.Motor_2_Angle_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Gimbal_Angles_To_Motor_Angles_Tests.Implementation;
