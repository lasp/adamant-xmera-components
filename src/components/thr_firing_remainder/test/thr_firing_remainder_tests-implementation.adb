--------------------------------------------------------------------------------
-- Thr_Firing_Remainder Tests Body
--------------------------------------------------------------------------------

with Interfaces;
with Packed_F32x36;
with Basic_Assertions; use Basic_Assertions;
with Thr_On_Time_Cmd;
with Thr_On_Time_Cmd.Assertion; use Thr_On_Time_Cmd.Assertion;
with Packed_F32x8.Assertion; use Packed_F32x8.Assertion;
with Thr_Firing_Remainder_Parameters;
with Packed_F32;
with Packed_Pulsing_Regime;
with Thr_Firing_Remainder_Enums;
with Parameter;
with Basic_Types;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Thr_Firing_Remainder_Tests.Implementation is

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
      T : Component.Thr_Firing_Remainder.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Remainder_Parameters.Instance;

      -- Thruster configuration: 2 thrusters with maxThrust = 1.0
      Thr_Count : constant Interfaces.Unsigned_32 := 2;
      Max_Thrust : constant Packed_F32x36.U := [0 => 1.0, 1 => 1.0, others => 0.0];

      -- Control parameters
      Min_Fire_Time : constant Packed_F32.T := (Value => 0.02);
      Control_Period_Param : constant Packed_F32.T := (Value => 0.5);
      Saturation_Factor : constant Packed_F32.T := (Value => 1.0);
      On_Pulsing_Regime : constant Packed_Pulsing_Regime.T := (Value => Thr_Firing_Remainder_Enums.Pulsing_Regime.On_Pulsing);
      Off_Pulsing_Regime : constant Packed_Pulsing_Regime.T := (Value => Thr_Firing_Remainder_Enums.Pulsing_Regime.Off_Pulsing);

      -- Expected on-time computation for ON_PULSING:
      -- thruster 0: force=0.5, maxThrust=1.0, period=0.5 => onTime = (0.5/1.0)*0.5 = 0.25
      -- thruster 1: force=0.3, maxThrust=1.0, period=0.5 => onTime = (0.3/1.0)*0.5 = 0.15
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

      -- The direct actuation connector must carry the same on-time command as
      -- the data product:
      Natural_Assert.Eq (T.Thr_On_Time_Cmd_T_Recv_Sync_History.Get_Count, 1);
      Thr_On_Time_Cmd_Assert.Eq (T.Thr_On_Time_Cmd_T_Recv_Sync_History.Get (1), T.On_Time_Cmd_History.Get (1));

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

      -- The direct actuation connector tracks the data product on every run:
      Natural_Assert.Eq (T.Thr_On_Time_Cmd_T_Recv_Sync_History.Get_Count, 2);
      Thr_On_Time_Cmd_Assert.Eq (T.Thr_On_Time_Cmd_T_Recv_Sync_History.Get (2), T.On_Time_Cmd_History.Get (2));

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

   -- A byte outside the pulsing regime enumeration must be rejected at
   -- staging by E8 type validation, before it can reach the component's
   -- enum case mapping (which would raise Constraint_Error on the invalid
   -- value) or the C algorithm. The out-of-range raw byte is injected by
   -- overwriting the parameter buffer, mimicking a ground upload.
   overriding procedure Test_Pulsing_Regime_Validation (Self : in out Instance) is
      T : Component.Thr_Firing_Remainder.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Remainder_Parameters.Instance;
      Param : Parameter.T := Params.Thrust_Pulsing_Regime (
         (Value => Thr_Firing_Remainder_Enums.Pulsing_Regime.On_Pulsing));
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

   -- A staged parameter set that the C++ ThrFiringRemainderConfig would reject must
   -- be refused by Validate_Parameters, so it never reaches the throwing Set_Config
   -- across the FFI boundary. Each field is perturbed on its own and then restored,
   -- proving the rejection is attributable to that field. The values here pass the
   -- staging type/range checks and are caught only by the algorithm's validators.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Thr_Firing_Remainder.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Remainder_Parameters.Instance;

      Valid_Min_Fire_Time : constant Packed_F32.T := (Value => 0.02);
      Valid_Control_Period : constant Packed_F32.T := (Value => 0.5);
      Valid_Saturation_Factor : constant Packed_F32.T := (Value => 1.0);
      Valid_Regime : constant Packed_Pulsing_Regime.T :=
         (Value => Thr_Firing_Remainder_Enums.Pulsing_Regime.On_Pulsing);

      -- Stage the full valid set. Every case below starts from this baseline so a
      -- rejection can only come from the single field that was perturbed.
      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Valid_Min_Fire_Time)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Valid_Control_Period)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Valid_Saturation_Factor)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (Valid_Regime)), Success);
      end Stage_Valid_Set;
   begin
      T.Component_Instance.Init;

      -- The baseline set is accepted:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A negative minimum fire time is rejected (must be finite and >= 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time ((Value => -1.0))), Success);
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

end Thr_Firing_Remainder_Tests.Implementation;
