--------------------------------------------------------------------------------
-- Mimu_Majority_Vote Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_Bool_X3.Assertion; use Packed_Bool_X3.Assertion;
with Mimu_Majority_Vote_Output;
with Mimu_Majority_Vote_Parameters;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Invalid_Parameter_Info.Assertion; use Invalid_Parameter_Info.Assertion;

package body Mimu_Majority_Vote_Tests.Implementation is

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

   -- Run the algorithm to ensure the Ada -> C -> C++ integration is sound.
   -- The algorithm votes independently on angular velocity (gyro) and
   -- acceleration (accel), each producing an averaged measurement, a fault
   -- flag, and per-IMU validity. Two cases (values ground-truthed against the
   -- fp32 mimuMajorityVote C++ unit tests):
   --   1. Nominal: gyro and accel both agree within threshold -> full averages,
   --      no fault on either vote.
   --   2. Independent faults: IMU 2 is a gyro outlier and IMU 3 is an accel
   --      outlier -> each vote excludes only its own outlier.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mimu_Majority_Vote_Parameters.Instance;
   begin
      -----------------------------------------------------------------------
      -- Test Case 1: Nominal - all IMUs within threshold (gyro and accel).
      --   thresholds = 1.0; symmetric perturbations -> exact averages, no fault.
      -----------------------------------------------------------------------

      -- Set thresholds high so nothing faults:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Threshold ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Accel_Threshold ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set IMU data dependencies (symmetric perturbations -> exact averages):
      T.Imu_1_Body := (Ang_Vel_Body => [1.0, 2.0, 3.0], Accel_Body => [0.0, 0.0, 9.8]);
      T.Imu_2_Body := (Ang_Vel_Body => [1.1, 2.1, 3.1], Accel_Body => [0.1, 0.1, 9.9]);
      T.Imu_3_Body := (Ang_Vel_Body => [0.9, 1.9, 2.9], Accel_Body => [-0.1, -0.1, 9.7]);

      -- Send tick to trigger algorithm:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data product was produced:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Majority_Vote_Result_History.Get_Count, 1);

      -- Check output: full averages, no fault on either vote:
      declare
         Output : constant Mimu_Majority_Vote_Output.T := T.Majority_Vote_Result_History.Get (1);
      begin
         -- Gyro vote:
         Packed_F32x3_Assert.Eq (Output.Gyro.Average, [1.0, 2.0, 3.0], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Gyro.Fault_Detected, False);
         Packed_Bool_X3_Assert.Eq (Output.Gyro.Imu_Valid, [True, True, True]);
         -- Accel vote:
         Packed_F32x3_Assert.Eq (Output.Accel.Average, [0.0, 0.0, 9.8], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Accel.Fault_Detected, False);
         Packed_Bool_X3_Assert.Eq (Output.Accel.Imu_Valid, [True, True, True]);
      end;

      -----------------------------------------------------------------------
      -- Test Case 2: Independent faults on different IMUs.
      --   thresholds = 0.05; persistence limits = 1 (default) -> fault on the
      --   first tick. IMU 2 is a gyro outlier; IMU 3 is an accel outlier.
      -----------------------------------------------------------------------

      -- Tighten thresholds so the outliers fault:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Threshold ((Value => 0.05))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Accel_Threshold ((Value => 0.05))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- IMU 2 (index 1) angular velocity is base + 2.0; IMU 3 (index 2)
      -- acceleration is base + 2.0. All other quantities agree on base.
      T.Imu_1_Body := (Ang_Vel_Body => [-0.1, 0.25, 0.3], Accel_Body => [0.0, 0.0, 9.8]);
      T.Imu_2_Body := (Ang_Vel_Body => [1.9, 2.25, 2.3], Accel_Body => [0.0, 0.0, 9.8]);
      T.Imu_3_Body := (Ang_Vel_Body => [-0.1, 0.25, 0.3], Accel_Body => [2.0, 2.0, 11.8]);

      -- Send tick to trigger algorithm:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify second data product was produced:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Majority_Vote_Result_History.Get_Count, 2);

      -- Check output: each vote excludes only its own outlier:
      declare
         Output : constant Mimu_Majority_Vote_Output.T := T.Majority_Vote_Result_History.Get (2);
      begin
         -- Gyro vote: IMU 2 (index 1) excluded; average of IMU 1 and IMU 3 = base:
         Packed_F32x3_Assert.Eq (Output.Gyro.Average, [-0.1, 0.25, 0.3], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Gyro.Fault_Detected, True);
         Packed_Bool_X3_Assert.Eq (Output.Gyro.Imu_Valid, [True, False, True]);
         -- Accel vote: IMU 3 (index 2) excluded; average of IMU 1 and IMU 2 = base:
         Packed_F32x3_Assert.Eq (Output.Accel.Average, [0.0, 0.0, 9.8], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Accel.Fault_Detected, True);
         Packed_Bool_X3_Assert.Eq (Output.Accel.Imu_Valid, [True, True, False]);
      end;

   end Test;

   -- Test that an invalid parameter throws the appropriate event.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Param : Parameter.T := T.Parameters.Omega_Threshold ((Value => 1.0));
   begin
      -- Make the parameter invalid by modifying its length.
      Param.Header.Buffer_Length := 0;

      -- Send bad parameter and expect bad response:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Length_Error);

      -- Make sure the invalid parameter event was thrown:
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Invalid_Parameter_Received_History.Get_Count, 1);
      Invalid_Parameter_Info_Assert.Eq (T.Invalid_Parameter_Received_History.Get (1), (
         Id => T.Parameters.Get_Omega_Threshold_Id,
         Errant_Field_Number => Interfaces.Unsigned_32'Last,
         Errant_Field => [0, 0, 0, 0, 0, 0, 0, 0]
      ));

      -- Test with invalid id:
      Param.Header.Id := 1_001;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Id_Error);

      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Invalid_Parameter_Received_History.Get_Count, 2);
   end Test_Invalid_Parameter;

end Mimu_Majority_Vote_Tests.Implementation;
