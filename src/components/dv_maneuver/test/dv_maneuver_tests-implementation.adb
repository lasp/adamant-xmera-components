--------------------------------------------------------------------------------
-- Dv_Maneuver Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with Ada.Real_Time;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Cmd_Force_Body.Assertion; use Cmd_Force_Body.Assertion;
with Dv_Maneuver_Enums; use Dv_Maneuver_Enums;
with Dv_Maneuver_Parameters;
with Packed_Burn_State.Assertion; use Packed_Burn_State.Assertion;
with Packed_F32x3;
with Parameter;
with Parameter_Enums.Assertion;
with Parameter_Update;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Dv_Maneuver_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The burn of the algorithm's Python reference test (_tests/test_dvManeuver.py):
   -- the thrusters accelerate the spacecraft at two meters per second squared along
   -- the third axis, so at the control period of half a second the accumulated
   -- delta-V at step I is I meters per second along it, and the burn time is half of
   -- I seconds, the burn starting at step zero.
   Control_Period : constant Long_Float := 0.5;
   Force : constant Packed_F32x3.T := [1.0, -2.0, 5.0];
   Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   Epsilon : constant := 1.0E-6;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply the body force.
   procedure Apply_Force (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Maneuver_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cmd_Force_B (Force)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Force;

   -- Stage the burn times and the commanded delta-V of a burn.
   procedure Stage_Burn (Self : in out Instance; Delta_V : in Short_Float; Min_Time : in Long_Float; Max_Time : in Long_Float) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Maneuver_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Min_Time ((Value => Min_Time))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Max_Time ((Value => Max_Time))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cmd_Dv_N ([0.0, 0.0, Delta_V])), Success);
   end Stage_Burn;

   -- Discard the staged parameters, as the state manager does when a component
   -- rejects its part of a state change.
   procedure Discard_Burn (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
      use Parameter_Enums.Parameter_Operation_Type;
      Param_Update : Parameter_Update.T := (Table_Id => 1, Operation => Discard, Status => Success, Param => ((0, 0), [others => 0]));
   begin
      T.Parameter_Update_T_Provide (Param_Update);
      Parameter_Update_Status_Assert.Eq (Param_Update.Status, Success);
   end Discard_Burn;

   -- Stage, validate and update a burn, as the state manager does when a burn is
   -- commanded.
   procedure Command_Burn (Self : in out Instance; Delta_V : in Short_Float; Min_Time : in Long_Float; Max_Time : in Long_Float) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Stage_Burn (Self, Delta_V, Min_Time, Max_Time);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Command_Burn;

   -- Send the tick for step I, with the delta-V accumulated by then, and check the
   -- force command and the burn state it publishes. The histories only hold the
   -- outputs of this tick.
   procedure Send_Tick (Self : in out Instance; Step : in Natural; Executing : in Boolean) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Accumulated_Delta_V := [0.0, 0.0, Short_Float (Step)];
      T.Data_Product_T_Recv_Sync_History.Clear;
      T.Commanded_Force_History.Clear;
      T.Burn_State_History.Clear;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Commanded_Force_History.Get_Count, 1);
      Natural_Assert.Eq (T.Burn_State_History.Get_Count, 1);
      Cmd_Force_Body_Assert.Eq (T.Commanded_Force_History.Get (1), (Force_Request_Body => (if Executing then Force else Zero_Vector)), Epsilon => Epsilon);
      Packed_Burn_State_Assert.Eq (T.Burn_State_History.Get (1), (Value => (if Executing then Burn_State.Executing else Burn_State.Complete)));
   end Send_Tick;

   -- Run a burn from step First to step Last, expecting it to execute until step
   -- Completes_At and to be complete from there on.
   procedure Run_Burn (Self : in out Instance; First : in Natural; Last : in Natural; Completes_At : in Natural) is
   begin
      for Step in First .. Last loop
         Send_Tick (Self, Step, Executing => Step < Completes_At);
      end loop;
   end Run_Burn;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- The product is produced every tick, so it gets no stale limit:
      Self.Tester.Component_Instance.Map_Data_Dependencies (Accumulated_Delta_V_Id => 0, Accumulated_Delta_V_Stale_Limit => Ada.Real_Time.Time_Span_Zero);

      -- Call component init here.
      Self.Tester.Component_Instance.Init (Control_Period => Control_Period);

      -- Call the component set up method that the assembly would normally call.
      Self.Tester.Component_Instance.Set_Up;

      -- The body force of the reference test is set for a mission phase, so it is set
      -- once here:
      Apply_Force (Self);
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

   -- Run the burn of the algorithm's Python reference test, with the delta-V
   -- accumulating at a constant rate, and check the force command and the burn state
   -- on every tick until the commanded delta-V completes the burn, to ensure the Ada
   -- to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance) is
   begin
      -- The first tick applies the burn and starts it. The commanded delta-V of 4.3
      -- is reached at step 5, after the minimum burn time of zero, so the burn is
      -- complete from there:
      Command_Burn (Self, Delta_V => 4.3, Min_Time => 0.0, Max_Time => 3.0);
      Run_Burn (Self, First => 0, Last => 8, Completes_At => 5);
   end Test;

   -- Ensure the minimum burn time holds a burn whose delta-V is reached early, and
   -- the maximum burn time ends one whose delta-V is never reached.
   overriding procedure Test_Time_Limits (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- The delta-V is reached at step 5, but the burn runs until the minimum burn
      -- time of four seconds has elapsed at step 8:
      Command_Burn (Self, Delta_V => 4.3, Min_Time => 4.0, Max_Time => 5.0);
      Run_Burn (Self, First => 0, Last => 9, Completes_At => 8);

      -- A delta-V of ten is never reached, so the burn ends at the maximum burn time
      -- of three seconds, at step 6. The reset restarts the burn at the next tick:
      Command_Burn (Self, Delta_V => 10.0, Min_Time => 0.0, Max_Time => 3.0);
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Run_Burn (Self, First => 0, Last => 7, Completes_At => 6);
   end Test_Time_Limits;

   -- Ensure a complete burn stays complete, through a new burn as well, until the
   -- reset starts a new one.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Command_Burn (Self, Delta_V => 4.3, Min_Time => 0.0, Max_Time => 3.0);
      Run_Burn (Self, First => 0, Last => 7, Completes_At => 5);

      -- A new burn with a longer minimum time does not reopen the complete one:
      Command_Burn (Self, Delta_V => 4.3, Min_Time => 2.0, Max_Time => 100.0);
      Send_Tick (Self, 8, Executing => False);

      -- The reset starts it. The delta-V is already reached, so the burn runs for the
      -- minimum time, which is four steps, and is complete at the fifth:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Run_Burn (Self, First => 9, Last => 14, Completes_At => 13);
   end Test_Reset;

   -- The algorithm requires a finite minimum burn time that is not negative and a
   -- finite positive maximum burn time greater than the minimum once both are rounded
   -- to nanoseconds. Validation is the only guard keeping a rejected burn out of the
   -- throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Burn (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Stage a burn the algorithm rejects, check validation refuses it, and discard
      -- it, as the state manager would.
      procedure Expect_Rejection (Min_Time : in Long_Float; Max_Time : in Long_Float) is
      begin
         Stage_Burn (Self, Delta_V => 4.3, Min_Time => Min_Time, Max_Time => Max_Time);
         Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);
         Discard_Burn (Self);
      end Expect_Rejection;
   begin
      -- The reference burn is accepted, and the first tick applies it and starts
      -- the burn:
      Command_Burn (Self, Delta_V => 4.3, Min_Time => 1.0, Max_Time => 3.0);
      Send_Tick (Self, 0, Executing => True);

      -- A negative minimum, a zero maximum, and a maximum not above the minimum,
      -- including one that rounds to the same nanosecond, are rejected:
      Expect_Rejection (Min_Time => -0.1, Max_Time => 3.0);
      Expect_Rejection (Min_Time => 1.0, Max_Time => 0.0);
      Expect_Rejection (Min_Time => 1.0, Max_Time => 1.0);
      Expect_Rejection (Min_Time => 1.0, Max_Time => 1.0 + 1.0E-10);

      -- The rejections were never applied, so the reference burn goes on: the
      -- delta-V is reached at step 5, after the minimum burn time of one second, so
      -- the burn is complete from there:
      Run_Burn (Self, First => 1, Last => 7, Completes_At => 5);
   end Test_Invalid_Burn;

   -- The algorithm requires a finite force. Validation is the only guard keeping a
   -- rejected value out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Maneuver_Parameters.Instance;
      Par : Parameter.T := Params.Cmd_Force_B (Force);
   begin
      -- The reference force is accepted:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cmd_Force_B (Force)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A non-finite force is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite float be written as a literal, and because
      -- that is how one would arrive: as bytes from the ground. The staging type check
      -- of the array accepts it, and copying it for the algorithm raises, which
      -- validation reports as a rejection.
      Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 0, 0];
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring the reference force makes the set acceptable again, so the rejection
      -- above was caused by the perturbed value:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cmd_Force_B (Force)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Dv_Maneuver.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Commanded_Force_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Dv_Maneuver_Tests.Implementation;
