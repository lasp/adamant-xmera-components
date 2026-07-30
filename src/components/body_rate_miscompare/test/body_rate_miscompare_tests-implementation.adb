--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Body_Rate_Fault;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Body_Rate_Fault.Assertion; use Body_Rate_Fault.Assertion;
with Packed_F32;
with Packed_Boolean.Assertion; use Packed_Boolean.Assertion;
with Body_Rate_Miscompare_Parameters;
with Parameter_Enums.Assertion;
with Command;
with Command_Enums;
with Command_Response.Assertion; use Command_Response.Assertion;
with Sys_Time.Assertion; use Sys_Time.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Body_Rate_Miscompare_Tests.Implementation is

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

      -- Reset the component's fault transition tracking state: on targets
      -- where the tester is statically allocated and reused across tests
      -- (bareboard), the instance record defaults are not re-applied between
      -- tests.
      Self.Tester.Reset_Prev_Fault_Latched;

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
      T : Component.Body_Rate_Miscompare.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Body_Rate_Miscompare_Parameters.Instance;

      -- Match the default in body_rate_miscompare.parameters.yaml; stage explicitly so the C-side
      -- bodyRateThreshold (which defaults to 0.0 in C++) gets initialized via Update_Parameters_Action.
      Threshold : constant Packed_F32.T := (Value => 1.0);

      -- Test data based on Python test
      type Test_Vector is record
         Imu_Angular_Velocity : Packed_F32x3.T;
         St_Angular_Velocity : Packed_F32x3.T;
         Expected_Angular_Velocity : Packed_F32x3.T;
         Expected_Fault : Boolean;
      end record;

      -- Default threshold is 1.0 rad/s
      -- Test 1: Nominal - star tracker and IMU agree (diff < threshold)
      -- Test 2: Off-nominal - star tracker and IMU disagree (diff > threshold), output should be IMU rate
      Test_Cases : constant array (1 .. 2) of Test_Vector := [
         -- Nominal: ST rate close to IMU rate, output should be ST rate
         (Imu_Angular_Velocity => [-0.1, 0.2, -0.3],
          St_Angular_Velocity => [-0.09, 0.21, -0.29],
          Expected_Angular_Velocity => [-0.09, 0.21, -0.29],
          Expected_Fault => False),
         -- Off-nominal: ST rate far from IMU rate, output should be IMU rate
         (Imu_Angular_Velocity => [-0.1, 0.2, -0.3],
          St_Angular_Velocity => [1.9, 2.2, 1.7],
          Expected_Angular_Velocity => [-0.1, 0.2, -0.3],
          Expected_Fault => True)
      ];

      Expected_Dp_Count : Natural := 0;
   begin
      -- Stage and apply the threshold parameter:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Body_Rate_Threshold (Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      for I in Test_Cases'Range loop
         -- Set IMU angular velocity data dependency
         T.Imu_Body := (
            Avg_Ang_Vel_Body => Test_Cases (I).Imu_Angular_Velocity,
            Fault_Detected => 0,
            Mimu_Index_Faulted => -1
         );

         -- Set star tracker attitude data dependency
         T.Star_Tracker_Attitude := (
            Time_Tag => 0,
            Sigma_Bn => [0.0, 0.0, 0.0],
            Omega_Bn_B => Test_Cases (I).St_Angular_Velocity
         );

         -- Call algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Make sure data products produced. Every tick publishes the body rate and
         -- fault status products; the tick where the fault first latches (case 2)
         -- additionally publishes the Fault_Latch_Time product.
         Expected_Dp_Count := @ + 2;
         if Test_Cases (I).Expected_Fault then
            Expected_Dp_Count := @ + 1;
         end if;
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Expected_Dp_Count);
         Natural_Assert.Eq (T.Body_Rate_History.Get_Count, I);
         Natural_Assert.Eq (T.Rate_Fault_Status_History.Get_Count, I);

         -- Check body rate output (Body_Rate is now the omega_BN_B vector directly)
         declare
            Rate_Output : constant Packed_F32x3.T := T.Body_Rate_History.Get (I);
         begin
            Packed_F32x3_Assert.Eq (
               Rate_Output,
               Test_Cases (I).Expected_Angular_Velocity,
               Epsilon => 0.0001
            );
         end;

         -- Check fault status
         declare
            Fault_Output : constant Body_Rate_Fault.T := T.Rate_Fault_Status_History.Get (I);
         begin
            Body_Rate_Fault_Assert.Eq (
               Fault_Output,
               (Fault_Detected => Test_Cases (I).Expected_Fault)
            );
         end;
      end loop;
   end Test;

   -- Verify the Use_Imu_Rates command forces and releases IMU-rate output and reports the new setting.
   overriding procedure Test_Use_Imu_Rates_Command (Self : in out Instance) is
      T : Component.Body_Rate_Miscompare.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Agreeing rates (difference well under the 1.0 rad/s default threshold), but with
      -- distinct IMU vs star tracker values so the selected output reveals which branch ran.
      Imu_Rate : constant Packed_F32x3.T := [0.1, 0.2, 0.3];
      St_Rate : constant Packed_F32x3.T := [0.11, 0.21, 0.31];
   begin
      -- Provide agreeing data dependencies:
      T.Imu_Body := (Avg_Ang_Vel_Body => Imu_Rate, Fault_Detected => 0, Mimu_Index_Faulted => -1);
      T.Star_Tracker_Attitude := (Time_Tag => 0, Sigma_Bn => [0.0, 0.0, 0.0], Omega_Bn_B => St_Rate);

      -- Command the override on:
      T.Command_T_Send (T.Commands.Use_Imu_Rates ((Value => True)));

      -- Command was accepted:
      Natural_Assert.Eq (T.Command_Response_T_Recv_Sync_History.Get_Count, 1);
      Command_Response_Assert.Eq (T.Command_Response_T_Recv_Sync_History.Get (1), (
         Source_Id => 0,
         Registration_Id => 0,
         Command_Id => T.Commands.Get_Use_Imu_Rates_Id,
         Status => Command_Enums.Command_Response_Status.Success
      ));
      -- New setting reported via event:
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Use_Imu_Rates_Set_History.Get_Count, 1);
      Packed_Boolean_Assert.Eq (T.Use_Imu_Rates_Set_History.Get (1), (Value => True));

      -- Tick: although the rates agree, the override forces IMU-rate output with the fault set:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Body_Rate_History.Get_Count, 1);
      Natural_Assert.Eq (T.Rate_Fault_Status_History.Get_Count, 1);
      Packed_F32x3_Assert.Eq (T.Body_Rate_History.Get (1), Imu_Rate, Epsilon => 0.0001);
      Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (1), (Fault_Detected => True));

      -- Command the override back off:
      T.Command_T_Send (T.Commands.Use_Imu_Rates ((Value => False)));
      Natural_Assert.Eq (T.Command_Response_T_Recv_Sync_History.Get_Count, 2);
      Command_Response_Assert.Eq (T.Command_Response_T_Recv_Sync_History.Get (2), (
         Source_Id => 0,
         Registration_Id => 0,
         Command_Id => T.Commands.Get_Use_Imu_Rates_Id,
         Status => Command_Enums.Command_Response_Status.Success
      ));
      Natural_Assert.Eq (T.Use_Imu_Rates_Set_History.Get_Count, 2);
      Packed_Boolean_Assert.Eq (T.Use_Imu_Rates_Set_History.Get (2), (Value => False));

      -- Tick: normal miscompare logic resumes, so the agreeing star tracker rate is output with no fault:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Body_Rate_History.Get_Count, 2);
      Natural_Assert.Eq (T.Rate_Fault_Status_History.Get_Count, 2);
      Packed_F32x3_Assert.Eq (T.Body_Rate_History.Get (2), St_Rate, Epsilon => 0.0001);
      Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (2), (Fault_Detected => False));
   end Test_Use_Imu_Rates_Command;

   -- Verify the reset connector clears the algorithm's fault persistence counter.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Body_Rate_Miscompare.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Body_Rate_Miscompare_Parameters.Instance;

      -- Rates that disagree by well over the 1.0 rad/s threshold:
      Imu_Rate : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      St_Rate : constant Packed_F32x3.T := [2.0, 0.0, 0.0];

      -- Tick once with the disagreeing data, then assert the cumulative fault-status history:
      procedure Tick_Disagree (Count : in Natural; Expected_Fault : in Boolean) is
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         Natural_Assert.Eq (T.Rate_Fault_Status_History.Get_Count, Count);
         Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (Count), (Fault_Detected => Expected_Fault));
      end Tick_Disagree;
   begin
      -- Require three consecutive disagreements before the fault latches:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Fault_Persistence_Limit ((Value => 3))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Persistent disagreement:
      T.Imu_Body := (Avg_Ang_Vel_Body => Imu_Rate, Fault_Detected => 0, Mimu_Index_Faulted => -1);
      T.Star_Tracker_Attitude := (Time_Tag => 0, Sigma_Bn => [0.0, 0.0, 0.0], Omega_Bn_B => St_Rate);

      -- Two disagreements: persistence counter reaches 2 (limit 3 not yet hit) -> no fault:
      Tick_Disagree (1, False);
      Tick_Disagree (2, False);

      -- Reset clears the persistence counter:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Two more disagreements: counter climbs from zero to 2 again -> still no fault. Without the
      -- reset, this would be the third/fourth consecutive disagreement and the fault would have latched.
      Tick_Disagree (3, False);
      Tick_Disagree (4, False);

      -- One more disagreement: counter reaches 3 -> fault latches:
      Tick_Disagree (5, True);
   end Test_Reset;

   -- Verify fault flag transitions publish the latch-time data product and
   -- latched/cleared events exactly once per transition, for both the miscompare
   -- latch and the commanded override.
   overriding procedure Test_Fault_Latch_Transition (Self : in out Instance) is
      T : Component.Body_Rate_Miscompare.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Body_Rate_Miscompare_Parameters.Instance;

      Imu_Rate : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      -- Difference well under/over the 1.0 rad/s threshold:
      Agreeing_St_Rate : constant Packed_F32x3.T := [0.1, 0.0, 0.0];
      Disagreeing_St_Rate : constant Packed_F32x3.T := [2.0, 0.0, 0.0];
      Latch_Time : constant Sys_Time.T := (Seconds => 100, Subseconds => 0);
   begin
      -- Stage the threshold and persistence limit explicitly rather than
      -- relying on defaults: on targets where the tester is statically
      -- allocated and reused across tests (bareboard), parameter values
      -- staged by earlier tests would otherwise leak into this one.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Body_Rate_Threshold ((Value => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Fault_Persistence_Limit ((Value => 1))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Imu_Body := (Avg_Ang_Vel_Body => Imu_Rate, Fault_Detected => 0, Mimu_Index_Faulted => -1);

      -- Agreeing tick: no fault, no transition reports.
      T.Star_Tracker_Attitude := (Time_Tag => 0, Sigma_Bn => [0.0, 0.0, 0.0], Omega_Bn_B => Agreeing_St_Rate);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Body_Rate_Fault_Latched_History.Get_Count, 0);
      Natural_Assert.Eq (T.Fault_Latch_Time_History.Get_Count, 0);

      -- Disagreeing tick (default persistence limit of 1): the fault latches, and the
      -- transition is reported exactly once, stamped with the tick time.
      T.Star_Tracker_Attitude := (Time_Tag => 0, Sigma_Bn => [0.0, 0.0, 0.0], Omega_Bn_B => Disagreeing_St_Rate);
      T.Tick_T_Send ((Time => Latch_Time, Count => 0));
      Natural_Assert.Eq (T.Body_Rate_Fault_Latched_History.Get_Count, 1);
      Natural_Assert.Eq (T.Fault_Latch_Time_History.Get_Count, 1);
      Sys_Time_Assert.Eq (T.Fault_Latch_Time_History.Get (1), Latch_Time);

      -- Another disagreeing tick: still latched -> no new transition report.
      T.Tick_T_Send ((Time => (Seconds => 101, Subseconds => 0), Count => 0));
      Natural_Assert.Eq (T.Body_Rate_Fault_Latched_History.Get_Count, 1);
      Natural_Assert.Eq (T.Fault_Latch_Time_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_Rate_Fault_Cleared_History.Get_Count, 0);

      -- Agreeing rates do NOT unlatch the fault (only the command does), so still no
      -- cleared report and the fault status remains set:
      T.Star_Tracker_Attitude := (Time_Tag => 0, Sigma_Bn => [0.0, 0.0, 0.0], Omega_Bn_B => Agreeing_St_Rate);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Body_Rate_Fault_Cleared_History.Get_Count, 0);
      Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (4), (Fault_Detected => True));

      -- Clear the latch by command; the next tick reports the fault cleared exactly once:
      T.Command_T_Send (T.Commands.Use_Imu_Rates ((Value => False)));
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Body_Rate_Fault_Cleared_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_Rate_Fault_Latched_History.Get_Count, 1);
      Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (5), (Fault_Detected => False));

      -- Engage the commanded override with agreeing rates: the fault flag sets, and
      -- the transition is reported just like a miscompare latch.
      T.Command_T_Send (T.Commands.Use_Imu_Rates ((Value => True)));
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (6), (Fault_Detected => True));
      Natural_Assert.Eq (T.Body_Rate_Fault_Latched_History.Get_Count, 2);
      Natural_Assert.Eq (T.Fault_Latch_Time_History.Get_Count, 2);
      Natural_Assert.Eq (T.Body_Rate_Fault_Cleared_History.Get_Count, 1);

      -- Disengage the override: the fault flag clears and the transition is reported
      -- exactly once.
      T.Command_T_Send (T.Commands.Use_Imu_Rates ((Value => False)));
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Body_Rate_Fault_Assert.Eq (T.Rate_Fault_Status_History.Get (7), (Fault_Detected => False));
      Natural_Assert.Eq (T.Body_Rate_Fault_Latched_History.Get_Count, 2);
      Natural_Assert.Eq (T.Body_Rate_Fault_Cleared_History.Get_Count, 2);
   end Test_Fault_Latch_Transition;

   -- Verify a malformed command is rejected and reported via the Invalid_Command_Received event.
   overriding procedure Test_Invalid_Command (Self : in out Instance) is
      T : Component.Body_Rate_Miscompare.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Build a valid command, then corrupt its argument buffer length so the framework
      -- rejects it and routes to the Invalid_Command handler:
      Invalid_Cmd : Command.T := T.Commands.Use_Imu_Rates ((Value => True));
   begin
      Invalid_Cmd.Header.Arg_Buffer_Length := 0;
      T.Command_T_Send (Invalid_Cmd);

      -- The command is rejected with a length error:
      Natural_Assert.Eq (T.Command_Response_T_Recv_Sync_History.Get_Count, 1);
      Command_Response_Assert.Eq (T.Command_Response_T_Recv_Sync_History.Get (1), (
         Source_Id => 0,
         Registration_Id => 0,
         Command_Id => T.Commands.Get_Use_Imu_Rates_Id,
         Status => Command_Enums.Command_Response_Status.Length_Error
      ));

      -- The rejection is reported via the Invalid_Command_Received event. (The errant field
      -- detail for a length error is not meaningfully predictable, so only the count is checked.)
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Invalid_Command_Received_History.Get_Count, 1);

      -- The override must NOT have been applied -- no setting event:
      Boolean_Assert.Eq (T.Use_Imu_Rates_Set_History.Is_Empty, True);
   end Test_Invalid_Command;

end Body_Rate_Miscompare_Tests.Implementation;
