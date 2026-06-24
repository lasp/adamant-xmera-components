--------------------------------------------------------------------------------
-- Average_Mimu_Data Tests Body
--------------------------------------------------------------------------------

with Ada.Numerics;
with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Mimu_Raw_Packet;
with Averaged_Imu_Data;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Parameter;
with Average_Mimu_Data_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Invalid_Parameter_Info.Assertion; use Invalid_Parameter_Info.Assertion;

package body Average_Mimu_Data_Tests.Implementation is

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
   overriding procedure Test (Self : in out Instance) is
      T : Component.Average_Mimu_Data.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Average_Mimu_Data_Parameters.Instance;

      -- ICD conversion factors (must match spec constants):
      -- gyro[rad/s] = dn * 4000/2^31-1 * pi/180
      -- acc[m/s^2]  = dn * 160/2^31-1
      Gyro_Scale : constant Short_Float :=
         (4_000.0 / 2_147_483_647.0) * (Ada.Numerics.Pi / 180.0);
      Accel_Scale : constant Short_Float := 160.0 / 2_147_483_647.0;

      -- Expected physical-unit values for raw dn = 1M .. 6M:
      GyroA : constant Short_Float := 1_000_000.0 * Gyro_Scale;
      GyroB : constant Short_Float := 2_000_000.0 * Gyro_Scale;
      GyroC : constant Short_Float := 3_000_000.0 * Gyro_Scale;
      AccelA : constant Short_Float := 4_000_000.0 * Accel_Scale;
      AccelB : constant Short_Float := 5_000_000.0 * Accel_Scale;
      AccelC : constant Short_Float := 6_000_000.0 * Accel_Scale;

      -- Uniform raw packet: all 10 samples have the same integer values.
      -- ICD scale: 1_000_000 -> GyroA, 2_000_000 -> GyroB, etc.
      -- Timestamp Seconds=1 so the 10 samples have measTime ~1s.
      -- The C shim zero-fills the remaining internal buffer slots (measTime=0)
      -- with age ~1.09s, which is excluded by timeDelta=1.0.
      Uniform_Raw_Packet : constant Mimu_Raw_Packet.T := (
         Timestamp => (Seconds => 1, Subseconds => 0),
         Samples => [others => (
            Merged_Gyro_Rates => (X_Measurement => 1_000_000, Y_Measurement => 2_000_000, Z_Measurement => 3_000_000),
            Merged_Accelerations => (X_Measurement => 4_000_000, Y_Measurement => 5_000_000, Z_Measurement => 6_000_000),
            Merge_Info => 0
         )]
      );

      -- Non-uniform raw packet with negative values: first 5 samples negative,
      -- last 5 positive. Tests signed Integer_32-to-float conversion and
      -- averaging across mixed signs.
      -- After ICD scale:
      --   first 5 gyro = [-GyroA, -GyroB, -GyroC], accel = [-AccelA, -AccelB, -AccelC]
      --   last 5 gyro = [3*GyroA, 3*GyroB, 3*GyroC], accel = [3*AccelA, 3*AccelB, 3*AccelC]
      -- Average of 10: gyro = [GyroA, GyroB, GyroC], accel = [AccelA, AccelB, AccelC]
      Mixed_Raw_Packet : constant Mimu_Raw_Packet.T := (
         Timestamp => (Seconds => 1, Subseconds => 0),
         Samples => [
            0 .. 4 => (
               Merged_Gyro_Rates => (X_Measurement => -1_000_000, Y_Measurement => -2_000_000, Z_Measurement => -3_000_000),
               Merged_Accelerations => (X_Measurement => -4_000_000, Y_Measurement => -5_000_000, Z_Measurement => -6_000_000),
               Merge_Info => 0
            ),
            5 .. 9 => (
               Merged_Gyro_Rates => (X_Measurement => 3_000_000, Y_Measurement => 6_000_000, Z_Measurement => 9_000_000),
               Merged_Accelerations => (X_Measurement => 12_000_000, Y_Measurement => 15_000_000, Z_Measurement => 18_000_000),
               Merge_Info => 0
            )
         ]
      );

      -- Time-filtered raw packet: bogus values in samples 0-4, known values in 5-9.
      -- With timeDelta=0.045 (45ms), per-sample timestamps are base + I*10ms:
      --   maxTimeTag = base + 90ms
      --   Sample I age = (9-I)*10ms; included when age*NANO2SEC < timeDelta.
      --   Sample 4: age=50ms, 0.05 < 0.045 => NO (excluded)
      --   Sample 5: age=40ms, 0.04 < 0.045 => YES (included)
      --   Only samples 5-9 pass the time filter.
      -- Average of samples 5-9: gyro=[GyroA,GyroB,GyroC], accel=[AccelA,AccelB,AccelC]
      Filtered_Raw_Packet : constant Mimu_Raw_Packet.T := (
         Timestamp => (Seconds => 1, Subseconds => 0),
         Samples => [
            0 .. 4 => (
               Merged_Gyro_Rates => (X_Measurement => 99_000_000, Y_Measurement => 99_000_000, Z_Measurement => 99_000_000),
               Merged_Accelerations => (X_Measurement => 99_000_000, Y_Measurement => 99_000_000, Z_Measurement => 99_000_000),
               Merge_Info => 0
            ),
            5 .. 9 => (
               Merged_Gyro_Rates => (X_Measurement => 1_000_000, Y_Measurement => 2_000_000, Z_Measurement => 3_000_000),
               Merged_Accelerations => (X_Measurement => 4_000_000, Y_Measurement => 5_000_000, Z_Measurement => 6_000_000),
               Merge_Info => 0
            )
         ]
      );
   begin
      -----------------------------------------------------------------------
      -- Set parameters: identity DCM, 1s time window
      -- timeDelta=1.0 includes all 10 filled samples (age 0-90ms < 1.0s)
      -- but excludes the 110 zero-filled slots (age ~1.09s >= 1.0s).
      -----------------------------------------------------------------------
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Time_Delta ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Dcm_Pltf_To_Bdy ([
            1.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 1.0
         ])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -----------------------------------------------------------------------
      -- Test Case 1: Identity DCM, uniform data - output equals scaled input
      -- Send 1 packet (10 samples), fire tick to process.
      -----------------------------------------------------------------------
      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);

      -- No output yet - algorithm runs on tick, not on recv:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 0);

      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 2: 90-degree Z rotation DCM
      -- DCM = [0, -1, 0; 1, 0, 0; 0, 0, 1]
      -- DCM * [GyroA,GyroB,GyroC] = [-GyroB, GyroA, GyroC]
      -- DCM * [AccelA,AccelB,AccelC] = [-AccelB, AccelA, AccelC]
      -----------------------------------------------------------------------
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Dcm_Pltf_To_Bdy ([
            0.0, -1.0, 0.0,
            1.0,  0.0, 0.0,
            0.0,  0.0, 1.0
         ])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 2);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (2);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [-GyroB, GyroA, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [-AccelB, AccelA, AccelC], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 3: Non-uniform data with negative values, identity DCM
      -- Tests signed I32-to-float conversion and averaging across mixed signs.
      -----------------------------------------------------------------------
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Dcm_Pltf_To_Bdy ([
            1.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 1.0
         ])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Mimu_Raw_Packet_T_Send (Mixed_Raw_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 3);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 3);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (3);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 4: Time filtering within 10-sample packet
      -- timeDelta=0.045 (45ms) excludes samples 0-4, includes 5-9.
      -----------------------------------------------------------------------
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Time_Delta ((Value => 0.045))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Mimu_Raw_Packet_T_Send (Filtered_Raw_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 4);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 4);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (4);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 5: Tick with no buffered data publishes a zero result.
      -- The wrapper always publishes Imu_Body_Data so downstream consumers
      -- see Success on every tick; with no Mimu_Raw_Packet buffered, the
      -- algorithm runs on all-zero input and produces a zeroed output.
      -----------------------------------------------------------------------
      T.Tick_T_Send (((0, 0), 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 5);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 5);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (5);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [0.0, 0.0, 0.0], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [0.0, 0.0, 0.0], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 6: Multi-packet buffering - two packets before one tick.
      -- Both packets have the same uniform data. The algorithm receives 20
      -- samples (all identical values) and averages to the same result.
      -----------------------------------------------------------------------
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Time_Delta ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Dcm_Pltf_To_Bdy ([
            1.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 1.0
         ])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 6);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 6);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (6);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;

      -----------------------------------------------------------------------
      -- Test Case 7: Buffer overflow event
      -- Send 5 packets (buffer holds 4), verify the 5th triggers the
      -- Packet_Buffer_Overflow event and is dropped.
      -----------------------------------------------------------------------
      Natural_Assert.Eq (T.Packet_Buffer_Overflow_History.Get_Count, 0);

      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);

      -- Buffer is now full (4/4), no overflow yet:
      Natural_Assert.Eq (T.Packet_Buffer_Overflow_History.Get_Count, 0);

      -- 5th packet should trigger overflow event:
      T.Mimu_Raw_Packet_T_Send (Uniform_Raw_Packet);
      Natural_Assert.Eq (T.Packet_Buffer_Overflow_History.Get_Count, 1);

      -- Tick still processes the 4 buffered packets:
      T.Tick_T_Send (((0, 0), 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 7);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 7);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (7);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test;

   -- Test that an invalid parameter throws the appropriate event.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Average_Mimu_Data.Implementation.Tester.Instance_Access renames Self.Tester;
      Param : Parameter.T := T.Parameters.Time_Delta ((Value => 1.0));
   begin
      -- Make the parameter invalid by modifying its length.
      Param.Header.Buffer_Length := 0;

      -- Send bad parameter and expect bad response:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Length_Error);

      -- Make sure the invalid parameter event was thrown:
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Invalid_Parameter_Received_History.Get_Count, 1);
      Invalid_Parameter_Info_Assert.Eq (T.Invalid_Parameter_Received_History.Get (1), (
         Id => T.Parameters.Get_Time_Delta_Id,
         Errant_Field_Number => Interfaces.Unsigned_32'Last,
         Errant_Field => [0, 0, 0, 0, 0, 0, 0, 0]
      ));

      -- Test with invalid id:
      Param.Header.Id := 1_001;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Id_Error);

      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Invalid_Parameter_Received_History.Get_Count, 2);
   end Test_Invalid_Parameter;

end Average_Mimu_Data_Tests.Implementation;
