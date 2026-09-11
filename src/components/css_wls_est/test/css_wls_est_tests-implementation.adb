--------------------------------------------------------------------------------
-- Css_Wls_Est Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Css_Sensor_Values;
with Css_Wls_Est_Parameters;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_F32x8.Assertion; use Packed_F32x8.Assertion;
with Packed_F32x24;
with Packed_F64x8;
with Packed_U32.Assertion; use Packed_U32.Assertion;
with Parameter_Enums.Assertion;
with Sys_Time;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Css_Wls_Est_Tests.Implementation is

   -- Eight-sensor coarse sun sensor constellation: two opposing four-sensor pyramids,
   -- so a sun heading along any body axis lights at least three sensors and the least
   -- squares fit is over-determined. Row major, three components per sensor. Taken from
   -- the algorithm's own reference test in fp32-fsw-xmera.
   Sqrt_Half : constant Short_Float := 0.70710678;
   Css_Orientations : constant Packed_F32x24.T := [
      +Sqrt_Half, -0.5, +0.5,
      +Sqrt_Half, -0.5, -0.5,
      +Sqrt_Half, +0.5, -0.5,
      +Sqrt_Half, +0.5, +0.5,
      -Sqrt_Half, +0.0, +Sqrt_Half,
      -Sqrt_Half, +Sqrt_Half, +0.0,
      -Sqrt_Half, +0.0, -Sqrt_Half,
      -Sqrt_Half, -Sqrt_Half, +0.0
   ];

   -- Unity calibration, so a reading is the raw cosine.
   Css_Biases : constant Packed_F32x8.T := [others => 1.0];

   -- [-] Cosine at or below which a reading is treated as noise and dropped from the fit.
   Use_Thresh : constant Short_Float := 0.15;

   -- The six body axes. Along each of them the constellation is symmetric, so the fit
   -- returns the truth exactly.
   type Heading_Array is array (Natural range <>) of Packed_F32x3.T;
   Principal_Axes : constant Heading_Array (0 .. 5) := [
      [+1.0, +0.0, +0.0],
      [-1.0, +0.0, +0.0],
      [+0.0, +1.0, +0.0],
      [+0.0, -1.0, +0.0],
      [+0.0, +0.0, +1.0],
      [+0.0, +0.0, -1.0]
   ];

   -- A heading 40.68 degrees off the +z axis in the x-z plane, which lights only sensors
   -- 0 and 3. The components are the sine and cosine of that latitude.
   Low_Coverage_Heading : constant Packed_F32x3.T := [0.65196812, 0.0, 0.75824672];

   -- A ninety degree step of the sun across a half second period, in radians per second.
   Pi_Rate : constant Short_Float := 3.14159265;

   -- Tick times half a second apart, so a ninety degree step of the sun across one
   -- period is a whole number of radians per second. Subseconds are sixteen bits, so
   -- half a second is 32768. The times are non-zero because the tester reads a zero
   -- data dependency timestamp as a request for its own clock instead.
   Tick_1 : constant Sys_Time.T := (Seconds => 1, Subseconds => 0);
   Tick_2 : constant Sys_Time.T := (Seconds => 1, Subseconds => 32_768);
   Tick_3 : constant Sys_Time.T := (Seconds => 2, Subseconds => 0);

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Per-sensor cosine readings for a sun heading. A coarse sun sensor cannot report a
   -- negative cosine, so a sensor facing away from the sun reads zero rather than the
   -- signed dot product.
   function Cos_Values (Sun_Heading_B : in Packed_F32x3.T) return Css_Sensor_Values.T is
      Result : Css_Sensor_Values.T := (Data => [others => 0.0]);
   begin
      for Sensor in 0 .. Packed_F64x8.Length - 1 loop
         declare
            Dot : constant Short_Float :=
               Css_Orientations (Sensor * 3 + 0) * Sun_Heading_B (0) +
               Css_Orientations (Sensor * 3 + 1) * Sun_Heading_B (1) +
               Css_Orientations (Sensor * 3 + 2) * Sun_Heading_B (2);
         begin
            if Dot > 0.0 then
               Result.Data (Sensor) := Long_Float (Dot);
            end if;
         end;
      end loop;
      return Result;
   end Cos_Values;

   -- The number of readings the estimator will keep, which is the count it must report.
   function Num_Active (Readings : in Css_Sensor_Values.T; Thresh : in Short_Float) return Unsigned_32 is
      Count : Unsigned_32 := 0;
   begin
      for Sensor in 0 .. Packed_F64x8.Length - 1 loop
         if Readings.Data (Sensor) > Long_Float (Thresh) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Num_Active;

   -- Drive one tick with the given readings at the given time. The data dependency is
   -- stamped with the tick time, which is what the component's own staleness check
   -- compares against, so a test is free to choose tick times and thereby control the
   -- estimator's update period.
   procedure Send_Tick (
      T : in Component.Css_Wls_Est.Implementation.Tester.Instance_Access;
      Readings : in Css_Sensor_Values.T;
      Time : in Sys_Time.T;
      Count : in Unsigned_32
   ) is
   begin
      T.Css_Sensor_Input := Readings;
      T.Data_Dependency_Timestamp_Override := Time;
      T.Tick_T_Send ((Time => Time, Count => Count));
   end Send_Tick;

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

   -- Along each body axis the constellation is symmetric about the heading, so the
   -- normal matrix comes out diagonal and the fit returns the true heading exactly.
   -- Every lit sensor is then predicted exactly and every sensor facing away is
   -- predicted at the zero it reported, so the whole residual vector is zero. That
   -- symmetry also makes the weights drop out of the normal equations, so the weighted
   -- and unweighted fits agree and both paths are checked against the same truth.
   overriding procedure Test_Nominal_Full_Coverage (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Wls_Est_Parameters.Instance;
      Weight_Settings : constant array (0 .. 1) of Boolean := [False, True];
      Product_Count : Natural := 0;
   begin
      for Weights of Weight_Settings loop
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Css_Orientations)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Bias (Css_Biases)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh ((Value => Use_Thresh))), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Use_Weights ((Value => Weights))), Success);
         Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

         for Axis of Principal_Axes loop
            T.Css_Sensor_Input := Cos_Values (Axis);
            T.Tick_T_Send ((Time => T.System_Time, Count => 0));
            Product_Count := Product_Count + 1;

            Natural_Assert.Eq (T.Sun_Heading_B_History.Get_Count, Product_Count);
            Packed_F32x3_Assert.Eq (T.Sun_Heading_B_History.Get (Product_Count), Axis, Epsilon => 1.0e-6);
            Packed_F32x8_Assert.Eq (T.Post_Fit_Residuals_History.Get (Product_Count), [others => 0.0], Epsilon => 1.0e-6);
            Packed_U32_Assert.Eq (
               T.Num_Active_Css_History.Get (Product_Count),
               (Value => Num_Active (Cos_Values (Axis), Use_Thresh)));
         end loop;
      end loop;
   end Test_Nominal_Full_Coverage;

   -- Sensors 0 and 3 are lit and read the same cosine, so the minimum norm solution is
   -- the direction that bisects their two boresights. It is 14 degrees off the true
   -- heading, which is the price of the missing third measurement rather than an error
   -- in the fit.
   overriding procedure Test_Two_Sensor_Coverage (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
      Readings : constant Css_Sensor_Values.T := Cos_Values (Low_Coverage_Heading);
      -- The normalized sum of boresights 0 and 3, which differ only in the sign of
      -- their y component.
      Expected_Heading : constant Packed_F32x3.T := [0.81649658, 0.0, 0.57735027];
   begin
      T.Css_Sensor_Input := Readings;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      Packed_U32_Assert.Eq (T.Num_Active_Css_History.Get (1), (Value => 2));
      Packed_F32x3_Assert.Eq (T.Sun_Heading_B_History.Get (1), Expected_Heading, Epsilon => 1.0e-6);
   end Test_Two_Sensor_Coverage;

   -- One reading fixes only the cone of headings about that sensor's boresight, so the
   -- estimator returns the boresight itself. That is a guess on the cone, not an
   -- estimate of the heading.
   overriding procedure Test_Single_Sensor_Coverage (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
      Readings : Css_Sensor_Values.T := Cos_Values (Low_Coverage_Heading);
      -- Boresight 3, the only reading left above the threshold.
      Expected_Heading : constant Packed_F32x3.T := [Sqrt_Half, 0.5, 0.5];
   begin
      -- Blind sensor 0, leaving sensor 3 as the only reading above the threshold.
      Readings.Data (0) := 0.0;

      T.Css_Sensor_Input := Readings;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      Packed_U32_Assert.Eq (T.Num_Active_Css_History.Get (1), (Value => 1));
      Packed_F32x3_Assert.Eq (T.Sun_Heading_B_History.Get (1), Expected_Heading, Epsilon => 1.0e-6);
   end Test_Single_Sensor_Coverage;

   -- With no sun the estimator reports the zero vector rather than a stale or invented
   -- heading, and the residuals are the raw measurements differenced against a zero
   -- prediction.
   overriding procedure Test_No_Signal (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Css_Sensor_Input := (Data => [others => 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      Packed_U32_Assert.Eq (T.Num_Active_Css_History.Get (1), (Value => 0));
      Packed_F32x3_Assert.Eq (T.Sun_Heading_B_History.Get (1), [0.0, 0.0, 0.0], Epsilon => 0.0);
      Packed_F32x8_Assert.Eq (T.Post_Fit_Residuals_History.Get (1), [others => 0.0], Epsilon => 1.0e-6);
   end Test_No_Signal;

   -- The first heading has nothing to difference against, so no rate is reported. A
   -- ninety degree step of the sun from +x to +y across one half second period is an
   -- apparent rate of pi radians per second about -z.
   overriding procedure Test_Rate_Estimate (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
      -- The rate is an arc cosine divided by the period, so float32 round-off on the
      -- heading is amplified by one over the period.
      Rate_Epsilon : constant Long_Float := 1.0e-5;
   begin
      Send_Tick (T, Cos_Values (Principal_Axes (0)), Tick_1, 0);
      Packed_F32x3_Assert.Eq (T.Omega_Bn_B_History.Get (1), [0.0, 0.0, 0.0], Epsilon => 0.0);

      Send_Tick (T, Cos_Values (Principal_Axes (2)), Tick_2, 1);
      Packed_F32x3_Assert.Eq (
         T.Omega_Bn_B_History.Get (2), [0.0, 0.0, -Pi_Rate], Epsilon => Rate_Epsilon);
   end Test_Rate_Estimate;

   -- A heading along +y reads 0.5 on two sensors and 0.7071 on a third, so raising the
   -- threshold past 0.5 from the ground drops the fit from three sensors to one. The
   -- reconfiguration also discards the prior heading, so the change in the estimate is
   -- not differenced into a rate the spacecraft never turned through.
   overriding procedure Test_Parameter_Update_Reconfigures (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Wls_Est_Parameters.Instance;
      Readings : constant Css_Sensor_Values.T := Cos_Values (Principal_Axes (2));
      Raised_Thresh : constant Short_Float := 0.6;
   begin
      -- Two ticks at the default threshold, so a prior heading is on hand and the
      -- second tick's rate is the zero of an unchanging heading rather than of a
      -- missing one.
      Send_Tick (T, Readings, Tick_1, 0);
      Send_Tick (T, Readings, Tick_2, 1);
      Packed_U32_Assert.Eq (T.Num_Active_Css_History.Get (2), (Value => 3));

      -- Raise the threshold from the ground.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Css_Orientations)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Bias (Css_Biases)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh ((Value => Raised_Thresh))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Use_Weights ((Value => False))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- The same readings now leave a single sensor above the threshold, and the
      -- estimate can only be that sensor's boresight.
      Send_Tick (T, Readings, Tick_3, 2);
      Packed_U32_Assert.Eq (T.Num_Active_Css_History.Get (3), (Value => 1));
      Packed_F32x3_Assert.Eq (
         T.Sun_Heading_B_History.Get (3), [-Sqrt_Half, Sqrt_Half, 0.0], Epsilon => 1.0e-6);

      -- The prior heading was discarded with the reconfiguration, so the step is not
      -- reported as a rate.
      Packed_F32x3_Assert.Eq (T.Omega_Bn_B_History.Get (3), [0.0, 0.0, 0.0], Epsilon => 0.0);
   end Test_Parameter_Update_Reconfigures;

   -- The boresights must be unit vectors, the biases non-negative and the threshold a
   -- cosine. Validation is the only guard keeping a rejected set out of the throwing
   -- Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Css_Wls_Est.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Wls_Est_Parameters.Instance;

      -- Stage the full valid set. Every case below starts from this baseline so a
      -- rejection can only come from the single value that was perturbed.
      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Css_Orientations)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Bias (Css_Biases)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh ((Value => Use_Thresh))), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Use_Weights ((Value => False))), Success);
      end Stage_Valid_Set;

      Non_Unit_Boresights : Packed_F32x24.T := Css_Orientations;
      Negative_Bias : Packed_F32x8.T := Css_Biases;
   begin
      -- The baseline set is accepted:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A boresight that is not a unit vector is rejected:
      Non_Unit_Boresights (0) := 1.0;
      Non_Unit_Boresights (1) := 1.0;
      Non_Unit_Boresights (2) := 0.0;
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_N_Hat_B (Non_Unit_Boresights)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative calibration scale factor is rejected:
      Negative_Bias (3) := -1.0;
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Css_Bias (Negative_Bias)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A threshold outside the range of a cosine is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensor_Use_Thresh ((Value => 1.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above were
      -- caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Css_Wls_Est_Tests.Implementation;
