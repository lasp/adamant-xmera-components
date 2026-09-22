--------------------------------------------------------------------------------
-- Mrp_Steering Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Cmd_Torque_Body.Assertion; use Cmd_Torque_Body.Assertion;
with Mrp_Feedback_Enums; use Mrp_Feedback_Enums;
with Mrp_Steering_Parameters;
with Packed_Boolean;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3_X4;
with Packed_F32x4;
with Packed_F32x9;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Wheel_Availability_X4;

package body Mrp_Steering_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Gains, inertia, wheel configuration, guidance errors, and wheel speeds from the
   -- Python reference test (_tests/test_mrpSteering.py).
   Gain_K1 : constant Packed_F32.T := (Value => 0.15);
   No_K1 : constant Packed_F32.T := (Value => 0.0);
   Gain_K3 : constant Packed_F32.T := (Value => 1.0);
   No_K3 : constant Packed_F32.T := (Value => 0.0);
   -- 1.5 degrees per second.
   Omega_Max : constant Packed_F32.T := (Value => 0.02617993878);
   Small_Omega_Max : constant Packed_F32.T := (Value => 0.001);
   With_Feedforward : constant Packed_Boolean.T := (Value => False);
   Without_Feedforward : constant Packed_Boolean.T := (Value => True);
   Gain_P : constant Packed_F32.T := (Value => 150.0);
   Gain_Ki : constant Packed_F32.T := (Value => 0.01);
   Integral_Limit : constant Packed_F32.T := (Value => 20.0);
   -- The control period is fixed at initialization, half a second as in the reference test.
   Control_Period : constant Short_Float := 0.5;
   Known_Torque : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
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

   -- Torques of a few Nm computed in single precision agree with the double precision
   -- reference model to a few parts in a million.
   Epsilon : constant := 1.0E-4;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a configuration. The gains P and Ki, the integral limit, the known
   -- torque, the inertia, and the wheel configuration are the same in every case.
   procedure Apply_Configuration (
      Self : in out Instance;
      K1 : in Packed_F32.T;
      K3 : in Packed_F32.T;
      Max_Rate : in Packed_F32.T;
      Ignore_Feedforward : in Packed_Boolean.T
   ) is
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Steering_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K1 (K1)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cubic_Gain_K3 (K3)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Max (Max_Rate)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Ignore_Outer_Loop_Feedforward (Ignore_Feedforward)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (Gain_P)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki (Gain_Ki)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Integral_Limit)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Known_Torque_Pnt_B_B (Known_Torque)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Inertia (Inertia)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Inertias (Wheel_Inertias)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (All_Available)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the reference guidance errors and wheel speeds.
   procedure Send_Tick (Self : in out Instance) is
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;
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

   -- Check the torque published by the most recent tick.
   procedure Assert_Latest_Output (Self : in out Instance; Tick_Number : in Natural; Control_Torque : in Packed_F32x3.T) is
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Control_Torque_History.Get_Count, Tick_Number);
      Cmd_Torque_Body_Assert.Eq
        (T.Control_Torque_History.Get (Tick_Number),
         (Torque_Request_Body => Control_Torque),
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
   -- the integral gain on, the rate error integral grows each tick, so the torque
   -- changes from tick to tick. The reference test zeroes the integral after three
   -- ticks, which here is the reset connector, so ticks four and five repeat ticks one
   -- and two.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Expected torques, computed independently from the steering law, rate error
      -- integral, and momentum terms of the reference model.
      Expected : constant array (1 .. 3) of Packed_F32x3.T := [
         [-4.4480000794, 8.4093848702, -4.8611816778],
         [-4.4481620228, 8.4096088415, -4.8613844788],
         [-4.4483239663, 8.4098328127, -4.8615872797]
      ];
   begin
      Apply_Configuration (Self, K1 => Gain_K1, K3 => Gain_K3, Max_Rate => Omega_Max, Ignore_Feedforward => With_Feedforward);

      -- Three ticks accumulate the integral:
      for I in Expected'Range loop
         Send_Tick (Self);
         Assert_Latest_Output (Self, I, Expected (I));
      end loop;

      -- The reset connector zeroes the integral, so the sequence starts over:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for I in 1 .. 2 loop
         Send_Tick (Self);
         Assert_Latest_Output (Self, 3 + I, Expected (I));
      end loop;
   end Test;

   -- Check the feedforward toggle, the saturation gains, and the maximum rate options
   -- against the Python reference model. Each case starts from a zeroed integral.
   overriding procedure Test_Steering_Law_Variants (Self : in out Instance) is
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Leaving out the outer loop feedforward changes the inertia term only:
      Apply_Configuration (Self, K1 => Gain_K1, K3 => Gain_K3, Max_Rate => Omega_Max, Ignore_Feedforward => Without_Feedforward);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 1, [-4.6357667290, 8.4406835569, -4.8896912369]);

      -- Zero steering gains command a zero rate, so the law reduces to rate damping
      -- with the momentum and reference motion terms:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Apply_Configuration (Self, K1 => No_K1, K3 => No_K3, Max_Rate => Small_Omega_Max, Ignore_Feedforward => With_Feedforward);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 2, [-1.5391475404, 4.0394559006, -1.4877533603]);

      -- A small maximum rate saturates the proportional steering command:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Apply_Configuration (Self, K1 => Gain_K1, K3 => No_K3, Max_Rate => Small_Omega_Max, Ignore_Feedforward => Without_Feedforward);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 3, [-1.6768409312, 4.2183997367, -1.6183801474]);
   end Test_Steering_Law_Variants;

   -- The algorithm requires non-negative gains and integral limit, a positive maximum
   -- rate, a finite known torque, a valid spacecraft inertia matrix, and a unit spin
   -- axis in every wheel slot. Validation is the only guard keeping a rejected value out
   -- of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Steering_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K1 (Gain_K1)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cubic_Gain_K3 (Gain_K3)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Max (Omega_Max)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Ignore_Outer_Loop_Feedforward (With_Feedforward)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (Gain_P)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki (Gain_Ki)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Integral_Limit)), Success);
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
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K1 ((Value => -0.15))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero maximum rate is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Max ((Value => 0.0))), Success);
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
      T : Component.Mrp_Steering.Implementation.Tester.Instance_Access renames Self.Tester;
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

end Mrp_Steering_Tests.Implementation;
