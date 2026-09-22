--------------------------------------------------------------------------------
-- Css_Weighted_Least_Squares Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Interfaces; use Interfaces;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Css_Availability_X8;
with Css_Weighted_Least_Squares_Enums; use Css_Weighted_Least_Squares_Enums;
with Css_Weighted_Least_Squares_Parameters;
with Packed_Boolean;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_F32x8;
with Packed_F32x8.Assertion; use Packed_F32x8.Assertion;
with Packed_F32x24;
with Packed_F64x8;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Css_Weighted_Least_Squares_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The constellation, threshold, and readings come from the Python reference test
   -- (_tests/test_cssWeightedLeastSquaresF32.py): two opposing four-sensor pyramids, so
   -- a sun along any body axis lights at least three sensors.
   Boresights : constant Packed_F32x24.T := [
      +0.70710678, -0.5, +0.5,
      +0.70710678, -0.5, -0.5,
      +0.70710678, +0.5, -0.5,
      +0.70710678, +0.5, +0.5,
      -0.70710678, +0.0, +0.70710678,
      -0.70710678, +0.70710678, +0.0,
      -0.70710678, +0.0, -0.70710678,
      -0.70710678, -0.70710678, +0.0
   ];
   All_Available : constant Css_Availability_X8.T := [others => Sensor_Availability.Available];
   Sensor_0_Unavailable : constant Css_Availability_X8.T :=
      [0 => Sensor_Availability.Unavailable, others => Sensor_Availability.Available];
   Unweighted : constant Packed_Boolean.T := (Value => False);
   Weighted : constant Packed_Boolean.T := (Value => True);
   Use_Thresh : constant Packed_F32.T := (Value => 0.15);
   -- The control period is fixed at initialization, half a second as in the reference test.
   Control_Period : constant Short_Float := 0.5;

   -- Cosine readings for a sun along each body axis. A sensor facing away reads zero.
   Cos_45 : constant := 0.70710678118654746;
   Plus_X : constant Packed_F64x8.T := [Cos_45, Cos_45, Cos_45, Cos_45, 0.0, 0.0, 0.0, 0.0];
   Minus_X : constant Packed_F64x8.T := [0.0, 0.0, 0.0, 0.0, Cos_45, Cos_45, Cos_45, Cos_45];
   Plus_Y : constant Packed_F64x8.T := [0.0, 0.0, 0.5, 0.5, 0.0, Cos_45, 0.0, 0.0];
   Minus_Y : constant Packed_F64x8.T := [0.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, Cos_45];
   Plus_Z : constant Packed_F64x8.T := [0.5, 0.0, 0.0, 0.5, Cos_45, 0.0, 0.0, 0.0];
   Minus_Z : constant Packed_F64x8.T := [0.0, 0.5, 0.5, 0.0, 0.0, 0.0, Cos_45, 0.0];
   No_Sun : constant Packed_F64x8.T := [others => 0.0];

   Zero : constant Packed_F32x3.U := [0.0, 0.0, 0.0];
   No_Residuals : constant Packed_F32x8.U := [others => 0.0];

   -- Headings computed in single precision agree with the double precision reference
   -- model to about a part in a million.
   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a configuration. The boresights are the same in every case.
   procedure Apply_Configuration (
      Self : in out Instance;
      Availability : in Css_Availability_X8.T;
      Weights : in Packed_Boolean.T;
      Thresh : in Packed_F32.T
   ) is
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Weighted_Least_Squares_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Boresights)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Availability (Availability)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Use_Measurements_As_Weights (Weights)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh (Thresh)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the given readings.
   procedure Send_Tick (Self : in out Instance; Readings : in Packed_F64x8.T) is
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Css_Sensor_Input := (Data => Readings);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Send_Tick;

   -- Discard the prior heading through the reset connector.
   procedure Reset (Self : in out Instance) is
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Reset;

   -- Check the heading, rate, and sensor count published by the most recent tick.
   -- Every tick publishes all four products. The arrays are unpacked first, so the
   -- comparisons run on native floats.
   procedure Assert_Latest_Estimate (
      Self : in out Instance;
      Tick_Number : in Natural;
      Heading : in Packed_F32x3.U;
      Count : in Unsigned_32;
      Omega : in Packed_F32x3.U := Zero;
      Omega_Epsilon : in Long_Float := 1.0E-6
   ) is
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number * 4);
      Natural_Assert.Eq (T.Sun_Heading_B_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Omega_Bn_B_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Post_Fit_Residuals_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Num_Css_Viewing_Sun_History.Get_Count, Tick_Number);
      Packed_F32x3_U_Assert.Eq (Packed_F32x3.Unpack (T.Sun_Heading_B_History.Get (Tick_Number)), Heading, Epsilon => Epsilon);
      Packed_F32x3_U_Assert.Eq (Packed_F32x3.Unpack (T.Omega_Bn_B_History.Get (Tick_Number)), Omega, Epsilon => Omega_Epsilon);
      Unsigned_32_Assert.Eq (T.Num_Css_Viewing_Sun_History.Get (Tick_Number).Value, Count);
   end Assert_Latest_Estimate;

   -- Check the residuals published by the most recent tick.
   procedure Assert_Latest_Residuals (Self : in out Instance; Tick_Number : in Natural; Residuals : in Packed_F32x8.U) is
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Packed_F32x8_U_Assert.Eq (Packed_F32x8.Unpack (T.Post_Fit_Residuals_History.Get (Tick_Number)), Residuals, Epsilon => Epsilon);
   end Assert_Latest_Residuals;

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
      Self.Tester.Component_Instance.Init (Control_Period => Control_Period);

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

   -- Fit the sun heading along each body axis from the Python reference test, with and
   -- without measurement weights, to ensure the Ada to C to C++ integration is sound.
   -- The constellation is symmetric about every body axis, so the fit returns the true
   -- heading exactly, every residual is zero, and the weights drop out of the normal
   -- equations. A sun along x lights four sensors, along y or z three. Each heading is
   -- preceded by a reset so no rate is differenced between them.
   overriding procedure Test (Self : in out Instance) is
      type Axis_Case is record
         Readings : Packed_F64x8.T;
         Heading : Packed_F32x3.U;
         Count : Unsigned_32;
      end record;
      Cases : constant array (1 .. 6) of Axis_Case := [
         (Plus_X, [1.0, 0.0, 0.0], 4),
         (Minus_X, [-1.0, 0.0, 0.0], 4),
         (Plus_Y, [0.0, 1.0, 0.0], 3),
         (Minus_Y, [0.0, -1.0, 0.0], 3),
         (Plus_Z, [0.0, 0.0, 1.0], 3),
         (Minus_Z, [0.0, 0.0, -1.0], 3)
      ];
      Tick_Number : Natural := 0;
   begin
      for Weights in Boolean loop
         Apply_Configuration (Self, All_Available, (Value => Weights), Use_Thresh);
         for C of Cases loop
            Reset (Self);
            Send_Tick (Self, C.Readings);
            Tick_Number := @ + 1;
            Assert_Latest_Estimate (Self, Tick_Number, C.Heading, C.Count);
            Assert_Latest_Residuals (Self, Tick_Number, No_Residuals);
         end loop;
      end loop;
   end Test;

   -- Check the minimum norm fits with two and one lit sensors, the effect of an
   -- unavailable sensor, the residual indexing, and the no signal case against the
   -- Python reference model.
   overriding procedure Test_Partial_Coverage (Self : in out Instance) is
      -- A heading 40.68 degrees off +z in the x-z plane lights only sensors 0 and 3.
      Low_Coverage : constant Packed_F64x8.T :=
         [0.8400970050, 0.0817350897, 0.0817350897, 0.8400970050, 0.0753268055, 0.0, 0.0, 0.0];
      -- Sensor 0 blinded, so sensor 3 is the only reading above the threshold.
      Single_Sensor : constant Packed_F64x8.T :=
         [0.0, 0.0817350897, 0.0817350897, 0.8400970050, 0.0753268055, 0.0, 0.0, 0.0];
      Only_Sensor_0 : constant Packed_F64x8.T := [0 => 0.7071, others => 0.0];
      Sensors_0_And_1 : constant Packed_F64x8.T := [0 => 0.7071, 1 => 0.7071, others => 0.0];
      -- A sun along -x with sensor 4 reading ten percent low, so the four measurements
      -- disagree and every residual is non-zero.
      Weak_Sensor_4 : constant Packed_F64x8.T :=
         [0.0, 0.0, 0.0, 0.0, 0.6363961031, Cos_45, Cos_45, Cos_45];
      Tick_Number : Natural := 0;
   begin
      Apply_Configuration (Self, All_Available, Unweighted, Use_Thresh);

      -- Two lit sensors reading the same cosine give the minimum norm solution, the
      -- direction that bisects their boresights:
      Send_Tick (Self, Low_Coverage);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.8164965809, 0.0, 0.5773502692], 2);

      -- One lit sensor fixes only a cone about its boresight, so the estimator returns
      -- the boresight itself:
      Reset (Self);
      Send_Tick (Self, Single_Sensor);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.70710678, 0.5, 0.5], 1);

      -- An unavailable sensor takes no part in the cycle. Sensors 1 to 3 fit the same
      -- +x heading without it, and it is not counted among the sensors viewing the sun:
      Apply_Configuration (Self, Sensor_0_Unavailable, Unweighted, Use_Thresh);
      Reset (Self);
      Send_Tick (Self, Plus_X);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [1.0, 0.0, 0.0], 3);

      -- With only the unavailable sensor lit there is no measurement, so no heading:
      Reset (Self);
      Send_Tick (Self, Only_Sensor_0);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, Zero, 0);

      -- An unavailable sensor does not take a healthy one down with it:
      Reset (Self);
      Send_Tick (Self, Sensors_0_And_1);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.70710678, -0.5, -0.5], 1);

      -- The residuals are indexed by observation, not by sensor slot: the lit sensors
      -- are 4 to 7, and their residuals land in entries 0 to 3:
      Apply_Configuration (Self, All_Available, Unweighted, Use_Thresh);
      Reset (Self);
      Send_Tick (Self, Weak_Sensor_4);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [-0.9986876635, 0.0, -0.0512147520], 4);
      Assert_Latest_Residuals (Self, Tick_Number,
         [-0.0176776695, 0.0176776695, -0.0176776695, 0.0176776695, 0.0, 0.0, 0.0, 0.0]);

      -- With no reading above the threshold there is no sun to estimate, so the heading
      -- is zero rather than stale or invented, and no residual is reported:
      Reset (Self);
      Send_Tick (Self, No_Sun);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, Zero, 0);
      Assert_Latest_Residuals (Self, Tick_Number, No_Residuals);
   end Test_Partial_Coverage;

   -- Check the body rate from two successive headings, including a slow slew, a heading
   -- reversal, and the reset connector. The rate is the angle between the headings over
   -- the control period, about the axis that carries one into the other.
   overriding procedure Test_Rate_Estimate (Self : in out Instance) is
      Pi : constant := 3.14159265358979;
      -- The sun a milliradian off +x toward +y.
      Slow_Slew : constant Packed_F64x8.T :=
         [0.7066064277, 0.7066064277, 0.7076064275, 0.7076064275, 0.0, 0.0, 0.0, 0.0];
      Tick_Number : Natural := 0;
   begin
      Apply_Configuration (Self, All_Available, Unweighted, Use_Thresh);

      -- The first heading has nothing to difference against, and an unchanged heading
      -- gives no rate:
      Send_Tick (Self, Plus_X);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [1.0, 0.0, 0.0], 4);
      Send_Tick (Self, Plus_X);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [1.0, 0.0, 0.0], 4);

      -- A 90 degree step from +x to +y in one half second period is pi rad/s about -z.
      -- The rate is an arc cosine divided by the period, so single precision round-off
      -- on the heading is amplified by 1/dt:
      Send_Tick (Self, Plus_Y);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.0, 1.0, 0.0], 3, Omega => [0.0, 0.0, -Pi], Omega_Epsilon => 1.0E-4);
      Send_Tick (Self, Plus_Y);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.0, 1.0, 0.0], 3);

      -- The reset discards the prior heading, so the first heading after it has nothing
      -- to difference against, and the step back to +x is then reported as +pi about z:
      Reset (Self);
      Send_Tick (Self, Plus_Y);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.0, 1.0, 0.0], 3);
      Send_Tick (Self, Plus_X);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [1.0, 0.0, 0.0], 4, Omega => [0.0, 0.0, Pi], Omega_Epsilon => 1.0E-4);

      -- A milliradian sweep in one period is 2 mrad/s about -z. The cosine of that angle
      -- is one to within four parts in ten million, so the rate has to come from the
      -- cross product rather than the dot product alone:
      Reset (Self);
      Send_Tick (Self, Plus_X);
      Tick_Number := @ + 1;
      Send_Tick (Self, Slow_Slew);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.9999995, 0.001, 0.0], 4, Omega => [0.0, 0.0, -0.002], Omega_Epsilon => 5.0E-6);

      -- Two opposed headings fix a rotation angle but no axis, so the estimator reports
      -- no rate rather than a confident direction:
      Reset (Self);
      Send_Tick (Self, Plus_X);
      Tick_Number := @ + 1;
      Send_Tick (Self, Minus_X);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [-1.0, 0.0, 0.0], 4);
   end Test_Rate_Estimate;

   -- Check that a parameter update changes the live fit, and that the fit weights do
   -- not carry over from a cycle with more lit sensors.
   overriding procedure Test_Reconfigure (Self : in out Instance) is
      -- The first heading lights five sensors and the second three, so both stay in the
      -- weighted least squares branch while the lit count drops between cycles.
      Many_Lit : constant Packed_F64x8.T :=
         [0.9014650863, 0.1941650863, 0.0, 0.2784650863, 0.2638215401, 0.0, 0.0, 0.2042124384];
      Few_Lit : constant Packed_F64x8.T :=
         [0.0, 0.0, 0.5153833150, 0.8629833150, 0.0, 0.3541190760, 0.0, 0.0];
      Tick_Number : Natural := 0;
   begin
      -- A sun along +y reads 0.5 on two sensors and 0.7071 on a third. Raising the
      -- threshold past 0.5 drops the fit from three sensors to one:
      Apply_Configuration (Self, All_Available, Unweighted, Use_Thresh);
      Send_Tick (Self, Plus_Y);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.0, 1.0, 0.0], 3);
      Apply_Configuration (Self, All_Available, Unweighted, (Value => 0.6));
      Reset (Self);
      Send_Tick (Self, Plus_Y);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [-0.70710678, 0.70710678, 0.0], 1);

      -- With measurement weights, a sensor that takes no part in a cycle carries a
      -- weight of zero. A weight left behind by the five-sensor cycle would bias the
      -- three-sensor fit, so both are checked against the double precision solution
      -- over their own lit sensors:
      Apply_Configuration (Self, All_Available, Weighted, Use_Thresh);
      Reset (Self);
      Send_Tick (Self, Many_Lit);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.3341846396, -0.6229713658, 0.7072674912], 5);
      Reset (Self);
      Send_Tick (Self, Few_Lit);
      Tick_Number := @ + 1;
      Assert_Latest_Estimate (Self, Tick_Number, [0.3635049982, 0.8643118844, 0.3476047796], 3);
   end Test_Reconfigure;

   -- The algorithm requires a unit boresight for every available sensor and a use
   -- threshold in [0, 1]. Validation is the only guard keeping a rejected value out of
   -- the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Weighted_Least_Squares_Parameters.Instance;

      -- The reference constellation with sensor 0's boresight doubled in length.
      Long_Boresight_0 : constant Packed_F32x24.T := [
         +1.41421356, -1.0, +1.0,
         +0.70710678, -0.5, -0.5,
         +0.70710678, +0.5, -0.5,
         +0.70710678, +0.5, +0.5,
         -0.70710678, +0.0, +0.70710678,
         -0.70710678, +0.70710678, +0.0,
         -0.70710678, +0.0, -0.70710678,
         -0.70710678, -0.70710678, +0.0
      ];

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Boresights)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Availability (All_Available)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Use_Measurements_As_Weights (Unweighted)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh (Use_Thresh)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A boresight that is not a unit vector is rejected for an available sensor:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Long_Boresight_0)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The same boresight is accepted once that sensor is unavailable, since an
      -- unavailable sensor's boresight is never read:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Long_Boresight_0)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Availability (Sensor_0_Unavailable)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A negative use threshold is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh ((Value => -0.1))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A use threshold above one is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh ((Value => 1.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite boresight component is rejected. The value is injected as raw bytes
      -- because the compiler will not let a non-finite Short_Float be written as a
      -- literal, and because that is how one would arrive: as bytes from the ground.
      -- Staging accepts it, and converting it for the algorithm raises, which validation
      -- reports as a rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Css_N_Hat_B (Boresights);
      begin
         -- Overwrite the first big-endian float with +infinity.
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
      T : Component.Css_Weighted_Least_Squares.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Sun_Heading_B_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Css_Weighted_Least_Squares_Tests.Implementation;
