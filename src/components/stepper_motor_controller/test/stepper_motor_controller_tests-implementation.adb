--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Tests Body
--------------------------------------------------------------------------------

with AUnit.Assertions; use AUnit.Assertions;
with Ada.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Stepper_Controller_Step;
with Stepper_Controller_Step.Assertion; use Stepper_Controller_Step.Assertion;
with Data_Product_Enums;
with Stepper_Enums; use Stepper_Enums;
with Stepper_Motor_Controller_Parameters;
with Parameter;
with Interfaces; use Interfaces;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Stepper_Motor_Controller_Tests.Implementation is

   subtype Tester_Access is Component.Stepper_Motor_Controller.Implementation.Tester.Instance_Access;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Component Init is called manually in each test body (after staging parameters).

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
   -- Parameter staging helpers:
   -------------------------------------------------------------------------

   -- Stage a single parameter, asserting the stage succeeded.
   procedure Stage (T : in Tester_Access; Par : in Parameter.T) is
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
   end Stage;

   -- Commit the staged parameters via the Update operation, asserting it succeeded.
   procedure Commit (T : in Tester_Access) is
   begin
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Commit;

   -- Stage and commit a full algorithm configuration. The nominal defaults give 1 deg/step, a
   -- full-circle travel range, no settling, and a minimum step command of 1; each test passes only
   -- the parameters it varies. Every parameter the algorithm reads is staged explicitly because the
   -- bare-board runtime does not apply the YAML parameter defaults in a unit test (in flight a
   -- Parameter_Manager loads the table before the first tick).
   procedure Configure
      (T : in Tester_Access;
       Reference : in Short_Float;
       Step_Angle : in Short_Float := 0.0174532925;          -- 1 deg/step
       Motor_Min : in Short_Float := 0.0;
       Motor_Max : in Short_Float := 6.2831853071795862;     -- 2*pi (full circle)
       Settle : in Interfaces.Unsigned_32 := 0;
       Enable_Hold : in Interfaces.Unsigned_32 := 0;
       Min_Step : in Interfaces.Unsigned_32 := 1)
   is
      Params : Stepper_Motor_Controller_Parameters.Instance;
   begin
      Stage (T, Params.Step_Angle ((Value => Step_Angle)));
      Stage (T, Params.Motor_Min_Angle ((Value => Motor_Min)));
      Stage (T, Params.Motor_Max_Angle ((Value => Motor_Max)));
      Stage (T, Params.Settle_Count_Max ((Value => Settle)));
      Stage (T, Params.Enable_Hold_Count ((Value => Enable_Hold)));
      Stage (T, Params.Min_Step_Command ((Value => Min_Step)));
      Stage (T, Params.Reference_Angle ((Value => Reference)));
      Commit (T);
   end Configure;

   -- Stage and commit a new reference angle, keeping the rest of the active configuration.
   procedure Set_Reference (T : in Tester_Access; Reference : in Short_Float) is
      Params : Stepper_Motor_Controller_Parameters.Instance;
   begin
      Stage (T, Params.Reference_Angle ((Value => Reference)));
      Commit (T);
   end Set_Reference;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Across step angles and initial positions, a reference angle commands a step of
   -- the shortest-path magnitude and direction (clockwise for an increasing
   -- position, counterclockwise for a decreasing one).
   overriding procedure Test_Move_Command (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;

      type Test_Vector is record
         Step_Angle : Short_Float;            -- [rad/step]
         Init_Pos : Interfaces.Integer_32;    -- [steps]
         Reference : Short_Float;             -- [rad]
         Expected : Stepper_Controller_Step.T;
      end record;

      -- Each case starts from rest at Init_Pos and commands the shortest-path move to Reference.
      -- Expected step counts are the wrapped delta (reference steps minus initial position).
      Cases : constant array (1 .. 9) of Test_Vector := [
         (0.0174532925, 0, 0.174532925, (Command => Command_Type.Step_Cw, Num_Steps => 10)),     -- 1.0 deg/step, +10 deg
         (0.0174532925, 0, -0.523598776, (Command => Command_Type.Step_Ccw, Num_Steps => 30)),   -- negative reference
         (0.0174532925, -45, 0.174532925, (Command => Command_Type.Step_Cw, Num_Steps => 55)),   -- negative start
         (0.0174532925, 90, 0.174532925, (Command => Command_Type.Step_Ccw, Num_Steps => 80)),   -- start past reference
         (0.031415927, 0, 0.174532925, (Command => Command_Type.Step_Cw, Num_Steps => 6)),       -- 1.8 deg/step
         (0.015707963, 0, 0.174532925, (Command => Command_Type.Step_Cw, Num_Steps => 11)),      -- 0.9 deg/step
         (0.0174532925, -162, 2.827433388, (Command => Command_Type.Step_Ccw, Num_Steps => 36)), -- shortest path wraps
         (0.0174532925, 170, -2.967059728, (Command => Command_Type.Step_Cw, Num_Steps => 20)),  -- shortest path forward wrap
         (0.0174532925, 1, 6.265732015, (Command => Command_Type.Step_Ccw, Num_Steps => 2))      -- shortest path backward wrap
      ];
   begin
      for I in Cases'Range loop
         -- Reset the algorithm to a fresh IDLE state for each independent move:
         if I > Cases'First then
            T.Component_Instance.Destroy;
         end if;
         T.Component_Instance.Init;

         Configure (T, Reference => Cases (I).Reference, Step_Angle => Cases (I).Step_Angle);
         T.Motor_State := (Current_Position => Cases (I).Init_Pos, Is_Moving => Motion_Status.Stationary);
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, I);
         Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (I), Cases (I).Expected);
      end loop;
   end Test_Move_Command;

   -- A reference within the minimum step command of the current position produces no
   -- motor command.
   overriding procedure Test_No_Command (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      T.Component_Instance.Init;
      -- A 3-step delta (3 deg at 1 deg/step) is below the minimum command of 5 steps:
      Configure (T, Reference => 0.0523598776, Min_Step => 5);
      T.Motor_State := (Current_Position => 0, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      -- The algorithm produces no command, so the wrapper sends nothing:
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);
   end Test_No_Command;

   -- A reference angle outside the configured motor travel range produces no motor command.
   overriding procedure Test_Out_Of_Range (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      T.Component_Instance.Init;
      -- A partial travel range of [45, 90] deg; a reference at -10 deg is below it:
      Configure (T, Reference => -0.174532925, Motor_Min => 0.785398163, Motor_Max => 1.570796327);
      T.Motor_State := (Current_Position => 60, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);

      -- A reference at 200 deg is above the range and likewise rejected:
      Set_Reference (T, 3.490658504);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);
   end Test_Out_Of_Range;

   -- Changing the reference mid-move commands a halt, then re-plans a move from the
   -- final position once the motor settles.
   overriding procedure Test_Interrupt (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      T.Component_Instance.Init;
      -- Start a 20-step (20 deg) clockwise move from rest, with a 2-tick settling period:
      Configure (T, Reference => 0.34906585, Settle => 2);
      T.Motor_State := (Current_Position => 0, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (
         T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Command_Type.Step_Cw, Num_Steps => 20));

      -- Retarget to 10 deg while the motor is still moving: the algorithm commands a stop:
      Set_Reference (T, 0.174532925);
      T.Motor_State := (Current_Position => 5, Is_Moving => Motion_Status.Moving);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Stepper_Controller_Step_Assert.Eq (
         T.Stepper_Controller_Step_T_Recv_Sync_History.Get (2),
         (Command => Command_Type.Halt, Num_Steps => 0));

      -- The motor finishes its current step at 20 and stops; the controller passes through
      -- STOPPING and the 2-tick SETTLING period without commanding anything:
      for J in 1 .. 4 loop
         T.Motor_State := (Current_Position => 20, Is_Moving => Motion_Status.Stationary);
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      end loop;

      -- Settling complete: the controller re-plans from the final position 20 to the new
      -- reference 10, a 10-step counterclockwise move:
      T.Motor_State := (Current_Position => 20, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 3);
      Stepper_Controller_Step_Assert.Eq (
         T.Stepper_Controller_Step_T_Recv_Sync_History.Get (3),
         (Command => Command_Type.Step_Ccw, Num_Steps => 10));
   end Test_Interrupt;

   -- The applied settle count is the total desired settle count reduced by the enable
   -- hold count, saturating at zero.
   overriding procedure Test_Settle_Enable_Hold (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;

      type Test_Vector is record
         Settle : Interfaces.Unsigned_32;       -- [ticks] total desired settle count
         Enable_Hold : Interfaces.Unsigned_32;  -- [ticks] configured enable hold count
         Quiet_Ticks : Natural;                 -- expected command-free ticks after the motor stops
      end record;

      -- After the motor stops, the controller is quiet for one MOVING -> SETTLING transition
      -- tick, the applied settle count of ticks, and one SETTLING -> IDLE transition tick, so
      -- the expected quiet ticks are (Settle - Enable_Hold) + 2, with the subtraction
      -- saturating at zero:
      Cases : constant array (1 .. 3) of Test_Vector := [
         (Settle => 5, Enable_Hold => 0, Quiet_Ticks => 7),   -- hold disabled: full settle count
         (Settle => 5, Enable_Hold => 3, Quiet_Ticks => 4),   -- hold shortens the settling wait
         (Settle => 2, Enable_Hold => 5, Quiet_Ticks => 2)    -- hold covers the settle: saturates at 0
      ];

      Command_Count : Natural := 0;
   begin
      for C of Cases loop
         -- Reset the algorithm to a fresh IDLE state for each independent case:
         if Command_Count > 0 then
            T.Component_Instance.Destroy;
         end if;
         T.Component_Instance.Init;

         -- Start a 20-step (20 deg) clockwise move from rest:
         Configure (T, Reference => 0.34906585, Settle => C.Settle, Enable_Hold => C.Enable_Hold);
         T.Motor_State := (Current_Position => 0, Is_Moving => Motion_Status.Stationary);
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         Command_Count := @ + 1;
         Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, Command_Count);
         Stepper_Controller_Step_Assert.Eq (
            T.Stepper_Controller_Step_T_Recv_Sync_History.Get (Command_Count),
            (Command => Command_Type.Step_Cw, Num_Steps => 20));

         -- The motor stops short at 10, leaving a residual delta to re-command after settling.
         -- The controller stays quiet through the transition and settling ticks:
         T.Motor_State := (Current_Position => 10, Is_Moving => Motion_Status.Stationary);
         for J in 1 .. C.Quiet_Ticks loop
            T.Tick_T_Send ((Time => T.System_Time, Count => 0));
            Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, Command_Count);
         end loop;

         -- Settling complete: the next tick re-plans the remaining 10-step move from IDLE:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         Command_Count := @ + 1;
         Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, Command_Count);
         Stepper_Controller_Step_Assert.Eq (
            T.Stepper_Controller_Step_T_Recv_Sync_History.Get (Command_Count),
            (Command => Command_Type.Step_Cw, Num_Steps => 10));
      end loop;
   end Test_Settle_Enable_Hold;

   -- A move out and back from the fed-back absolute position produces equal and
   -- opposite step counts.
   overriding procedure Test_Position_Tracking (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- Move out: from position 0 to 20 deg is a 20-step clockwise move:
      T.Component_Instance.Init;
      Configure (T, Reference => 0.34906585);
      T.Motor_State := (Current_Position => 0, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (
         T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Command_Type.Step_Cw, Num_Steps => 20));

      -- Move back: with the motor reporting absolute position 20, returning to 0 deg is the
      -- equal and opposite 20-step counterclockwise move -- only correct if the wrapper feeds
      -- the absolute position to the algorithm:
      T.Component_Instance.Destroy;
      T.Component_Instance.Init;
      Configure (T, Reference => 0.0);
      T.Motor_State := (Current_Position => 20, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Stepper_Controller_Step_Assert.Eq (
         T.Stepper_Controller_Step_T_Recv_Sync_History.Get (2),
         (Command => Command_Type.Step_Ccw, Num_Steps => 20));
   end Test_Position_Tracking;

   -- A move whose step delta exceeds the motor-command field fails an assertion (an algorithm
   -- defect) rather than being sent or truncated. Exercised at the exact field boundary on a
   -- partial range, where the unwrapped delta against a fed-back position far from the in-range
   -- reference can overflow the field.
   overriding procedure Test_Over_Range_Rejected (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- A delta of exactly the Num_Steps field maximum (Unsigned_16'Last = 65535; reference at
      -- position 0, feedback at -65535) is still representable and is sent:
      T.Component_Instance.Init;
      Configure (T, Reference => 0.0, Motor_Min => -1.0, Motor_Max => 1.0);
      T.Motor_State := (Current_Position => -65535, Is_Moving => Motion_Status.Stationary);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (
         T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Command_Type.Step_Cw, Num_Steps => 65535));

      -- One step past the field (feedback at -65536) overflows it: the tick fails an
      -- assertion and nothing further is sent:
      T.Component_Instance.Destroy;
      T.Component_Instance.Init;
      Configure (T, Reference => 0.0, Motor_Min => -1.0, Motor_Max => 1.0);
      T.Motor_State := (Current_Position => -65536, Is_Moving => Motion_Status.Stationary);
      declare
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         Assert (False, "An over-range step delta should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
   end Test_Over_Range_Rejected;

   -- An unavailable motor state data dependency fails an assertion. The motor interface
   -- publishes an initial motor state at Set_Up, so this can only indicate a wiring defect.
   overriding procedure Test_Motor_State_Unavailable (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
      use Data_Product_Enums;
   begin
      T.Component_Instance.Init;
      Configure (T, Reference => 0.174532925);

      -- Force the motor-state fetch to report the data product as not yet available; the tick
      -- fails an assertion and no step or halt is commanded:
      T.Data_Dependency_Return_Status_Override := Fetch_Status.Not_Available;
      T.Motor_State := (Current_Position => 0, Is_Moving => Motion_Status.Stationary);
      declare
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         Assert (False, "An unavailable motor state should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);
   end Test_Motor_State_Unavailable;

end Stepper_Motor_Controller_Tests.Implementation;
