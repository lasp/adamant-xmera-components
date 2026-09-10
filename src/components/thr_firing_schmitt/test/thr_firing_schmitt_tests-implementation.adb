--------------------------------------------------------------------------------
-- Thr_Firing_Schmitt Tests Body
--------------------------------------------------------------------------------

with Interfaces;
with Packed_F32x36;
with Basic_Assertions; use Basic_Assertions;
with Thr_On_Time_Cmd;
with Packed_F32x8.Assertion; use Packed_F32x8.Assertion;
with Thr_Firing_Schmitt_Parameters;
with Levels_On_Off;
with Packed_F32;
with Packed_Pulsing_Regime;
with Thr_Firing_Remainder_Enums;
with Parameter;
with Basic_Types;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Thr_Firing_Schmitt_Tests.Implementation is

   -- The baseline configuration shared by the behavioural tests. Two thrusters of
   -- unit maximum thrust keep the on-time arithmetic transparent: with a control
   -- period of 0.5 s an on-time is simply the requested force halved. The
   -- hysteresis band runs from a duty cycle of 0.25 to 0.75 of the 0.02 s minimum
   -- fire time.
   Thr_Count : constant Interfaces.Unsigned_32 := 2;
   Max_Thrust : constant Packed_F32x36.U := [0 => 1.0, 1 => 1.0, others => 0.0];
   Levels : constant Levels_On_Off.T := (Level_On => 0.75, Level_Off => 0.25);
   Min_Fire_Time : constant Packed_F32.T := (Value => 0.02);
   Control_Period_Param : constant Packed_F32.T := (Value => 0.5);
   Saturation_Factor : constant Packed_F32.T := (Value => 1.0);
   On_Pulsing_Regime : constant Packed_Pulsing_Regime.T :=
      (Value => Thr_Firing_Remainder_Enums.Pulsing_Regime.On_Pulsing);
   Off_Pulsing_Regime : constant Packed_Pulsing_Regime.T :=
      (Value => Thr_Firing_Remainder_Enums.Pulsing_Regime.Off_Pulsing);

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Component Init will be called manually in test body
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
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      -- Expected on-time computation for ON_PULSING:
      -- thruster 0: force=0.5, maxThrust=1.0, period=0.5 => onTime = (0.5/1.0)*0.5 = 0.25
      -- thruster 1: force=0.3, maxThrust=1.0, period=0.5 => onTime = (0.3/1.0)*0.5 = 0.15
      -- Both are above thrMinFireTime and below controlPeriod, so no Schmitt clamping.
      Expected_On_Time_On_Pulsing : constant Packed_F32x8.T := [0.25, 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      -- Expected on-time computation for OFF_PULSING:
      -- thruster 0: force=-0.5 + maxThrust(1.0) = 0.5, onTime = (0.5/1.0)*0.5 = 0.25
      -- thruster 1: force=-0.3 + maxThrust(1.0) = 0.7, onTime = (0.7/1.0)*0.5 = 0.35
      Expected_On_Time_Off_Pulsing : constant Packed_F32x8.T := [0.25, 0.35, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      Output : Thr_On_Time_Cmd.T;
   begin
      -----------------------------------------------------------------------
      -- Test Case 1: ON_PULSING with positive force commands
      -----------------------------------------------------------------------

      -- Initialize component
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      -- Configure thrusters
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => Thr_Count, Max_Thrust => Max_Thrust);

      -- Stage and apply parameters
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set force command data dependency: positive forces for ON_PULSING
      T.Thruster_Force_Cmd := (Thr_Force => [0.5, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

      -- Send tick to trigger algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify output was produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.On_Time_Cmd_History.Get_Count, 1);

      -- Check output matches expected values
      Output := T.On_Time_Cmd_History.Get (1);
      Packed_F32x8_Assert.Eq (
         Output.On_Time_Request,
         Expected_On_Time_On_Pulsing,
         Epsilon => 0.0001
      );

      -- All on-times must be non-negative
      for I in Output.On_Time_Request'Range loop
         Short_Float_Assert.Ge (Output.On_Time_Request (I), 0.0);
      end loop;

      -- Clean up before next test
      T.Component_Instance.Destroy;

      -----------------------------------------------------------------------
      -- Test Case 2: OFF_PULSING with negative force commands
      -----------------------------------------------------------------------

      -- Initialize fresh algorithm instance
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      -- Configure thrusters
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => Thr_Count, Max_Thrust => Max_Thrust);

      -- Stage and apply parameters with OFF_PULSING regime
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (Off_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set force command data dependency: negative forces for OFF_PULSING
      T.Thruster_Force_Cmd := (Thr_Force => [-0.5, -0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);

      -- Send tick to trigger algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify output was produced (history accumulates)
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.On_Time_Cmd_History.Get_Count, 2);

      -- Check output matches expected values
      Output := T.On_Time_Cmd_History.Get (2);
      Packed_F32x8_Assert.Eq (
         Output.On_Time_Request,
         Expected_On_Time_Off_Pulsing,
         Epsilon => 0.0001
      );

      -- All on-times must be non-negative
      for I in Output.On_Time_Request'Range loop
         Short_Float_Assert.Ge (Output.On_Time_Request (I), 0.0);
      end loop;

      -- Tear_Down_Test will handle the final Destroy

   end Test;

   -- Verify the reset connector clears the Schmitt-trigger hysteresis state.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      -- Single thruster with maxThrust = 1.0
      Single_Thruster : constant Packed_F32x36.U := [0 => 1.0, others => 0.0];

      Output : Thr_On_Time_Cmd.T;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => 1, Max_Thrust => Single_Thruster);

      -- Stage and apply parameters
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Tick 1: force=0.5 => onTime=0.25 (above min fire time), latches the
      -- thruster's previous state to ON.
      T.Thruster_Force_Cmd := (Thr_Force => [0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Tick 2: force=0.02 => onTime=0.01, level=0.5 (between levelOff and
      -- levelOn). Because the previous state is latched ON, the Schmitt trigger
      -- holds the thruster ON at the minimum fire time (0.02).
      T.Thruster_Force_Cmd := (Thr_Force => [0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (2);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.02, Epsilon => 0.0001);

      -- Reset the algorithm's hysteresis state via the reset connector.
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Tick 3: identical intermediate force=0.02. With the previous state now
      -- cleared to OFF by the reset, the Schmitt trigger drops the thruster to
      -- zero on-time, proving the reset took effect.
      T.Thruster_Force_Cmd := (Thr_Force => [0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (3);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.0, Epsilon => 0.0001);

      -- Tear_Down_Test will handle the final Destroy
   end Test_Reset;

   -- Below the minimum fire time the duty cycle decides. A level at or above
   -- Level_On latches ON and floors the on-time at the minimum fire time; a level
   -- at or below Level_Off latches OFF at zero. Both latches override whatever the
   -- previous state was, which is what separates them from the hysteresis band
   -- exercised by Test_Reset.
   overriding procedure Test_Min_Fire_Time_Floor (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      Single_Thruster : constant Packed_F32x36.U := [0 => 1.0, others => 0.0];

      Output : Thr_On_Time_Cmd.T;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => 1, Max_Thrust => Single_Thruster);

      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Tick 1: force=0.032 => onTime=0.016, below the 0.02 minimum fire time.
      -- level = 0.016/0.02 = 0.8 >= Level_On (0.75), so the thruster latches ON
      -- and fires for exactly the minimum fire time.
      T.Thruster_Force_Cmd := (Thr_Force => [0.032, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (1);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.02, Epsilon => 0.0001);

      -- Tick 2: force=0.008 => onTime=0.004, level = 0.2 <= Level_Off (0.25).
      -- The OFF latch wins over the ON state left by tick 1.
      T.Thruster_Force_Cmd := (Thr_Force => [0.008, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (2);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.0, Epsilon => 0.0001);

      -- Tick 3: back to level 0.8. The ON latch wins over the OFF state left by
      -- tick 2, so neither latch depends on history.
      T.Thruster_Force_Cmd := (Thr_Force => [0.032, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (3);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.02, Epsilon => 0.0001);
   end Test_Min_Fire_Time_Floor;

   -- An on-time request that reaches the control period is deliberately
   -- oversaturated to On_Time_Saturation_Factor times the control period, so the
   -- thruster is still firing when the next control period begins.
   overriding procedure Test_On_Time_Saturation (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      Single_Thruster : constant Packed_F32x36.U := [0 => 1.0, others => 0.0];
      Oversaturating_Factor : constant Packed_F32.T := (Value => 1.5);

      -- onTime saturates to 1.5 * 0.5 = 0.75, beyond the control period itself.
      Expected_Saturated : constant Short_Float := 0.75;

      Output : Thr_On_Time_Cmd.T;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => 1, Max_Thrust => Single_Thruster);

      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Oversaturating_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Tick 1: force equals the maximum thrust, so onTime = 0.5 exactly meets the
      -- control period. The comparison is inclusive, so this already saturates.
      T.Thruster_Force_Cmd := (Thr_Force => [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (1);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), Expected_Saturated, Epsilon => 0.0001);

      -- Tick 2: a force well beyond the maximum thrust cannot push the on-time any
      -- higher -- the saturated value is a ceiling, not a scaling.
      T.Thruster_Force_Cmd := (Thr_Force => [2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (2);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), Expected_Saturated, Epsilon => 0.0001);
   end Test_On_Time_Saturation;

   -- In off-pulsing the commanded force is a negative delta about a thruster that
   -- is otherwise firing continuously, so the algorithm adds the maximum thrust
   -- back before converting to an on-time, then refuses to go below zero.
   overriding procedure Test_Off_Pulsing_Offset (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      Single_Thruster : constant Packed_F32x36.U := [0 => 1.0, others => 0.0];

      Output : Thr_On_Time_Cmd.T;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => 1, Max_Thrust => Single_Thruster);

      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (Off_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Tick 1: a zero delta means "no reduction", so the effective force is the
      -- full maximum thrust and the thruster fires for the whole control period
      -- (saturated at a factor of 1.0).
      T.Thruster_Force_Cmd := (Thr_Force => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (1);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.5, Epsilon => 0.0001);

      -- Tick 2: a delta more negative than the maximum thrust would make the
      -- effective force negative (-2.0 + 1.0 = -1.0). It is clamped to zero rather
      -- than producing a negative on-time.
      T.Thruster_Force_Cmd := (Thr_Force => [-2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (2);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.0, Epsilon => 0.0001);
   end Test_Off_Pulsing_Offset;

   -- The Schmitt trigger keeps one ON/OFF state per thruster. Driving two
   -- thrusters into opposite states and then handing them an identical force in
   -- the hysteresis band must produce different on-times; a shared state would
   -- collapse them to the same value.
   overriding procedure Test_Thruster_Independence (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      Output : Thr_On_Time_Cmd.T;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => Thr_Count, Max_Thrust => Max_Thrust);

      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Tick 1: thruster 0 is driven well above the minimum fire time and latches
      -- ON; thruster 1 is commanded zero and latches OFF.
      T.Thruster_Force_Cmd := (Thr_Force => [0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (1);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.25, Epsilon => 0.0001);
      Short_Float_Assert.Eq (Output.On_Time_Request (1), 0.0, Epsilon => 0.0001);

      -- Tick 2: both thrusters get the same force, landing at level 0.5 -- inside
      -- the hysteresis band, where the previous state decides. Thruster 0 holds at
      -- the minimum fire time, thruster 1 stays off.
      T.Thruster_Force_Cmd := (Thr_Force => [0.02, 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Output := T.On_Time_Cmd_History.Get (2);
      Short_Float_Assert.Eq (Output.On_Time_Request (0), 0.02, Epsilon => 0.0001);
      Short_Float_Assert.Eq (Output.On_Time_Request (1), 0.0, Epsilon => 0.0001);
   end Test_Thruster_Independence;

   -- The configured thruster count bounds the algorithm's loop. Slots past it keep
   -- their zero maximum thrust, which would produce Inf or NaN if the on-time
   -- division ever reached them, so an all-zero tail is the evidence that it does
   -- not.
   overriding procedure Test_Num_Thrusters_Bound (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      -- One active thruster, but the force command drives all eight.
      Single_Thruster : constant Packed_F32x36.U := [0 => 1.0, others => 0.0];
      Expected : constant Packed_F32x8.T := [0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

      Output : Thr_On_Time_Cmd.T;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
      T.Component_Instance.Configure_Thrusters (Num_Thrusters => 1, Max_Thrust => Single_Thruster);

      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      T.Thruster_Force_Cmd := (Thr_Force => [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      Output := T.On_Time_Cmd_History.Get (1);
      Packed_F32x8_Assert.Eq (Output.On_Time_Request, Expected, Epsilon => 0.0001);
   end Test_Num_Thrusters_Bound;

   -- A byte outside the pulsing regime enumeration must be rejected at
   -- staging by E8 type validation, before it can reach the component's
   -- enum conversion (which would raise Constraint_Error on the invalid
   -- value) or the C algorithm. The out-of-range raw byte is injected by
   -- overwriting the parameter buffer, mimicking a ground upload.
   overriding procedure Test_Pulsing_Regime_Validation (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;
      Param : Parameter.T := Params.Thrust_Pulsing_Regime (On_Pulsing_Regime);
   begin
      -- Initialize component
      T.Component_Instance.Init;

      -- A raw byte one past the last enumeration value must be rejected:
      Param.Buffer (Param.Buffer'First) := Basic_Types.Byte (Natural (
         Thr_Firing_Remainder_Enums.Pulsing_Regime.E'Pos (
            Thr_Firing_Remainder_Enums.Pulsing_Regime.E'Last)) + 1);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Validation_Error);

      -- The last valid enumeration value stages successfully:
      Param.Buffer (Param.Buffer'First) := Basic_Types.Byte (
         Thr_Firing_Remainder_Enums.Pulsing_Regime.E'Pos (
            Thr_Firing_Remainder_Enums.Pulsing_Regime.E'Last));
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Param), Success);
   end Test_Pulsing_Regime_Validation;

   -- A staged parameter set that the C++ ThrFiringSchmittConfig would reject must
   -- be refused by Validate_Parameters, so it never reaches the throwing Set_Config
   -- across the FFI boundary. Each field is perturbed on its own and then restored,
   -- proving the rejection is attributable to that field. The values here pass the
   -- staging type/range checks and are caught only by the algorithm's validators.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Schmitt_Parameters.Instance;

      -- Stage the full valid set. Every case below starts from this baseline so a
      -- rejection can only come from the single field that was perturbed.
      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels (Levels)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Min_Fire_Time)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Control_Period_Param)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Saturation_Factor)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (On_Pulsing_Regime)), Success);
      end Stage_Valid_Set;
   begin
      T.Component_Instance.Init;

      -- The baseline set is accepted:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A zero Level_On is rejected (must be finite and in (0, 1]):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels ((Level_On => 0.0, Level_Off => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A Level_On above one is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels ((Level_On => 1.1, Level_Off => 0.25))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A Level_Off of one is rejected (must be finite and in [0, 1)):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels ((Level_On => 1.0, Level_Off => 1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Thresholds that cross -- Level_On below Level_Off -- are rejected, because
      -- they would invert the hysteresis band:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Levels ((Level_On => 0.1, Level_Off => 0.2))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero minimum fire time is rejected (must be finite and strictly > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero control period is rejected (must be finite and strictly > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An on-time saturation factor below one is rejected (must be finite and >= 1):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor ((Value => 0.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above
      -- were caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Thr_Firing_Schmitt_Tests.Implementation;
