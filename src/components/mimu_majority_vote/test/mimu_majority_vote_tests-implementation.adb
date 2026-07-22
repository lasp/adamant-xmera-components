--------------------------------------------------------------------------------
-- Mimu_Majority_Vote Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Interfaces; use Interfaces;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Mimu_Majority_Vote_Output;
with Mimu_Majority_Vote_Parameters;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

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

   -- Run algorithm to ensure integration is sound.
   -- Two test cases matching the Python unit test:
   --   1. Nominal: 3 IMUs within threshold -> simple average, no fault
   --   2. Off-nominal: 1 outlier rejected -> fault-excluded average, fault detected
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mimu_Majority_Vote_Parameters.Instance;
   begin
      -----------------------------------------------------------------------
      -- Test Case 1: Nominal - all IMUs within threshold
      --   threshold = 1.0 rad/s
      --   IMU diffs ~0.173 rad/s (well below threshold)
      --   Expected: simple average, no fault
      -----------------------------------------------------------------------

      -- Set omega threshold parameter
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Threshold ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set IMU data dependencies (symmetric perturbations -> exact average)
      T.Imu_1_Body := (Accel_Body => [others => 0.0], Ang_Vel_Body => [1.0, 2.0, 3.0]);
      T.Imu_2_Body := (Accel_Body => [others => 0.0], Ang_Vel_Body => [1.1, 2.1, 3.1]);
      T.Imu_3_Body := (Accel_Body => [others => 0.0], Ang_Vel_Body => [0.9, 1.9, 2.9]);

      -- Send tick to trigger algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data product was produced:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Majority_Vote_Result_History.Get_Count, 1);

      -- Check output: simple average, no fault
      declare
         Output : constant Mimu_Majority_Vote_Output.T := T.Majority_Vote_Result_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Avg_Ang_Vel_Body, [1.0, 2.0, 3.0], Epsilon => 0.0001);
         Unsigned_8_Assert.Eq (Output.Fault_Detected, 0);
         Integer_32_Assert.Eq (Output.Mimu_Index_Faulted, -1);
      end;

      -----------------------------------------------------------------------
      -- Test Case 2: Off-nominal - IMU 2 is an outlier
      --   threshold = 0.5 rad/s
      --   IMU 2 diff ~1.1 rad/s (exceeds threshold, largest)
      --   Expected: fault-excluded average of IMU 1 & 3, fault at index 1
      -----------------------------------------------------------------------

      -- Update omega threshold parameter
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Threshold ((Value => 0.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set IMU data dependencies (IMU 2 is outlier)
      T.Imu_1_Body := (Accel_Body => [others => 0.0], Ang_Vel_Body => [1.0, 2.0, 3.0]);
      T.Imu_2_Body := (Accel_Body => [others => 0.0], Ang_Vel_Body => [2.0, 3.0, 4.0]);
      T.Imu_3_Body := (Accel_Body => [others => 0.0], Ang_Vel_Body => [1.1, 2.1, 3.1]);

      -- Send tick to trigger algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify second data product was produced:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Majority_Vote_Result_History.Get_Count, 2);

      -- Check output: fault-excluded average of IMU 1 and IMU 3
      -- corrected = (IMU1 + IMU3) / 2 = [1.05, 2.05, 3.05]
      declare
         Output : constant Mimu_Majority_Vote_Output.T := T.Majority_Vote_Result_History.Get (2);
      begin
         Packed_F32x3_Assert.Eq (Output.Avg_Ang_Vel_Body, [1.05, 2.05, 3.05], Epsilon => 0.0001);
         Unsigned_8_Assert.Eq (Output.Fault_Detected, 1);
         Integer_32_Assert.Eq (Output.Mimu_Index_Faulted, 1);
      end;

   end Test;

   -- Test that an invalid parameter is rejected with an error status (the
   -- Invalid_Parameter handler is null; the Parameters component reports the
   -- failure to the ground).
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Param : Parameter.T := T.Parameters.Omega_Threshold ((Value => 1.0));
   begin
      -- Make the parameter invalid by modifying its length.
      Param.Header.Buffer_Length := 0;

      -- Send bad parameter and expect bad response:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Length_Error);

      -- Test with invalid id:
      Param.Header.Id := 1_001;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Id_Error);
   end Test_Invalid_Parameter;

end Mimu_Majority_Vote_Tests.Implementation;
