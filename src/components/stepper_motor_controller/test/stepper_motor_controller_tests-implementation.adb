--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with AUnit.Assertions; use AUnit.Assertions;
with Stepper_Controller_Step.Assertion; use Stepper_Controller_Step.Assertion;
with Packed_I32.Assertion; use Packed_I32.Assertion;
with Stepper_Motor_Controller_Parameters;
with Stepper_Enums;
with Parameter;
with Parameter_Enums.Assertion;
with Interfaces; use Interfaces;
with Ada.Assertions;
with Ada.Real_Time;
with Data_Product_Enums;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Stepper_Motor_Controller_Tests.Implementation is

   -- Handy rename for the tester access type:
   subtype Tester_Access is Component.Stepper_Motor_Controller.Implementation.Tester.Instance_Access;

   -- One degree in radians and the full circle as named numbers, so the exact
   -- universal-real values convert to Short_Float once at each use site,
   -- matching the single-precision arithmetic inside the C++ algorithm:
   Deg : constant := 0.01745_32925_19943_29577;
   Two_Pi : constant := 6.28318_53071_79586_48;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage the full parameter set and apply it to the algorithm:
   procedure Stage_Config
      (T : in Tester_Access;
       Step_Angle : in Short_Float;
       Motor_Min_Angle : in Short_Float;
       Motor_Max_Angle : in Short_Float;
       Settle_Count_Max : in Unsigned_32;
       Min_Step_Command : in Unsigned_32;
       Reference_Angle : in Short_Float)
   is
      Params : Stepper_Motor_Controller_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Step_Angle ((Value => Step_Angle))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_Min_Angle ((Value => Motor_Min_Angle))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Motor_Max_Angle ((Value => Motor_Max_Angle))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Settle_Count_Max ((Value => Settle_Count_Max))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Min_Step_Command ((Value => Min_Step_Command))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Reference_Angle ((Value => Reference_Angle))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Stage_Config;

   -- Stage a new reference angle and apply it:
   procedure Stage_Reference
      (T : in Tester_Access;
       Reference_Angle : in Short_Float)
   is
      Params : Stepper_Motor_Controller_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Reference_Angle ((Value => Reference_Angle))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Stage_Reference;

   -- Send a tick to run one cycle of the controller:
   procedure Send_Tick (T : in Tester_Access) is
   begin
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Send_Tick;

   -- Re-initialize the component with a fresh algorithm instance so a new
   -- scenario starts from the reset controller state:
   procedure Restart_Component (T : in Tester_Access) is
   begin
      T.Component_Instance.Destroy;
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
   end Restart_Component;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Call component init here. The parameter defaults are valid for the C
      -- algorithm setters, so Init applies them safely; each test then stages
      -- its own configuration through the parameter interface.
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

   -- Verify nominal move commands with shortest-path wrapping through the full Ada
   -- to C++ path.
   overriding procedure Test_Nominal_Move (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- Case 1: forward move. Motor at step 0, reference at 10 degrees with a
      -- 1 degree step angle commands 10 steps clockwise.
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 0.0,
         Motor_Max_Angle => Two_Pi,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => 10.0 * Deg);
      T.Motor_State := (Current_Position => 0, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Stepper_Enums.Command_Type.Step_Cw, Num_Steps => 10));

      -- Case 2: shortest path goes backward across zero. Motor at step 1,
      -- reference at 359 degrees is 2 steps counter-clockwise, not 358 steps
      -- clockwise.
      Restart_Component (T);
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 0.0,
         Motor_Max_Angle => Two_Pi,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => 359.0 * Deg);
      T.Motor_State := (Current_Position => 1, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (2),
         (Command => Stepper_Enums.Command_Type.Step_Ccw, Num_Steps => 2));

      -- Case 3: shortest path goes forward across the half-circle seam, and a
      -- full-circle range accepts a reference outside [0, 2*pi]. Motor at step
      -- 170, reference at -170 degrees wraps to 20 steps clockwise.
      Restart_Component (T);
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 0.0,
         Motor_Max_Angle => Two_Pi,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => -170.0 * Deg);
      T.Motor_State := (Current_Position => 170, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 3);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (3),
         (Command => Stepper_Enums.Command_Type.Step_Cw, Num_Steps => 20));

      -- No saturation events were produced by any nominal move:
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 0);
   end Test_Nominal_Move;

   -- Verify no step command is issued while the step delta is below the minimum step
   -- command threshold.
   overriding procedure Test_Below_Min_Step_Command (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- A 3 step delta is below the minimum step command of 5, so the
      -- controller stays quiescent:
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 0.0,
         Motor_Max_Angle => Two_Pi,
         Settle_Count_Max => 10,
         Min_Step_Command => 5,
         Reference_Angle => 3.0 * Deg);
      T.Motor_State := (Current_Position => 0, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);

      -- A 5 step delta meets the threshold exactly and commands a move:
      Stage_Reference (T, 5.0 * Deg);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Stepper_Enums.Command_Type.Step_Cw, Num_Steps => 5));
   end Test_Below_Min_Step_Command;

   -- Verify a reference change mid-move produces a halt command and the controller
   -- re-plans from the settled position after the settle duration.
   overriding procedure Test_Interrupt_And_Replan (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- Move toward a 20 degree reference from step 0:
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 0.0,
         Motor_Max_Angle => Two_Pi,
         Settle_Count_Max => 2,
         Min_Step_Command => 1,
         Reference_Angle => 20.0 * Deg);
      T.Motor_State := (Current_Position => 0, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Stepper_Enums.Command_Type.Step_Cw, Num_Steps => 20));

      -- Motor under way; the unchanged reference produces no new command:
      T.Motor_State := (Current_Position => 5, Is_Moving => Stepper_Enums.Motion_Status.Moving);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);

      -- Retarget to 10 degrees mid-move: the controller halts the motor:
      Stage_Reference (T, 10.0 * Deg);
      T.Motor_State := (Current_Position => 8, Is_Moving => Stepper_Enums.Motion_Status.Moving);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (2),
         (Command => Stepper_Enums.Command_Type.Halt, Num_Steps => 0));

      -- The motor cannot stop mid-step; it keeps moving one more cycle:
      T.Motor_State := (Current_Position => 20, Is_Moving => Stepper_Enums.Motion_Status.Moving);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);

      -- Motor reports stationary: the controller enters settling. With a
      -- settle count of 2 (and no enable hold) the controller stays quiescent
      -- for the settling entry cycle plus three counting cycles:
      T.Motor_State := (Current_Position => 20, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);

      -- Back at idle, the controller re-plans from the settled position: the
      -- motor overshot to step 20, so reaching the 10 degree reference takes
      -- 10 steps counter-clockwise:
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 3);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (3),
         (Command => Stepper_Enums.Command_Type.Step_Ccw, Num_Steps => 10));

      -- No saturation events during the whole exchange:
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 0);
   end Test_Interrupt_And_Replan;

   -- Verify references outside a partial motor angle range produce no motion and an
   -- in-range reference uses the linear path.
   overriding procedure Test_Out_Of_Range_Reference (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- Partial range of [45, 90] degrees with the motor parked at 60 degrees.
      -- A reference above the range is ignored:
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 45.0 * Deg,
         Motor_Max_Angle => 90.0 * Deg,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => 200.0 * Deg);
      T.Motor_State := (Current_Position => 60, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);

      -- A reference below the range is also ignored:
      Stage_Reference (T, -10.0 * Deg);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 0);

      -- An in-range reference at 50 degrees moves linearly from 60 to 50, 10
      -- steps counter-clockwise (a partial range never wraps):
      Stage_Reference (T, 50.0 * Deg);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Stepper_Enums.Command_Type.Step_Ccw, Num_Steps => 10));
   end Test_Out_Of_Range_Reference;

   -- Verify step deltas exceeding the Num_Steps field range are saturated and
   -- reported via event.
   overriding procedure Test_Step_Command_Saturation (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- A partial range keeps the delta linear, so a far-away current position
      -- produces a step delta beyond the Num_Steps field range. From step
      -- -100000 to the 60 degree reference is +100060 steps: the command
      -- saturates at 65535 clockwise and the raw delta is reported:
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 45.0 * Deg,
         Motor_Max_Angle => 90.0 * Deg,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => 60.0 * Deg);
      T.Motor_State := (Current_Position => -100_000, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Stepper_Enums.Command_Type.Step_Cw, Num_Steps => 65_535));
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Step_Command_Saturated_History.Get_Count, 1);
      Packed_I32_Assert.Eq (T.Step_Command_Saturated_History.Get (1), (Value => 100_060));

      -- The same saturation applies counter-clockwise. From step +100000 to
      -- the 60 degree reference is -99940 steps:
      Restart_Component (T);
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 45.0 * Deg,
         Motor_Max_Angle => 90.0 * Deg,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => 60.0 * Deg);
      T.Motor_State := (Current_Position => 100_000, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      Send_Tick (T);
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 2);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (2),
         (Command => Stepper_Enums.Command_Type.Step_Ccw, Num_Steps => 65_535));
      Natural_Assert.Eq (T.Event_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Step_Command_Saturated_History.Get_Count, 2);
      Packed_I32_Assert.Eq (T.Step_Command_Saturated_History.Get (2), (Value => -99_940));
   end Test_Step_Command_Saturation;

   -- Verify a stale motor state is accepted and used, while an unavailable motor
   -- state fails an assertion.
   overriding procedure Test_Motor_State_Staleness (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
   begin
      -- Map a finite stale limit so the served timestamp can age out; the
      -- tester serves the data dependency with id 0 and timestamp (0, 0) by
      -- default:
      T.Component_Instance.Map_Data_Dependencies (
         Motor_State_Id => 0,
         Motor_State_Stale_Limit => Ada.Real_Time.Milliseconds (500));

      -- A stale motor state (timestamp far older than the tick's stale
      -- reference) is accepted and the controller still commands the move:
      Stage_Config (T,
         Step_Angle => Deg,
         Motor_Min_Angle => 0.0,
         Motor_Max_Angle => Two_Pi,
         Settle_Count_Max => 10,
         Min_Step_Command => 1,
         Reference_Angle => 10.0 * Deg);
      T.Motor_State := (Current_Position => 0, Is_Moving => Stepper_Enums.Motion_Status.Stationary);
      T.Tick_T_Send ((Time => (100, 0), Count => 0));
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
      Stepper_Controller_Step_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get (1),
         (Command => Stepper_Enums.Command_Type.Step_Cw, Num_Steps => 10));

      -- An unavailable motor state indicates a wiring defect and fails the
      -- tick's assertion; no command is produced:
      T.Data_Dependency_Return_Status_Override := Data_Product_Enums.Fetch_Status.Not_Available;
      begin
         Send_Tick (T);
         Assert (False, "An unavailable motor state should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Stepper_Controller_Step_T_Recv_Sync_History.Get_Count, 1);
   end Test_Motor_State_Staleness;

   -- Verify malformed parameter staging requests are rejected by status.
   overriding procedure Test_Parameter_Staging_Errors (Self : in out Instance) is
      T : Tester_Access renames Self.Tester;
      Params : Stepper_Motor_Controller_Parameters.Instance;
      Param : Parameter.T;
   begin
      -- A parameter with a corrupted (zero) buffer length is rejected:
      Param := Params.Step_Angle ((Value => 0.03));
      Param.Header.Buffer_Length := 0;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Length_Error);

      -- A parameter with an unknown ID is rejected:
      Param := Params.Step_Angle ((Value => 0.03));
      Param.Header.Id := 1_001;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Id_Error);

      -- A well-formed parameter still stages successfully afterward:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Step_Angle ((Value => 0.03))), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Parameter_Staging_Errors;

end Stepper_Motor_Controller_Tests.Implementation;
