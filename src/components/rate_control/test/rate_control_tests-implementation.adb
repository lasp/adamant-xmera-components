--------------------------------------------------------------------------------
-- Rate_Control Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_F32x9;
with Packed_F32;
with Att_Guid;
with Packed_F32x3_Record;
with Rate_Control_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Rate_Control_Tests.Implementation is

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
      T : Component.Rate_Control.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Rate_Control_Parameters.Instance;

      -- Test data from Python test
      -- P gain
      P_Gain : constant Packed_F32.T := (Value => 150.0);

      -- Inertia matrix (diagonal elements): [1000, 800, 800]
      Inertia : constant Packed_F32x9.T := [1000.0, 0.0, 0.0,
                                             0.0, 800.0, 0.0,
                                             0.0, 0.0, 800.0];

      -- Attitude guidance message
      Att_Guidance : constant Att_Guid.T := (
         Sigma_Br => [0.3, -0.5, 0.7],
         Omega_Br_B => [0.010, -0.020, 0.015],
         Omega_Rn_B => [-0.02, -0.01, 0.005],
         Domega_Rn_B => [0.0002, 0.0003, 0.0001]
      );

      -- Expected torque without external torque, computed from the current
      -- algorithm: Lr = -P*omega_BR_B + I*domega_RN_B - knownTorquePntB_B
      -- with knownTorquePntB_B = [0,0,0] (default).
      --   -P*omega_BR_B  = -150 * [0.010, -0.020, 0.015]    = [-1.5, 3.0, -2.25]
      --   I*domega_RN_B  = diag([1000,800,800])*[2e-4,3e-4,1e-4]
      --                                                     = [0.2, 0.24, 0.08]
      --   Lr             =                                    [-1.3, 3.24, -2.17]
      Expected_Torque_No_Ext : constant Packed_F32x3.T := [-1.3, 3.24, -2.17];

      Output : Packed_F32x3_Record.T;
   begin
      -----------------------------------------------------------------------
      -- Test Case 1: Without external torque
      -----------------------------------------------------------------------

      -- Initialize component
      T.Component_Instance.Init;

      -- Set parameters using parameter staging interface
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (P_Gain)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Spacecraft_Inertia (Inertia)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set data dependency
      T.Attitude_Guidance := Att_Guidance;

      -- Send tick to trigger algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify output was produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Torque_Command_History.Get_Count, 1);

      -- Check output matches expected value
      Output := T.Torque_Command_History.Get (1);
      Packed_F32x3_Assert.Eq (
         Output.Value,
         Expected_Torque_No_Ext,
         Epsilon => 0.001
      );

   end Test;

end Rate_Control_Tests.Implementation;
