--------------------------------------------------------------------------------
-- Thr_Firing_Remainder Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Thr_On_Time_Cmd;
with Packed_F32x8.Assertion; use Packed_F32x8.Assertion;
with Thr_Firing_Remainder_Parameters;
with Thr_Firing_Remainder_Array_Config;
with Packed_F32;
with Packed_Byte;
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
      Thr_Config : constant Thr_Firing_Remainder_Array_Config.T := (
         Num_Thrusters => 2,
         Thrusters => [
            0 => (R_Thrust_B => [0.0, 0.0, 0.0], T_Hat_Thrust_B => [0.0, 0.0, 1.0], Max_Thrust => 1.0),
            1 => (R_Thrust_B => [0.0, 0.0, 0.0], T_Hat_Thrust_B => [0.0, 0.0, 1.0], Max_Thrust => 1.0),
            others => (R_Thrust_B => [0.0, 0.0, 0.0], T_Hat_Thrust_B => [0.0, 0.0, 0.0], Max_Thrust => 0.0)
         ]
      );

      -- Control parameters
      Min_Fire_Time : constant Packed_F32.T := (Value => 0.02);
      Control_Period_Param : constant Packed_F32.T := (Value => 0.5);
      Saturation_Factor : constant Packed_F32.T := (Value => 1.0);
      On_Pulsing_Regime : constant Packed_Byte.T := (Value => 0);
      Off_Pulsing_Regime : constant Packed_Byte.T := (Value => 1);

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

      -- Stage and apply parameters (thruster config is now a parameter)
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thruster_Config (Thr_Config)), Success);
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

      -- Stage and apply parameters with OFF_PULSING regime (thruster config is a parameter)
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thruster_Config (Thr_Config)), Success);
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

   -- Verify parameter validation rejects configs the algorithm would reject.
   -- Staging only range-checks the type; the algorithm's rules (positive fire
   -- time / control period, saturation factor >= 1, defined pulsing regime) are
   -- enforced by the component's Validate_Parameters via the shim's non-throwing
   -- Validate_Config.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Thr_Firing_Remainder.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Thr_Firing_Remainder_Parameters.Instance;

      Valid_Fire   : constant Packed_F32.T := (Value => 0.02);
      Valid_Period : constant Packed_F32.T := (Value => 0.5);
      Valid_Sat    : constant Packed_F32.T := (Value => 1.0);
      Valid_Regime : constant Packed_Byte.T := (Value => 0);
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      -- Stage a full valid parameter set first so each case below isolates a
      -- single invalid field.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thr_Min_Fire_Time (Valid_Fire)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Valid_Period)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Valid_Sat)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (Valid_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A non-positive control period is rejected.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A saturation factor below 1.0 is rejected.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Valid_Period)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor ((Value => 0.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A pulsing regime outside the defined enumerators (0, 1) is rejected.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.On_Time_Saturation_Factor (Valid_Sat)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime ((Value => 2))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- All fields valid again validates successfully.
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Pulsing_Regime (Valid_Regime)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
   end Test_Invalid_Parameter;

end Thr_Firing_Remainder_Tests.Implementation;
