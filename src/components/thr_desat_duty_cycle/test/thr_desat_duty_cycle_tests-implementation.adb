--------------------------------------------------------------------------------
-- Thr_Desat_Duty_Cycle Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Ada.Assertions;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Packed_U32;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Thr_Desat_Duty_Cycle_Parameters;
with Thr_Force_Cmd;
with Thr_Force_Cmd.Assertion; use Thr_Force_Cmd.Assertion;

package body Thr_Desat_Duty_Cycle_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The per-thruster desaturation force command from the Python reference test
   -- (_tests/test_thrDesatDutyCycle.py), with two of the eight thrusters idle.
   Nominal_Forces : constant Thr_Force_Cmd.T := (Thr_Force => [1.2, 0.2, 0.0, 1.6, 1.2, 0.2, 1.6, 0.0]);
   No_Forces : constant Thr_Force_Cmd.T := (Thr_Force => [others => 0.0]);

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a cadence.
   procedure Apply_Cadence (Self : in out Instance; Firing_Periods : in Unsigned_32; Settling_Periods : in Unsigned_32) is
      T : Component.Thr_Desat_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Desat_Duty_Cycle_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Firing_Periods ((Value => Firing_Periods))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Settling_Periods ((Value => Settling_Periods))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Cadence;

   -- Tick once with the nominal force command and check the gated output. The gate
   -- does no arithmetic on the force, so a passed-through command compares exactly.
   procedure Tick_And_Expect (Self : in out Instance; Tick_Number : in Natural; Firing : in Boolean) is
      T : Component.Thr_Desat_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Thruster_Force_Cmd := Nominal_Forces;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Gated_Force_Cmd_History.Get_Count, Tick_Number);
      Thr_Force_Cmd_Assert.Eq (T.Gated_Force_Cmd_History.Get (Tick_Number), (if Firing then Nominal_Forces else No_Forces));
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
   -- the one-in-three and two-in-three cadences. The reset connector puts each
   -- cadence back at the start of its firing window.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Thr_Desat_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
      Tick_Number : Natural := 0;

      procedure Run_Cadence (Firing_Periods : in Unsigned_32; Settling_Periods : in Unsigned_32) is
         Cycle_Length : constant Unsigned_32 := Firing_Periods + Settling_Periods;
      begin
         Apply_Cadence (Self, Firing_Periods, Settling_Periods);
         T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
         for Update in 0 .. 8 loop
            Tick_Number := @ + 1;
            Tick_And_Expect (Self, Tick_Number, Firing => Unsigned_32 (Update) mod Cycle_Length < Firing_Periods);
         end loop;
      end Run_Cadence;
   begin
      -- The default cadence fires every period, so the gate is fully open:
      Run_Cadence (Firing_Periods => 1, Settling_Periods => 0);
      -- Fire one period in three:
      Run_Cadence (Firing_Periods => 1, Settling_Periods => 2);
      -- Fire two periods in three:
      Run_Cadence (Firing_Periods => 2, Settling_Periods => 1);
      -- A settling window longer than the run fires once and then stays shut:
      Run_Cadence (Firing_Periods => 1, Settling_Periods => 20);
   end Test;

   -- Check that the reset connector restarts the duty cycle at its firing window,
   -- and that a parameter update alone does not.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Thr_Desat_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- One firing period then two settling periods. Init started the cycle at its
      -- firing window, so the first tick fires and the next two do not:
      Apply_Cadence (Self, Firing_Periods => 1, Settling_Periods => 2);
      Tick_And_Expect (Self, 1, Firing => True);
      Tick_And_Expect (Self, 2, Firing => False);

      -- A reset mid-cycle restarts the firing window:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Tick_And_Expect (Self, 3, Firing => True);
      Tick_And_Expect (Self, 4, Firing => False);

      -- Reapplying the cadence keeps the counter running where it was, so the next
      -- tick is still the last settling period rather than a new firing window:
      Apply_Cadence (Self, Firing_Periods => 1, Settling_Periods => 2);
      Tick_And_Expect (Self, 5, Firing => False);
      Tick_And_Expect (Self, 6, Firing => True);
   end Test_Reset;

   -- The algorithm requires at least one firing period and a cycle length that fits
   -- in 32 bits. Validation is the only guard keeping a rejected value out of the
   -- throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Thr_Desat_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Desat_Duty_Cycle_Parameters.Instance;
      One : constant Packed_U32.T := (Value => 1);
      Two : constant Packed_U32.T := (Value => 2);

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Firing_Periods (One)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Settling_Periods (Two)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- Zero firing periods would hold the thrusters off forever, so it is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Firing_Periods ((Value => 0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A cycle length that would wrap around 32 bits is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Settling_Periods ((Value => Unsigned_32'Last))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The largest cycle that does fit is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Settling_Periods ((Value => Unsigned_32'Last - 1))), Success);
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
      T : Component.Thr_Desat_Duty_Cycle.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Gated_Force_Cmd_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Thr_Desat_Duty_Cycle_Tests.Implementation;
