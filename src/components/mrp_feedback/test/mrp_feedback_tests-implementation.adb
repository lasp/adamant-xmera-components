--------------------------------------------------------------------------------
-- Mrp_Feedback Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Cmd_Torque_Body.Assertion; use Cmd_Torque_Body.Assertion;
with Mrp_Feedback_Enums; use Mrp_Feedback_Enums;
with Mrp_Feedback_Parameters;
with Packed_Control_Law_Type;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3_X4;
with Packed_F32x4;
with Packed_F32x9;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Wheel_Availability_X4;

package body Mrp_Feedback_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Gains, inertia, wheel configuration, guidance errors, and wheel speeds from the
   -- Python reference test (_tests/test_mrpFeedback.py).
   Gain_K : constant Packed_F32.T := (Value => 0.15);
   Gain_P : constant Packed_F32.T := (Value => 150.0);
   Gain_Ki : constant Packed_F32.T := (Value => 0.01);
   No_Integral : constant Packed_F32.T := (Value => 0.0);
   Integral_Limit : constant Packed_F32.T := (Value => 20.0);
   No_Integral_Limit : constant Packed_F32.T := (Value => 0.0);
   Normal_Law : constant Packed_Control_Law_Type.T := (Value => Control_Law_Type.Normal);
   Simple_Integral_Law : constant Packed_Control_Law_Type.T := (Value => Control_Law_Type.Simple_Integral);
   -- The control period is fixed at initialization, half a second as in the reference test.
   Control_Period : constant Short_Float := 0.5;
   Known_Torque : constant Packed_F32x3.T := [1.0, 1.0, 1.0];
   Inertia : constant Packed_F32x9.T := [1000.0, 0.0, 0.0,
                                         0.0, 800.0, 0.0,
                                         0.0, 0.0, 800.0];
   Spin_Axes : constant Packed_F32x3_X4.T := [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0],
      [0.577350269190, 0.577350269190, 0.577350269190]
   ];
   Wheel_Inertias : constant Packed_F32x4.T := [0.1, 0.1, 0.1, 0.1];
   All_Available : constant Wheel_Availability_X4.T := [others => Wheel_Availability.Available];
   None_Available : constant Wheel_Availability_X4.T := [others => Wheel_Availability.Unavailable];
   Wheels_1_And_3 : constant Wheel_Availability_X4.T := [
      Wheel_Availability.Available, Wheel_Availability.Unavailable,
      Wheel_Availability.Available, Wheel_Availability.Unavailable
   ];

   Zero_Torque : constant Cmd_Torque_Body.T := (Torque_Request_Body => [0.0, 0.0, 0.0]);

   -- Torques of magnitude 20 Nm computed in single precision agree with the double
   -- precision reference model to a few parts in a million.
   Epsilon : constant := 1.0E-4;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a configuration. The gains K and P, the known torque, the
   -- inertia, and the wheel geometry are the same in every case.
   procedure Apply_Configuration (
      Self : in out Instance;
      Ki : in Packed_F32.T;
      Limit : in Packed_F32.T;
      Law : in Packed_Control_Law_Type.T;
      Availability : in Wheel_Availability_X4.T
   ) is
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Feedback_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K (Gain_K)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (Gain_P)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki (Ki)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Limit)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Law_Type (Law)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Known_Torque_Pnt_B_B (Known_Torque)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Inertia (Inertia)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Inertias (Wheel_Inertias)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (Availability)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the reference guidance errors and wheel speeds.
   procedure Send_Tick (Self : in out Instance) is
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Attitude_Guidance := (
         Sigma_Br => [0.3, -0.5, 0.7],
         Omega_Br_B => [0.010, -0.020, 0.015],
         Omega_Rn_B => [-0.02, -0.01, 0.005],
         Domega_Rn_B => [0.0002, 0.0003, 0.0001]
      );
      T.Wheel_Speeds := (Rwa_1 => 10.0, Rwa_2 => 25.0, Rwa_3 => 50.0, Rwa_4 => 100.0);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Send_Tick;

   -- Check the torques published by the most recent tick.
   procedure Assert_Latest_Output (
      Self : in out Instance;
      Tick_Number : in Natural;
      Control_Torque : in Packed_F32x3.T;
      Integral_Feedback_Torque : in Packed_F32x3.T
   ) is
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Every tick publishes both data products.
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number * 2);
      Natural_Assert.Eq (T.Control_Torque_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Integral_Feedback_Torque_History.Get_Count, Tick_Number);
      Cmd_Torque_Body_Assert.Eq
        (T.Control_Torque_History.Get (Tick_Number),
         (Torque_Request_Body => Control_Torque),
         Epsilon => Epsilon);
      Cmd_Torque_Body_Assert.Eq
        (T.Integral_Feedback_Torque_History.Get (Tick_Number),
         (Torque_Request_Body => Integral_Feedback_Torque),
         Epsilon => Epsilon);
   end Assert_Latest_Output;

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

   -- Run the algorithm through the integral accumulation and reset sequence of the
   -- Python reference test to ensure the Ada to C to C++ integration is sound. With
   -- the integral gain on, the attitude error integral grows by K * dt * sigma_BR each
   -- tick, so the torques change from tick to tick. The reference test zeroes the
   -- integral after three ticks, which here is the reset connector, so ticks four and
   -- five repeat ticks one and two.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;

      type Expected_Torques is record
         Control : Packed_F32x3.T;
         Integral : Packed_F32x3.T;
      end record;

      Expected : constant array (1 .. 3) of Expected_Torques := [
         (Control => [-20.0159838549, 24.0980234969, -22.7657008421],
          Integral => [-15.03375, 24.05625, -18.07875]),
         (Control => [-20.0515160823, 24.1465543728, -22.8492006905],
          Integral => [-15.0675, 24.1125, -18.1575]),
         (Control => [-20.0870483097, 24.1950852486, -22.9327005388],
          Integral => [-15.10125, 24.16875, -18.23625])
      ];
   begin
      Apply_Configuration (Self, Ki => Gain_Ki, Limit => Integral_Limit, Law => Normal_Law, Availability => All_Available);

      -- Three ticks accumulate the integral:
      for I in Expected'Range loop
         Send_Tick (Self);
         Assert_Latest_Output (Self, I, Expected (I).Control, Expected (I).Integral);
      end loop;

      -- The reset connector zeroes the integral, so the sequence starts over:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for I in 1 .. 2 loop
         Send_Tick (Self);
         Assert_Latest_Output (Self, 3 + I, Expected (I).Control, Expected (I).Integral);
      end loop;
   end Test;

   -- Check the integral gain, control law variant, and wheel availability options
   -- against the Python reference model. Each case starts from a zeroed integral.
   overriding procedure Test_Control_Law_Variants (Self : in out Instance) is
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- A zero integral gain disables the integral term entirely:
      Apply_Configuration (Self, Ki => No_Integral, Limit => Integral_Limit, Law => Normal_Law, Availability => All_Available);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 1,
         Control_Torque => [-2.5840975404, 3.1143559006, -2.5926783603],
         Integral_Feedback_Torque => Zero_Torque.Torque_Request_Body);

      -- The simple integral law with a zero integral limit clamps the integral state to
      -- zero, and with no wheel available the wheel momentum term drops out:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Apply_Configuration (Self, Ki => Gain_Ki, Limit => No_Integral_Limit, Law => Simple_Integral_Law, Availability => None_Available);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 2,
         Control_Torque => [-17.395, 26.555, -20.935],
         Integral_Feedback_Torque => [-15.0, 24.0, -18.0]);

      -- Only the available wheels contribute to the momentum term:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Apply_Configuration (Self, Ki => Gain_Ki, Limit => Integral_Limit, Law => Simple_Integral_Law, Availability => Wheels_1_And_3);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 3,
         Control_Torque => [-17.57881, 26.68125, -20.98378],
         Integral_Feedback_Torque => [-15.03375, 24.05625, -18.07875]);
   end Test_Control_Law_Variants;

   -- The algorithm requires non-negative gains and integral limit, a finite known
   -- torque, a valid spacecraft inertia matrix, and unit wheel spin axes. Validation is the only guard keeping a rejected value out of the
   -- throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Feedback_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K (Gain_K)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (Gain_P)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki (Gain_Ki)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Integral_Limit)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Law_Type (Normal_Law)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Known_Torque_Pnt_B_B (Known_Torque)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Inertia (Inertia)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Inertias (Wheel_Inertias)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (All_Available)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A negative proportional gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K ((Value => -0.15))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative integral gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki ((Value => -0.01))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A singular inertia is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Inertia ([1000.0, 0.0, 0.0,
                                             0.0, 800.0, 0.0,
                                             0.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A wheel spin axis that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Rw_Spin_Axes ([[2.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [0.0, 0.0, 1.0]])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite known torque is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Known_Torque_Pnt_B_B (Known_Torque);
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
      T : Component.Mrp_Feedback.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Control_Torque_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Mrp_Feedback_Tests.Implementation;
