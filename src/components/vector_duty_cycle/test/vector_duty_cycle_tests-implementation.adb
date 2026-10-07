--------------------------------------------------------------------------------
-- Vector_Duty_Cycle Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Ada.Assertions;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Cmd_Torque_Body;
with Cmd_Torque_Body.Assertion; use Cmd_Torque_Body.Assertion;
with Packed_U32;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Vector_Duty_Cycle_Parameters;

package body Vector_Duty_Cycle_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The body torque from the Python reference test (_tests/test_vectorDutyCycle.py).
   Nominal_Torque : constant Cmd_Torque_Body.T := (Torque_Request_Body => [1.2E-2, -3.5E-3, 7.0E-4]);
   No_Torque : constant Cmd_Torque_Body.T := (Torque_Request_Body => [others => 0.0]);

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a cadence.
   procedure Apply_Cadence (Self : in out Instance; On_Periods : in Unsigned_32; Off_Periods : in Unsigned_32) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Vector_Duty_Cycle_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Periods ((Value => On_Periods))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Off_Periods ((Value => Off_Periods))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Cadence;

   -- Tick once with the nominal torque and check that one output was published.
   procedure Tick (Self : in out Instance; Tick_Number : in Natural) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Commanded_Torque := Nominal_Torque;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Gated_Torque_History.Get_Count, Tick_Number);
   end Tick;

   -- Tick once and check the output. The duty cycle does no arithmetic on the vector,
   -- so a passed-through torque compares exactly.
   procedure Tick_And_Expect (Self : in out Instance; Tick_Number : in Natural; On : in Boolean) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Tick (Self, Tick_Number);
      Cmd_Torque_Body_Assert.Eq (T.Gated_Torque_History.Get (Tick_Number), (if On then Nominal_Torque else No_Torque));
   end Tick_And_Expect;

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

   -- Run the cadences of the Python reference test to ensure the Ada to C to C++
   -- integration is sound. Each cadence runs for nine ticks, three whole cycles of
   -- the one-in-three and two-in-three cadences. A cadence reaches the algorithm on
   -- the tick after it is applied and keeps the position in the cycle, so each run
   -- ticks once and then resets to start at the on window, as the reference test
   -- starts each cadence fresh.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
      Tick_Number : Natural := 0;

      procedure Run_Cadence (On_Periods : in Unsigned_32; Off_Periods : in Unsigned_32) is
         Cycle_Length : constant Unsigned_32 := On_Periods + Off_Periods;
      begin
         Apply_Cadence (Self, On_Periods, Off_Periods);
         Tick_Number := @ + 1;
         Tick (Self, Tick_Number);
         T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
         for Update in 0 .. 8 loop
            Tick_Number := @ + 1;
            Tick_And_Expect (Self, Tick_Number, On => Unsigned_32 (Update) mod Cycle_Length < On_Periods);
         end loop;
      end Run_Cadence;
   begin
      -- The default cadence is on every period, so the vector always passes:
      Run_Cadence (On_Periods => 1, Off_Periods => 0);
      -- On one period in three:
      Run_Cadence (On_Periods => 1, Off_Periods => 2);
      -- On two periods in three:
      Run_Cadence (On_Periods => 2, Off_Periods => 1);
      -- An off window longer than the run passes once and then stays at zero:
      Run_Cadence (On_Periods => 1, Off_Periods => 20);
   end Test;

   -- Check that the reset connector restarts the duty cycle at its on window, and
   -- that a parameter update alone does not.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Init built the default cadence, on every period, and its first update was the
      -- on window. One on period then two off periods reaches the algorithm on the
      -- next tick and keeps that position, so the cycle continues into its two off
      -- periods before the on window comes round:
      Apply_Cadence (Self, On_Periods => 1, Off_Periods => 2);
      Tick_And_Expect (Self, 1, On => False);
      Tick_And_Expect (Self, 2, On => False);
      Tick_And_Expect (Self, 3, On => True);
      Tick_And_Expect (Self, 4, On => False);

      -- A reset mid-cycle restarts the on window:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Tick_And_Expect (Self, 5, On => True);
      Tick_And_Expect (Self, 6, On => False);

      -- Reapplying the cadence keeps the position where it was, so the next tick is
      -- still the last off period rather than a new on window:
      Apply_Cadence (Self, On_Periods => 1, Off_Periods => 2);
      Tick_And_Expect (Self, 7, On => False);
      Tick_And_Expect (Self, 8, On => True);
   end Test_Reset;

   -- The algorithm requires at least one on period and a cycle length that fits in
   -- 32 bits. Validation is the only guard keeping a rejected value out of the
   -- throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Vector_Duty_Cycle_Parameters.Instance;
      One : constant Packed_U32.T := (Value => 1);
      Two : constant Packed_U32.T := (Value => 2);

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Periods (One)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Off_Periods (Two)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- Zero on periods would hold the output at zero forever, so it is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Periods ((Value => 0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A cycle length that would wrap around 32 bits is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Off_Periods ((Value => Unsigned_32'Last))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The largest cycle that does fit is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Off_Periods ((Value => Unsigned_32'Last - 1))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Vector_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Gated_Torque_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Vector_Duty_Cycle_Tests.Implementation;
