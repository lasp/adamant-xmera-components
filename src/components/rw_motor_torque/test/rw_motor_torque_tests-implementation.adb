--------------------------------------------------------------------------------
-- Rw_Motor_Torque Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Mrp_Feedback_Enums; use Mrp_Feedback_Enums;
with Packed_F32;
with Packed_F32x3_X4;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Rw_Motor_Torque_Parameters;
with Rwa_Torques.Assertion; use Rwa_Torques.Assertion;
with Wheel_Availability_X4;

package body Rw_Motor_Torque_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Wheel geometry, requested torque, and wheel speeds from the Python reference test
   -- (_tests/test_rwMotorTorque.py).
   Spin_Axes : constant Packed_F32x3_X4.T := [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0],
      [0.577350269190, 0.577350269190, 0.577350269190]
   ];
   All_Available : constant Wheel_Availability_X4.T := [others => Wheel_Availability.Available];
   None_Available : constant Wheel_Availability_X4.T := [others => Wheel_Availability.Unavailable];
   Wheel_3_Out : constant Wheel_Availability_X4.T := [
      Wheel_Availability.Available, Wheel_Availability.Available,
      Wheel_Availability.Unavailable, Wheel_Availability.Available
   ];
   No_Gain : constant Packed_F32.T := (Value => 0.0);
   Gain : constant Packed_F32.T := (Value => 0.5);

   -- The reference torques are computed in double precision; the single precision
   -- mapping agrees to a few parts in a million.
   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage the control axis selection. The record is built at the call rather than held
   -- in a named constant, which keeps the staged value intact on every target.
   procedure Stage_Control_Axes (Self : in out Instance; X, Y, Z : in Boolean) is
      T : Component.Rw_Motor_Torque.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Rw_Motor_Torque_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Control_Axes ((Torque_X => X, Torque_Y => Y, Torque_Z => Z))), Success);
   end Stage_Control_Axes;

   -- Stage and apply a configuration. The wheel geometry is the same in every case.
   procedure Apply_Configuration (
      Self : in out Instance;
      X, Y, Z : in Boolean;
      Availability : in Wheel_Availability_X4.T;
      Omega_Gain : in Packed_F32.T
   ) is
      T : Component.Rw_Motor_Torque.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Rw_Motor_Torque_Parameters.Instance;
   begin
      Stage_Control_Axes (Self, X, Y, Z);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (Availability)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Gain (Omega_Gain)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the reference torque and wheel speeds and check the torques sent
   -- to the wheel interface.
   procedure Send_Tick_And_Check (Self : in out Instance; Tick_Number : in Natural; Expected : in Rwa_Torques.T) is
      T : Component.Rw_Motor_Torque.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Control_Torque := (Torque_Request_Body => [1.0, -0.5, 0.7]);
      T.Wheel_Speeds := (Rwa_1 => 10.0, Rwa_2 => 20.0, Rwa_3 => 30.0, Rwa_4 => 40.0);
      T.Desired_Wheel_Speeds := (Rwa_1 => 0.0, Rwa_2 => 0.0, Rwa_3 => 0.0, Rwa_4 => 0.0);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Rwa_Torques_T_Recv_Sync_History.Get_Count, Tick_Number);
      Rwa_Torques_Assert.Eq (T.Rwa_Torques_T_Recv_Sync_History.Get (Tick_Number), Expected, Epsilon => Epsilon);
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

   -- Run the algorithm on the control axis, availability, and null space gain cases of
   -- the Python reference test to ensure the Ada to C to C++ integration is sound. The
   -- expected torques are computed independently from the minimum norm mapping and
   -- null space projection of the reference model.
   overriding procedure Test (Self : in out Instance) is
   begin
      -- All three axes on four wheels with the null space term off:
      Apply_Configuration (Self, X => True, Y => True, Z => True, Availability => All_Available, Omega_Gain => No_Gain);
      Send_Tick_And_Check (Self, 1, (Rwa_1 => -0.8, Rwa_2 => 0.7, Rwa_3 => -0.5, Rwa_4 => -0.3464101615));

      -- With four available wheels the null space term steers the wheel speeds without
      -- changing the body torque:
      Apply_Configuration (Self, X => True, Y => True, Z => True, Availability => All_Available, Omega_Gain => Gain);
      Send_Tick_And_Check (Self, 2, (Rwa_1 => -0.0264973081, Rwa_2 => 1.4735026919, Rwa_3 => 0.2735026919, Rwa_4 => -1.6861561237));

      -- Two axes on three available wheels; the unavailable wheel is commanded zero:
      Apply_Configuration (Self, X => True, Y => True, Z => False, Availability => Wheel_3_Out, Omega_Gain => No_Gain);
      Send_Tick_And_Check (Self, 3, (Rwa_1 => -0.9, Rwa_2 => 0.6, Rwa_3 => 0.0, Rwa_4 => -0.1732050808));

      -- A single axis with the null space term on:
      Apply_Configuration (Self, X => True, Y => False, Z => False, Availability => All_Available, Omega_Gain => Gain);
      Send_Tick_And_Check (Self, 4, (Rwa_1 => 0.0235026919, Rwa_2 => 0.7735026919, Rwa_3 => 0.7735026919, Rwa_4 => -1.7727586640));

      -- With only three available wheels there is no null space, so the gain has no effect:
      Apply_Configuration (Self, X => True, Y => True, Z => True, Availability => Wheel_3_Out, Omega_Gain => Gain);
      Send_Tick_And_Check (Self, 5, (Rwa_1 => -0.3, Rwa_2 => 1.2, Rwa_3 => 0.0, Rwa_4 => -1.2124355653));
   end Test;

   -- The algorithm requires at least one control axis, unit spin axes, a non-negative
   -- gain, and a mapping in which every selected axis is reachable by the available
   -- wheels. Validation is the only guard keeping a rejected value out of the throwing
   -- Set_Config, so exercise it directly. A control axis byte other than zero or one is
   -- an invalid Boolean, which staging rejects before validation runs.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Rw_Motor_Torque.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Rw_Motor_Torque_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Stage_Control_Axes (Self, X => True, Y => True, Z => True);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rw_Spin_Axes (Spin_Axes)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (All_Available)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Gain (No_Gain)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- No control axis is rejected:
      Stage_Valid_Configuration;
      Stage_Control_Axes (Self, X => False, Y => False, Z => False);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- No available wheel leaves the control axes unreachable, so it is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Wheel_Availability (None_Available)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A wheel spin axis that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Rw_Spin_Axes ([[2.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [0.0, 0.0, 1.0]])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Gain ((Value => -0.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite spin axis is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Rw_Spin_Axes (Spin_Axes);
      begin
         -- Overwrite the first big-endian float with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A control axis byte that is neither zero nor one is rejected at staging by type
      -- validation:
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Control_Axes ((Torque_X => True, Torque_Y => True, Torque_Z => True));
      begin
         Par.Buffer (Par.Buffer'First) := 2;
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Validation_Error);
      end;

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than sending anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Rw_Motor_Torque.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Rwa_Torques_T_Recv_Sync_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Rw_Motor_Torque_Tests.Implementation;
