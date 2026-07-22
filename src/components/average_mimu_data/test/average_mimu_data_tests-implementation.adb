--------------------------------------------------------------------------------
-- Average_Mimu_Data Tests Body
--------------------------------------------------------------------------------

with Ada.Numerics;
with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Mimu_Eng_Packet;
with Mimu_Sample;
with Averaged_Imu_Data;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Parameter;
with Average_Mimu_Data_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Average_Mimu_Data_Tests.Implementation is

   -- Short name for the tester access type:
   subtype Tester_Ref is Component.Average_Mimu_Data.Implementation.Tester.Instance_Access;

   -- ICD conversion factors used to derive engineering-unit test values
   -- from representative raw counts:
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

   -- Roughly 100 ms expressed in Sys_Time subseconds (1/65536 s). Used to space
   -- consecutive packets so each packet's first-sample time is strictly
   -- increasing, which the (stateful) algorithm requires to ingest them.
   Pkt_Subsec_Step : constant Interfaces.Unsigned_16 := 6_554;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Sys_Time seconds/subseconds expressed in nanoseconds.
   function To_Ns (Seconds : Interfaces.Unsigned_32; Subseconds : Interfaces.Unsigned_16) return Interfaces.Unsigned_64 is
      (Interfaces.Unsigned_64 (Seconds) * 1_000_000_000 +
       Interfaces.Unsigned_64 (Subseconds) * 1_000_000_000 / 65_536);

   -- Build one engineering-unit sample from representative raw counts
   function Eng_Sample (Gyro_Dn_X, Gyro_Dn_Y, Gyro_Dn_Z, Accel_Dn_X, Accel_Dn_Y, Accel_Dn_Z : Short_Float) return Mimu_Sample.T is
      ((Gyro_P => [Gyro_Dn_X * Gyro_Scale, Gyro_Dn_Y * Gyro_Scale, Gyro_Dn_Z * Gyro_Scale],
        Accel_P => [Accel_Dn_X * Accel_Scale, Accel_Dn_Y * Accel_Scale, Accel_Dn_Z * Accel_Scale]));

   -- A uniform packet (all 10 samples identical) at the given timestamp.
   -- ICD scale: gyro dn 1M/2M/3M -> GyroA/GyroB/GyroC, accel dn 4M/5M/6M -> AccelA/AccelB/AccelC.
   function Uniform_Packet (Seconds : Interfaces.Unsigned_32; Subseconds : Interfaces.Unsigned_16) return Mimu_Eng_Packet.T is
      ((
         Meas_Time => To_Ns (Seconds, Subseconds),
         Samples => [others => Eng_Sample (1_000_000.0, 2_000_000.0, 3_000_000.0, 4_000_000.0, 5_000_000.0, 6_000_000.0)]
      ));

   -- Non-uniform packet with negative values: first 5 samples negative, last 5
   -- positive, designed so the 10-sample average is exactly [GyroA,GyroB,GyroC]/[AccelA,AccelB,AccelC].
   Mixed_Packet : constant Mimu_Eng_Packet.T := (
      Meas_Time => To_Ns (1, 0),
      Samples => [
         0 .. 4 => Eng_Sample (-1_000_000.0, -2_000_000.0, -3_000_000.0, -4_000_000.0, -5_000_000.0, -6_000_000.0),
         5 .. 9 => Eng_Sample (3_000_000.0, 6_000_000.0, 9_000_000.0, 12_000_000.0, 15_000_000.0, 18_000_000.0)
      ]
   );

   -- Time-filtered packet: bogus values in samples 0-4, known values in 5-9.
   -- Per-sample times are first-sample-time + I*10ms; maxTimeTag = base + 90ms.
   -- With a 45 ms window, sample I is kept when (9-I)*10ms <= 45ms, i.e. I in 5..9.
   -- Average of samples 5-9: gyro=[GyroA,GyroB,GyroC], accel=[AccelA,AccelB,AccelC].
   Filtered_Packet : constant Mimu_Eng_Packet.T := (
      Meas_Time => To_Ns (1, 0),
      Samples => [
         0 .. 4 => Eng_Sample (99_000_000.0, 99_000_000.0, 99_000_000.0, 99_000_000.0, 99_000_000.0, 99_000_000.0),
         5 .. 9 => Eng_Sample (1_000_000.0, 2_000_000.0, 3_000_000.0, 4_000_000.0, 5_000_000.0, 6_000_000.0)
      ]
   );

   -- Packet whose newest sample (index 9) is uniquely valued: samples 0-8 carry a
   -- large sentinel while sample 9 carries the standard 1_000_000/2_000_000/3_000_000, 4_000_000/5_000_000/6_000_000 values
   -- (-> [GyroA,GyroB,GyroC]/[AccelA,AccelB,AccelC]). A 0.0 s window keeps only sample 9, so the result
   -- distinguishes "newest sample only" from any multi-sample average.
   Newest_Sample_Packet : constant Mimu_Eng_Packet.T := (
      Meas_Time => To_Ns (1, 0),
      Samples => [
         0 .. 8 => Eng_Sample (50_000_000.0, 50_000_000.0, 50_000_000.0, 50_000_000.0, 50_000_000.0, 50_000_000.0),
         9 => Eng_Sample (1_000_000.0, 2_000_000.0, 3_000_000.0, 4_000_000.0, 5_000_000.0, 6_000_000.0)
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

      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 0));

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

      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 0));
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

      T.Mimu_Eng_Packet_T_Send (Mixed_Packet);
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

      T.Mimu_Eng_Packet_T_Send (Filtered_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Time_Filtering;

   -- A tick with nothing buffered still publishes a data product; with an empty
   -- ring the algorithm returns a zero result.
   overriding procedure Test_Empty_Buffer (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 1.0, Accel_Window => 1.0);

      T.Tick_T_Send (((0, 0), 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [0.0, 0.0, 0.0], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [0.0, 0.0, 0.0], Epsilon => 0.0001);
      end;
   end Test_Empty_Buffer;

   -- Two packets buffered before one tick. Both carry identical uniform data
   -- but strictly-increasing timestamps, so both are ingested and the 20
   -- samples average to the same uniform result.
   overriding procedure Test_Multi_Packet (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 1.0, Accel_Window => 1.0);

      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 0));
      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, Pkt_Subsec_Step));
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Multi_Packet;

   -- Send 5 packets (buffer holds 4); the 5th triggers the overflow event and
   -- is dropped. The tick still processes the 4 buffered packets.
   overriding procedure Test_Buffer_Overflow (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 1.0, Accel_Window => 1.0);

      Natural_Assert.Eq (T.Packet_Buffer_Overflow_History.Get_Count, 0);

      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 0 * Pkt_Subsec_Step));
      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 1 * Pkt_Subsec_Step));
      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 2 * Pkt_Subsec_Step));
      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 3 * Pkt_Subsec_Step));

      -- Buffer is now full (4/4), no overflow yet:
      Natural_Assert.Eq (T.Packet_Buffer_Overflow_History.Get_Count, 0);

      -- 5th packet should trigger the overflow event:
      T.Mimu_Eng_Packet_T_Send (Uniform_Packet (1, 4 * Pkt_Subsec_Step));
      Natural_Assert.Eq (T.Packet_Buffer_Overflow_History.Get_Count, 1);

      -- Tick still processes the 4 buffered packets:
      T.Tick_T_Send (((0, 0), 0));
      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Buffer_Overflow;

   -- Test that an invalid parameter is rejected with an error status (the
   -- Invalid_Parameter handler is null; the Parameters component reports the
   -- failure to the ground).
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
      Param : Parameter.T := T.Parameters.Gyro_Time_Delta ((Value => 1.0));
   begin
      -- Make the parameter invalid by modifying its length.
      Param.Header.Buffer_Length := 0;

      -- Send bad parameter and expect bad response:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Length_Error);

      -- The Invalid_Parameter handler is null, so no event is thrown:
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 0);

      -- Test with invalid id:
      Param.Header.Id := 1_001;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Id_Error);

      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 0);
   end Test_Invalid_Parameter;

   -- The gyro and accel averaging windows are applied independently: a single
   -- packet is filtered by the gyro window for the gyro channel and by the accel
   -- window for the accel channel. With Mixed_Packet (samples 0-4 negative,
   -- samples 5-9 = 3x the uniform value) a tight gyro window keeps only the
   -- newest 5 samples while a wide accel window keeps all 10.
   overriding procedure Test_Asymmetric_Windows (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      -- Gyro window 45 ms keeps samples 5-9; accel window 1.0 s keeps all 10:
      Apply_Standard_Params (T, Gyro_Window => 0.045, Accel_Window => 1.0);

      T.Mimu_Eng_Packet_T_Send (Mixed_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         -- Gyro averages newest 5 samples ([3_000_000, 6_000_000, 9_000_000]) -> 3x the uniform value:
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [3.0 * GyroA, 3.0 * GyroB, 3.0 * GyroC], Epsilon => 0.0001);
         -- Accel averages all 10 samples -> the uniform value:
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Asymmetric_Windows;

   -- A 0.0 s averaging window keeps only the single newest sample (age 0). Using
   -- Newest_Sample_Packet (samples 0-8 a sentinel, sample 9 the standard values)
   -- the result is sample 9 only -> [GyroA,GyroB,GyroC]/[AccelA,AccelB,AccelC], not the sentinel an
   -- all-sample average would produce.
   overriding procedure Test_Zero_Window (Self : in out Instance) is
      T : Tester_Ref renames Self.Tester;
   begin
      Apply_Standard_Params (T, Gyro_Window => 0.0, Accel_Window => 0.0);

      T.Mimu_Eng_Packet_T_Send (Newest_Sample_Packet);
      T.Tick_T_Send (((0, 0), 0));

      Natural_Assert.Eq (T.Imu_Body_Data_History.Get_Count, 1);

      declare
         Output : constant Averaged_Imu_Data.T := T.Imu_Body_Data_History.Get (1);
      begin
         -- Only the newest sample survives the zero window:
         Packed_F32x3_Assert.Eq (Output.Ang_Vel_Body, [GyroA, GyroB, GyroC], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Accel_Body, [AccelA, AccelB, AccelC], Epsilon => 0.0001);
      end;
   end Test_Zero_Window;

end Average_Mimu_Data_Tests.Implementation;
