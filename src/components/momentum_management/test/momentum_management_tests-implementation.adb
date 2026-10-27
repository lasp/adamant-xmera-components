--------------------------------------------------------------------------------
-- Momentum_Management Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Cmd_Torque_Body.Assertion; use Cmd_Torque_Body.Assertion;
with Momentum_Management_Parameters;
with Mrp_Feedback_Enums; use Mrp_Feedback_Enums;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3_X4;
with Packed_F32x4;
with Packed_F32x9;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Wheel_Availability_X4;

package body Momentum_Management_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Thresholds, gains, wheel configuration, and wheel speeds from the Python
   -- reference test (_tests/test_momentumManagement.py). The wheel speeds give a
   -- cluster momentum of [6.7735, 3.2735, 10.7735] Nms.
   Nominal_Hs_Min : constant Packed_F32.T := (Value => 100.0 / 6000.0 * 100.0);
   High_Hs_Min : constant Packed_F32.T := (Value => 1000.0 / 6000.0 * 100.0);
   No_Hs_Min : constant Packed_F32.T := (Value => 0.0);
   Gain_K : constant Packed_F32.T := (Value => 0.05);
   Gain_Ki : constant Packed_F32.T := (Value => 0.01);
   No_Integral : constant Packed_F32.T := (Value => 0.0);
   Integral_Limit : constant Packed_F32.T := (Value => 1000.0);
   Tight_Integral_Limit : constant Packed_F32.T := (Value => 5.0);
   No_Integral_Limit : constant Packed_F32.T := (Value => 0.0);
   -- The control period is fixed at initialization, half a second as in the reference test.
   Control_Period : constant Short_Float := 0.5;
   Identity : constant Packed_F32x9.T := [1.0, 0.0, 0.0,
                                          0.0, 1.0, 0.0,
                                          0.0, 0.0, 1.0];
   -- Projector onto the plane perpendicular to the cluster momentum, so nothing is
   -- left to dump:
   Plane_Of_Cluster_Momentum : constant Packed_F32x9.T := [0.7342804473, -0.1284171146, -0.4226366249,
                                                           -0.1284171146, 0.9379384951, -0.2042520971,
                                                           -0.4226366249, -0.2042520971, 0.3277810576];
   -- Projector onto the plane perpendicular to [0, 0.2716, -0.9624], a direction off
   -- the body axes as a gimbaled thruster's moment arm is:
   Plane_Off_Axis : constant Packed_F32x9.T := [1.0, 0.0, 0.0,
                                                0.0, 0.9262319882, 0.2613929842,
                                                0.0, 0.2613929842, 0.0737680118];
   Zero_Momentum : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   Desired_Momentum : constant Packed_F32x3.T := [2.0, -1.0, 5.0];
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

   Zero_Torque : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   -- The whole cluster momentum dumped with the proportional gain alone:
   Nominal_Torque : constant Packed_F32x3.T := [-0.3386751346, -0.1636751346, -0.5386751346];

   -- Torques of magnitude 0.5 Nm computed in single precision agree with the double
   -- precision reference model to a few parts in ten million.
   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a configuration. The proportional gain and the wheel geometry
   -- are the same in every case.
   procedure Apply_Configuration (
      Self : in out Instance;
      Hs_Min : in Packed_F32.T;
      Ki : in Packed_F32.T;
      Limit : in Packed_F32.T;
      Projection : in Packed_F32x9.T;
      Desired : in Packed_F32x3.T;
      Availability : in Wheel_Availability_X4.T
   ) is
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Momentum_Management_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Hs_Min (Hs_Min)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K (Gain_K)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki (Ki)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Limit)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Dumpable_Projection (Projection)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Hs_Desired (Desired)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Inertias (Wheel_Inertias)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (Availability)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the reference wheel speeds.
   procedure Send_Tick (Self : in out Instance) is
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Wheel_Speeds := (Rwa_1 => 10.0, Rwa_2 => -25.0, Rwa_3 => 50.0, Rwa_4 => 100.0);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Send_Tick;

   -- Check the torque published by the most recent tick.
   procedure Assert_Latest_Output (
      Self : in out Instance;
      Tick_Number : in Natural;
      Commanded_Torque : in Packed_F32x3.T
   ) is
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Every tick publishes the torque.
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Commanded_Torque_History.Get_Count, Tick_Number);
      Cmd_Torque_Body_Assert.Eq
        (T.Commanded_Torque_History.Get (Tick_Number),
         (Torque_Request_Body => Commanded_Torque),
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

   -- Run the algorithm through the integral accumulation and reset sequence to
   -- ensure the Ada to C to C++ integration is sound. With the integral gain on, the
   -- trapezoidal integral of the momentum difference grows by half the control
   -- period times the difference on the first tick and by the full product on every
   -- tick after, so the torque grows from tick to tick. The reset connector zeroes
   -- the integral, so ticks four and five repeat ticks one and two.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;

      Expected : constant array (1 .. 3) of Packed_F32x3.T := [
         [-0.3556088913, -0.1718588913, -0.5656088913],
         [-0.3894764048, -0.1882264048, -0.6194764048],
         [-0.4233439182, -0.2045939182, -0.6733439182]
      ];
   begin
      Apply_Configuration (Self, Hs_Min => Nominal_Hs_Min, Ki => Gain_Ki, Limit => Integral_Limit,
         Projection => Identity, Desired => Zero_Momentum, Availability => All_Available);

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

   -- Check the threshold, the dumpable projection, the desired momentum, and the
   -- wheel availability options against the Python reference model. The integral
   -- gain is off, so each torque is a pure function of the wheel speeds.
   overriding procedure Test_Dumping_Variants (Self : in out Instance) is
      Tick_Number : Natural := 0;

      procedure Check (
         Hs_Min : in Packed_F32.T;
         Projection : in Packed_F32x9.T;
         Desired : in Packed_F32x3.T;
         Availability : in Wheel_Availability_X4.T;
         Commanded_Torque : in Packed_F32x3.T
      ) is
      begin
         Apply_Configuration (Self, Hs_Min => Hs_Min, Ki => No_Integral, Limit => No_Integral_Limit,
            Projection => Projection, Desired => Desired, Availability => Availability);
         Send_Tick (Self);
         Tick_Number := @ + 1;
         Assert_Latest_Output (Self, Tick_Number, Commanded_Torque);
      end Check;
   begin
      -- The whole cluster momentum is dumped:
      Check (Nominal_Hs_Min, Identity, Zero_Momentum, All_Available, Nominal_Torque);
      -- The threshold is above the cluster momentum, so no dump is requested:
      Check (High_Hs_Min, Identity, Zero_Momentum, All_Available, Zero_Torque);
      -- The whole cluster momentum lies along the direction the effectors cannot dump
      -- about, so nothing is left to dump even with the threshold at zero:
      Check (No_Hs_Min, Plane_Of_Cluster_Momentum, Zero_Momentum, All_Available, Zero_Torque);
      -- A part of the cluster momentum is undumpable and the rest is dumped:
      Check (Nominal_Hs_Min, Plane_Off_Axis, Zero_Momentum, All_Available, [-0.3386751346, -0.2924070463, -0.0825205255]);
      -- The cluster momentum is driven toward a non-zero desired momentum:
      Check (Nominal_Hs_Min, Identity, Desired_Momentum, All_Available, [-0.2386751346, -0.2136751346, -0.2886751346]);
      -- A desired momentum and an undumpable direction together:
      Check (Nominal_Hs_Min, Plane_Off_Axis, Desired_Momentum, All_Available, [-0.2386751346, -0.2733703997, -0.0771481718]);
      -- A desired momentum smaller than the threshold is still reached in full:
      Check (Nominal_Hs_Min, Identity, [1.0, 0.0, 0.0], All_Available, [-0.2886751346, -0.1636751346, -0.5386751346]);
      -- The cluster momentum is above the threshold but its difference to the desired
      -- momentum is not, so no dump is requested:
      Check ((Value => 5.0), Identity, [6.0, 3.0, 10.0], All_Available, Zero_Torque);
      -- Only the available wheels contribute to the cluster momentum:
      Check (Nominal_Hs_Min, Identity, Zero_Momentum, Wheels_1_And_3, [-0.05, 0.0, -0.25]);
      -- With no wheel available there is no momentum to dump:
      Check (Nominal_Hs_Min, Identity, Zero_Momentum, None_Available, Zero_Torque);
   end Test_Dumping_Variants;

   -- A parameter update is applied by the next tick and the integral state carries
   -- across it. Two ticks accumulate the integral, the proportional gain is doubled,
   -- and the third tick uses the new gain on the integral it inherited. A tight
   -- integral limit then clamps every component of the integral on the fourth tick.
   overriding procedure Test_Parameter_Update (Self : in out Instance) is
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Momentum_Management_Parameters.Instance;
   begin
      Apply_Configuration (Self, Hs_Min => Nominal_Hs_Min, Ki => Gain_Ki, Limit => Integral_Limit,
         Projection => Identity, Desired => Zero_Momentum, Availability => All_Available);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 1, [-0.3556088913, -0.1718588913, -0.5656088913]);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 2, [-0.3894764048, -0.1882264048, -0.6194764048]);

      -- Double the proportional gain:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K ((Value => 0.1))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 3, [-0.7620190528, -0.3682690528, -1.2120190528]);

      -- Tighten the integral limit to 5 Nms^2, well below the integral so far, so every
      -- component is clamped to it:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Tight_Integral_Limit)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
      Send_Tick (Self);
      Assert_Latest_Output (Self, 4, [-0.7273502692, -0.3773502692, -1.1273502692]);
   end Test_Parameter_Update;

   -- The algorithm requires a non-negative threshold and gains, an integral limit
   -- that is positive when the integral gain is, a genuine orthogonal projector, a
   -- finite desired momentum, and a unit spin axis in every wheel slot. Validation is
   -- the only guard keeping a rejected value out of the throwing Set_Config, so
   -- exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Momentum_Management_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Hs_Min (Nominal_Hs_Min)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K (Gain_K)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki (Gain_Ki)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (Integral_Limit)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Dumpable_Projection (Identity)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Hs_Desired (Desired_Momentum)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Inertias (Wheel_Inertias)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (All_Available)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A negative threshold is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Hs_Min ((Value => -1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative proportional gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K ((Value => -0.05))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative integral gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Gain_Ki ((Value => -0.01))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero integral limit is rejected while the integral gain is on:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Integral_Limit (No_Integral_Limit)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A scaled identity is not idempotent, so it is rejected as a projector:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Dumpable_Projection ([2.0, 0.0, 0.0,
                                                         0.0, 2.0, 0.0,
                                                         0.0, 0.0, 2.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero projector leaves no direction dumpable, so it is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Dumpable_Projection ([others => 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A wheel spin axis that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Rw_Spin_Axes ([[2.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [0.0, 0.0, 1.0]])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite desired momentum is rejected. The value is injected as raw bytes
      -- because the compiler will not let a non-finite Short_Float be written as a
      -- literal, and because that is how one would arrive: as bytes from the ground.
      -- Staging accepts it, and converting it for the algorithm raises, which
      -- validation reports as a rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Hs_Desired (Desired_Momentum);
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
      T : Component.Momentum_Management.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Commanded_Torque_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Momentum_Management_Tests.Implementation;
