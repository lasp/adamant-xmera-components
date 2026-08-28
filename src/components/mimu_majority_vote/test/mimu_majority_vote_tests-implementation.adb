--------------------------------------------------------------------------------
-- Mimu_Majority_Vote Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_Bool_X3.Assertion; use Packed_Bool_X3.Assertion;
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

   -- Run the algorithm to ensure the Ada -> C -> C++ integration is sound.
   -- The algorithm votes independently on angular velocity (gyro) and
   -- acceleration (accel), each producing an averaged measurement, a fault
   -- flag, and per-IMU validity. Two cases (values ground-truthed against the
   -- fp32 mimuMajorityVote C++ unit tests):
   --   1. Nominal: gyro and accel both agree within threshold -> full averages,
   --      no fault on either vote.
   --   2. Independent thresholds: IMU 2 is a gyro outlier and IMU 3 is an accel
   --      outlier, but only the gyro threshold rejects its own.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mimu_Majority_Vote_Parameters.Instance;
   begin
      -----------------------------------------------------------------------
      -- Test Case 1: Nominal - all IMUs within threshold (gyro and accel).
      --   thresholds = 1.0; symmetric perturbations -> exact averages, no fault.
      -----------------------------------------------------------------------

      -- Set thresholds high so nothing faults. The gyro and accel values are deliberately
      -- different from each other, here and below, so that a transposed argument pair in
      -- Create/Set_Config changes the result rather than passing unnoticed.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Threshold ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Accel_Threshold ((Value => 3.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Gyro_Fault_Persistence_Limit ((Value => 1))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Accel_Fault_Persistence_Limit ((Value => 2))), Success);
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
         Packed_F32x3_Assert.Eq
            (Output.Gyro.Imu_Difference_Mag, [0.0, 0.173_205, 0.173_205], Epsilon => 0.0001);
         -- Accel vote:
         Packed_F32x3_Assert.Eq (Output.Accel.Average, [0.0, 0.0, 9.8], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Accel.Fault_Detected, False);
         Packed_Bool_X3_Assert.Eq (Output.Accel.Imu_Valid, [True, True, True]);
         Packed_F32x3_Assert.Eq
            (Output.Accel.Imu_Difference_Mag, [0.0, 0.173_205, 0.173_205], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 2: Independent votes, gyro faults and accel does not.
      --   IMU 2 is a gyro outlier and IMU 3 is an accel outlier, but only the
      --   gyro threshold is tight enough to reject its outlier. This separates
      --   the two votes: each one answers to its own threshold alone.
      -----------------------------------------------------------------------

      -- Tighten the gyro threshold so its outlier faults, and hold the accel threshold
      -- above its own outlier's 2.31 difference so the accel vote does not. Swapping the
      -- two thresholds inverts both outcomes below.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Threshold ((Value => 0.05))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Accel_Threshold ((Value => 5.0))), Success);
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

      -- Check output: the gyro vote rejects its outlier, the accel vote keeps all three:
      declare
         Output : constant Mimu_Majority_Vote_Output.T := T.Majority_Vote_Result_History.Get (2);
      begin
         -- Gyro vote: IMU 2 (index 1) excluded; average of IMU 1 and IMU 3 = base:
         Packed_F32x3_Assert.Eq (Output.Gyro.Average, [-0.1, 0.25, 0.3], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Gyro.Fault_Detected, True);
         Packed_Bool_X3_Assert.Eq (Output.Gyro.Imu_Valid, [True, False, True]);
         -- Difference magnitudes stay relative to the all-three average:
         Packed_F32x3_Assert.Eq
            (Output.Gyro.Imu_Difference_Mag, [1.154_701, 2.309_401, 1.154_701], Epsilon => 0.0001);
         -- Accel vote: 2.31 is under the 5.0 threshold, so all three IMUs remain valid
         -- and the average is over all three:
         Packed_F32x3_Assert.Eq (Output.Accel.Average, [0.666_667, 0.666_667, 10.466_667], Epsilon => 0.0001);
         Boolean_Assert.Eq (Output.Accel.Fault_Detected, False);
         Packed_Bool_X3_Assert.Eq (Output.Accel.Imu_Valid, [True, True, True]);
         Packed_F32x3_Assert.Eq
            (Output.Accel.Imu_Difference_Mag, [1.154_701, 1.154_701, 2.309_401], Epsilon => 0.0001);
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

   -- Stage a candidate configuration one field at a time and confirm the component's
   -- Validate_Parameters gate rejects every value the C++ MimuMajorityVoteConfig would
   -- throw on. This gate is the only thing keeping ground input out of the throwing
   -- Set_Config, whose exception could not be caught on the Ada side.
   overriding procedure Test_Validate_Parameters (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mimu_Majority_Vote_Parameters.Instance;

      -- Stage the full valid set. Every case below starts from this baseline so a
      -- rejection can only come from the single field that was perturbed.
      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Omega_Threshold ((Value => 0.05))), Success);
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Gyro_Fault_Persistence_Limit ((Value => 3))), Success);
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Accel_Threshold ((Value => 0.5))), Success);
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Accel_Fault_Persistence_Limit ((Value => 1))), Success);
      end Stage_Valid_Set;
   begin
      -- The baseline set is accepted:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A zero gyro threshold is rejected (must be finite and > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
         (T.Stage_Parameter (Params.Omega_Threshold ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative gyro threshold is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
         (T.Stage_Parameter (Params.Omega_Threshold ((Value => -1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero gyro fault persistence limit is rejected (must be > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
         (T.Stage_Parameter (Params.Gyro_Fault_Persistence_Limit ((Value => 0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero accel threshold is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
         (T.Stage_Parameter (Params.Accel_Threshold ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative accel threshold is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
         (T.Stage_Parameter (Params.Accel_Threshold ((Value => -1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero accel fault persistence limit is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
         (T.Stage_Parameter (Params.Accel_Fault_Persistence_Limit ((Value => 0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above
      -- were caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Validate_Parameters;

   -- Drive a steady outlier on each quantity and confirm the gyro and accel votes
   -- confirm their faults at their own persistence limits, then that a parameter
   -- update clears both counters. The two limits differ, so a transposed pair in
   -- Create/Set_Config inverts which vote faults first.
   overriding procedure Test_Fault_Persistence (Self : in out Instance) is
      T : Component.Mimu_Majority_Vote.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mimu_Majority_Vote_Parameters.Instance;

      -- The gyro vote needs three consecutive outlier ticks to confirm a fault; the
      -- accel vote needs one. Re-staging this set is also what clears the counters.
      procedure Stage_Config is
      begin
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Omega_Threshold ((Value => 0.05))), Success);
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Accel_Threshold ((Value => 0.05))), Success);
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Gyro_Fault_Persistence_Limit ((Value => 3))), Success);
         Parameter_Update_Status_Assert.Eq
            (T.Stage_Parameter (Params.Accel_Fault_Persistence_Limit ((Value => 1))), Success);
         Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
      end Stage_Config;

      -- IMU 2 is a steady gyro outlier; IMU 3 is a steady accel outlier.
      procedure Send_Outlier_Tick is
      begin
         T.Imu_1_Body := (Ang_Vel_Body => [-0.1, 0.25, 0.3], Accel_Body => [0.0, 0.0, 9.8]);
         T.Imu_2_Body := (Ang_Vel_Body => [1.9, 2.25, 2.3], Accel_Body => [0.0, 0.0, 9.8]);
         T.Imu_3_Body := (Ang_Vel_Body => [-0.1, 0.25, 0.3], Accel_Body => [2.0, 2.0, 11.8]);
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      end Send_Outlier_Tick;

      -- The most recent published vote result.
      function Latest return Mimu_Majority_Vote_Output.T is
         (T.Majority_Vote_Result_History.Get (T.Majority_Vote_Result_History.Get_Count));
   begin
      Stage_Config;

      -- Tick 1: the accel fault confirms immediately, the gyro fault does not.
      Send_Outlier_Tick;
      Boolean_Assert.Eq (Latest.Gyro.Fault_Detected, False);
      Packed_Bool_X3_Assert.Eq (Latest.Gyro.Imu_Valid, [True, True, True]);
      Boolean_Assert.Eq (Latest.Accel.Fault_Detected, True);
      Packed_Bool_X3_Assert.Eq (Latest.Accel.Imu_Valid, [True, True, False]);

      -- Tick 2: the gyro counter is at two of three, still under the limit.
      Send_Outlier_Tick;
      Boolean_Assert.Eq (Latest.Gyro.Fault_Detected, False);
      Packed_Bool_X3_Assert.Eq (Latest.Gyro.Imu_Valid, [True, True, True]);

      -- Tick 3: the gyro counter reaches the limit and IMU 2 is rejected.
      Send_Outlier_Tick;
      Boolean_Assert.Eq (Latest.Gyro.Fault_Detected, True);
      Packed_Bool_X3_Assert.Eq (Latest.Gyro.Imu_Valid, [True, False, True]);
      Packed_F32x3_Assert.Eq (Latest.Gyro.Average, [-0.1, 0.25, 0.3], Epsilon => 0.0001);

      -- A parameter update re-applies the configuration and clears both persistence
      -- counters, so the very next outlier tick starts counting from one again.
      Stage_Config;
      Send_Outlier_Tick;
      Boolean_Assert.Eq (Latest.Gyro.Fault_Detected, False);
      Packed_Bool_X3_Assert.Eq (Latest.Gyro.Imu_Valid, [True, True, True]);
   end Test_Fault_Persistence;

end Mimu_Majority_Vote_Tests.Implementation;
