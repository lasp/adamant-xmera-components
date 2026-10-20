--------------------------------------------------------------------------------
-- Average_Rw_Speed_Data Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with Ada.Real_Time;
with AUnit.Assertions;
with Average_Rw_Speed_Data_Parameters;
with Basic_Assertions; use Basic_Assertions;
with Interfaces; use Interfaces;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Rwa_Speeds;
with Sys_Time;
with Sys_Time.Arithmetic;
with Sys_Time.Assertion; use Sys_Time.Assertion;

package body Average_Rw_Speed_Data_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Measurements arrive every quarter second, which is exact in system time since the
   -- subseconds count is a power of two, and the measurement of step I is stamped with
   -- the tick time of step I, or a given lead ahead of it. Wheel K of step I spins at
   -- 10 * I + K, as in the algorithm's C++ unit tests, so the mean over a run of steps
   -- is exact in single precision. The stale limit is shorter than a step, so a product
   -- not refreshed on a tick reads stale on it.
   Quarter_Second : constant Sys_Time.Subseconds_Type := Sys_Time.Subseconds_Type'Last / 4 + 1;
   Steps_Per_Second : constant := 4;
   Stale_Limit : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (100);
   Zero_Speeds : constant Rwa_Speeds.T := (Rwa_1 => 0.0, Rwa_2 => 0.0, Rwa_3 => 0.0, Rwa_4 => 0.0);

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- The tick time for step I.
   function Tick_Time (Step : in Positive) return Sys_Time.T is
      ((Seconds => Unsigned_32 (Step / Steps_Per_Second), Subseconds => Sys_Time.Subseconds_Type (Step mod Steps_Per_Second) * Quarter_Second));

   -- The wheel speeds of step I.
   function Speeds (Step : in Positive) return Rwa_Speeds.T is
      ((Rwa_1 => Short_Float (10 * Step), Rwa_2 => Short_Float (10 * Step + 1), Rwa_3 => Short_Float (10 * Step + 2), Rwa_4 => Short_Float (10 * Step + 3)));

   -- Stage and apply an averaging window.
   procedure Apply_Window (Self : in out Instance; Window : in Short_Float) is
      T : Component.Average_Rw_Speed_Data.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Average_Rw_Speed_Data_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Averaging_Window ((Value => Window))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Window;

   -- Send the tick for step I. The wheel speed product is refreshed with the
   -- measurement of step I, made Lead ahead of the tick, and one output stamped with the
   -- measurement time is expected. The history only holds the output of this tick.
   procedure Send_Tick (Self : in out Instance; Step : in Positive; Lead : in Ada.Real_Time.Time_Span := Ada.Real_Time.Time_Span_Zero) is
      use Sys_Time.Arithmetic;
      T : Component.Average_Rw_Speed_Data.Implementation.Tester.Instance_Access renames Self.Tester;
      Meas_Time : Sys_Time.T;
   begin
      pragma Assert (Subtract (Tick_Time (Step), Lead, Meas_Time) = Success);
      T.Wheel_Speeds := Speeds (Step);
      T.Data_Dependency_Timestamp_Override := Meas_Time;
      T.Data_Product_T_Recv_Sync_History.Clear;
      T.Averaged_Wheel_Speeds_History.Clear;
      T.Tick_T_Send ((Time => Tick_Time (Step), Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Averaged_Wheel_Speeds_History.Get_Count, 1);
      Sys_Time_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get (1).Header.Time, Meas_Time);
   end Send_Tick;

   -- Check that the last output is the mean of the samples of the given steps. Wheel K
   -- of step I spins at 10 * I + K, so the mean is 10 times the mean step, plus K.
   type Step_List is array (Positive range <>) of Positive;
   procedure Expect_Mean (Self : in out Instance; Steps : in Step_List) is
      Output : constant Rwa_Speeds.T := Self.Tester.Averaged_Wheel_Speeds_History.Get (1);
      Sum : Natural := 0;
   begin
      for Step of Steps loop
         Sum := @ + Step;
      end loop;
      declare
         Mean : constant Long_Float := 10.0 * Long_Float (Sum) / Long_Float (Steps'Length);
      begin
         Short_Float_Assert.Eq (Output.Rwa_1, Short_Float (Mean), Epsilon => 1.0E-4);
         Short_Float_Assert.Eq (Output.Rwa_2, Short_Float (Mean + 1.0), Epsilon => 1.0E-4);
         Short_Float_Assert.Eq (Output.Rwa_3, Short_Float (Mean + 2.0), Epsilon => 1.0E-4);
         Short_Float_Assert.Eq (Output.Rwa_4, Short_Float (Mean + 3.0), Epsilon => 1.0E-4);
      end;
   end Expect_Mean;

   -- Check that the last output is the mean of the samples of steps First through Last.
   procedure Expect_Mean (Self : in out Instance; First : in Positive; Last : in Positive) is
      Steps : Step_List (First .. Last);
   begin
      for Step in Steps'Range loop
         Steps (Step) := Step;
      end loop;
      Expect_Mean (Self, Steps);
   end Expect_Mean;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- The product starts out with zero speeds stamped just after time zero, stale on
      -- every tick until a measurement refreshes it:
      Self.Tester.Wheel_Speeds := Zero_Speeds;
      Self.Tester.Data_Dependency_Timestamp_Override := (Seconds => 0, Subseconds => 1);
      Self.Tester.Component_Instance.Map_Data_Dependencies (Wheel_Speeds_Id => 0, Wheel_Speeds_Stale_Limit => Stale_Limit);

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

   -- Feed a ramp of wheel speed measurements and check the output is the mean of the
   -- samples in the window, including the sample at the window's edge, and is stamped
   -- with the time of the measurement, to ensure the Ada to C to C++ integration is
   -- sound. The default window of one second holds five quarter second samples, the
   -- newest and the four before it.
   overriding procedure Test (Self : in out Instance) is
      Samples_In_Window : constant := 5;
   begin
      for Step in 1 .. 14 loop
         Send_Tick (Self, Step);
         Expect_Mean (Self, First => Positive'Max (1, Step - Samples_In_Window + 1), Last => Step);
      end loop;

      -- The last measurement is made ahead of its tick, within the stale limit, so the
      -- output stamp is told apart from the tick time. The window still reaches back
      -- to the sample a second behind it:
      Send_Tick (Self, 15, Lead => Ada.Real_Time.Milliseconds (50));
      Expect_Mean (Self, First => 15 - Samples_In_Window + 1, Last => 15);
   end Test;

   -- The wheel speeds are measured on every tick, so a stale product means the
   -- assembly is not measuring ahead of this component on each tick. The component
   -- asserts rather than publishing anything.
   overriding procedure Test_Stale_Data_Dependency (Self : in out Instance) is
      T : Component.Average_Rw_Speed_Data.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Send_Tick (Self, 1);
      Expect_Mean (Self, First => 1, Last => 1);

      -- No measurement was made on this tick, so the product is stale:
      T.Data_Product_T_Recv_Sync_History.Clear;
      T.Averaged_Wheel_Speeds_History.Clear;
      begin
         T.Tick_T_Send ((Time => Tick_Time (2), Count => 0));
         AUnit.Assertions.Assert (False, "A stale product should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 0);
   end Test_Stale_Data_Dependency;

   -- Ensure a new averaging window reaches the algorithm on the next tick and is
   -- applied to the stored samples.
   overriding procedure Test_Window_Update (Self : in out Instance) is
   begin
      for Step in 1 .. 8 loop
         Send_Tick (Self, Step);
      end loop;
      Expect_Mean (Self, First => 4, Last => 8);

      -- A half second window holds three samples:
      Apply_Window (Self, 0.5);
      Send_Tick (Self, 9);
      Expect_Mean (Self, First => 7, Last => 9);

      -- The largest window, two seconds, reaches back over nine samples, which the
      -- algorithm kept while the window was shorter:
      Apply_Window (Self, 2.0);
      Send_Tick (Self, 10);
      Expect_Mean (Self, First => 2, Last => 10);
   end Test_Window_Update;

   -- Ensure the reset connector clears the stored samples, so the next measurement
   -- is averaged alone.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Average_Rw_Speed_Data.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      for Step in 1 .. 3 loop
         Send_Tick (Self, Step);
      end loop;
      Expect_Mean (Self, First => 1, Last => 3);

      -- After the reset the next measurement starts the average over:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Send_Tick (Self, 4);
      Expect_Mean (Self, First => 4, Last => 4);
      Send_Tick (Self, 5);
      Expect_Mean (Self, First => 4, Last => 5);
   end Test_Reset;

   -- The algorithm requires a window greater than zero and at most two seconds.
   -- Validation is the only guard keeping a rejected value out of the throwing
   -- Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Average_Rw_Speed_Data.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Average_Rw_Speed_Data_Parameters.Instance;

      -- Stage a window and check the set is rejected.
      procedure Expect_Rejection (Par : in Parameter.T) is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
         Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);
      end Expect_Rejection;

      -- Stage a window and check the set is accepted.
      procedure Expect_Acceptance (Window : in Short_Float) is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Averaging_Window ((Value => Window))), Success);
         Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      end Expect_Acceptance;
   begin
      -- The reference window and both ends of the accepted range:
      Expect_Acceptance (1.0);
      Expect_Acceptance (2.0);
      Expect_Acceptance (Short_Float'Succ (0.0));

      -- A window of zero or less would hold nothing, and one above two seconds exceeds
      -- what the algorithm stores:
      Expect_Rejection (Params.Averaging_Window ((Value => 0.0)));
      Expect_Rejection (Params.Averaging_Window ((Value => -0.1)));
      Expect_Rejection (Params.Averaging_Window ((Value => 2.01)));

      -- A non-finite window is rejected before the algorithm is asked, by the type
      -- validation at staging. The value is injected as raw bytes because the compiler
      -- will not let a non-finite Short_Float be written as a literal, and because that
      -- is how one would arrive: as bytes from the ground.
      declare
         Par : Parameter.T := Params.Averaging_Window ((Value => 1.0));
      begin
         -- Overwrite the big-endian float with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 0, 0];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Validation_Error);
      end;

      -- Restoring the reference window makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Expect_Acceptance (1.0);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Average_Rw_Speed_Data.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Averaged_Wheel_Speeds_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Average_Rw_Speed_Data_Tests.Implementation;
