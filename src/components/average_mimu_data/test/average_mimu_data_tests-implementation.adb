--------------------------------------------------------------------------------
-- Average_Mimu_Data Tests Body
--------------------------------------------------------------------------------

with Ada.Numerics;
with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Mimu_Raw_Packet;
with Averaged_Imu_Data;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Average_Mimu_Data_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Average_Mimu_Data_Tests.Implementation is

   -- Short name for the tester access type:
   subtype Tester_Ref is Component.Average_Mimu_Data.Implementation.Tester.Instance_Access;

   -- ICD conversion factors (must match the component spec constants):
   --   gyro[rad/s] = dn * 4000/2^31-1 * pi/180
   --   acc[m/s^2]  = dn * 160/2^31-1
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

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- A uniform raw packet (all 10 samples identical) at the given timestamp.
   -- ICD scale: gyro dn 1M/2M/3M -> GyroA/GyroB/GyroC, accel dn 4M/5M/6M -> AccelA/AccelB/AccelC.
   function Uniform_Packet (Seconds : Interfaces.Unsigned_32; Subseconds : Interfaces.Unsigned_16) return Mimu_Raw_Packet.T is
      ((
         Timestamp => (Seconds => Seconds, Subseconds => Subseconds),
         Samples => [others => (
            Merged_Gyro_Rates => (X_Measurement => 1_000_000, Y_Measurement => 2_000_000, Z_Measurement => 3_000_000),
            Merged_Accelerations => (X_Measurement => 4_000_000, Y_Measurement => 5_000_000, Z_Measurement => 6_000_000),
            Merge_Info => 0
         )]
      ));

   -- Non-uniform packet with negative values: first 5 samples negative, last 5
   -- positive, designed so the 10-sample average is exactly [GyroA,GyroB,GyroC]/[AccelA,AccelB,AccelC].
   Mixed_Packet : constant Mimu_Raw_Packet.T := (
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

   -- Time-filtered packet: bogus values in samples 0-4, known values in 5-9.
   -- Per-sample times are first-sample-time + I*10ms; maxTimeTag = base + 90ms.
   -- With a 45 ms window, sample I is kept when (9-I)*10ms <= 45ms, i.e. I in 5..9.
   -- Average of samples 5-9: gyro=[GyroA,GyroB,GyroC], accel=[AccelA,AccelB,AccelC].
   Filtered_Packet : constant Mimu_Raw_Packet.T := (
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

   -- Stage identity DCM plus the given gyro/accel windows and apply them.
   procedure Apply_Standard_Params (
      T : Tester_Ref;
      Gyro_Window : Short_Float;
      Accel_Window : Short_Float)
   is
      Params : Average_Mimu_Data_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Gyro_Time_Delta ((Value => Gyro_Window))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Accel_Time_Delta ((Value => Accel_Window))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Dcm_Pltf_To_Bdy ([
            1.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 1.0
         ])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Standard_Params;

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

   -- Identity DCM, uniform data - output equals scaled input.
   overriding procedure Test_Identity_Dcm (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 1.0, Accel_Window => 1.0);

      T.Mimu_Raw_Packet_T_Send (Uniform_Packet (1, 0));

      -- No output yet - the algorithm runs on tick, not on recv:
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
   end Test_Identity_Dcm;

   -- 90-degree Z-rotation DCM = [0, -1, 0; 1, 0, 0; 0, 0, 1]
   --   DCM * [GyroA,GyroB,GyroC] = [-GyroB, GyroA, GyroC]
   --   DCM * [AccelA,AccelB,AccelC] = [-AccelB, AccelA, AccelC]
   overriding procedure Test_Dcm_Rotation (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
      Params : Average_Mimu_Data_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Gyro_Time_Delta ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Accel_Time_Delta ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Dcm_Pltf_To_Bdy ([
            0.0, -1.0, 0.0,
            1.0,  0.0, 0.0,
            0.0,  0.0, 1.0
         ])), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Mimu_Raw_Packet_T_Send (Uniform_Packet (1, 0));
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [-GyroB, GyroA, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [-AccelB, AccelA, AccelC], Epsilon => 0.0001);
      end;
   end Test_Dcm_Rotation;

   -- Non-uniform data with negative values, identity DCM. Tests signed
   -- Integer_32-to-float conversion and averaging across mixed signs.
   overriding procedure Test_Mixed_Signs (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 1.0, Accel_Window => 1.0);

      T.Mimu_Raw_Packet_T_Send (Mixed_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Mixed_Signs;

   -- Per-sample time windowing: a 45 ms window over a single 10-sample packet
   -- keeps only samples 5-9 (older samples 0-4 are excluded).
   overriding procedure Test_Time_Filtering (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 0.045, Accel_Window => 0.045);

      T.Mimu_Raw_Packet_T_Send (Filtered_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Time_Filtering;

end Average_Mimu_Data_Tests.Implementation;
