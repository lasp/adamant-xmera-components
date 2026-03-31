--------------------------------------------------------------------------------
-- Inertial_Ukf Tests Body
--------------------------------------------------------------------------------

with AUnit.Assertions; use AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Component.Inertial_Ukf.Implementation.Tester;
with Nav_Att;
with Inertial_Filter_Output;
with Rw_Array_Config_Input;
with Vehicle_Config_Input;
with Inertial_Ukf_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Interfaces; use Interfaces;

package body Inertial_Ukf_Tests.Implementation is

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
      -- Free component heap:
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run algorithm with known inputs to verify the pass-through of star-tracker
   -- attitude to nav attitude estimate and filter output.
   overriding procedure Test_Pass_Through (Self : in out Instance) is
      T : Component.Inertial_Ukf.Implementation.Tester.Instance_Access renames Self.Tester;

      Params     : Inertial_Ukf_Parameters.Instance;
      Rw_Config  : constant Rw_Array_Config_Input.T := (Num_Rw => 4);
      Veh_Config : constant Vehicle_Config_Input.T  :=
         (Iscpnt_B_B => [others => 0.0], Mass_Sc => 1.0);
      Zero_Vec   : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      Epsilon    : constant := 1.0e-5;
   begin
      -- Stage and commit default parameters. The pass-through algorithm does
      -- not use them, but the component requires a successful parameter update.
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Rw_Array_Config (Rw_Config)), Success);
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Vehicle_Config (Veh_Config)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -----------------------------------------------------------------------
      -- Test Case 1: Known non-zero star-tracker attitude
      -----------------------------------------------------------------------

      declare
         Expected_Sigma  : constant Packed_F32x3.T := [0.1, -0.2, 0.3];
         Expected_Omega  : constant Packed_F32x3.T := [0.01, -0.02, 0.03];
         Time_Tag_In     : constant Short_Float     := 1.5;
         Nav_Out         : Nav_Att.T;
         Filter_Out      : Inertial_Filter_Output.T;
      begin
         -- Set data dependency values using packed record aggregates directly.
         T.Star_Tracker_Att := (
            Time_Tag        => Long_Float (Time_Tag_In),
            Sigma_Bn        => Expected_Sigma,
            Omega_Bn_B      => Expected_Omega,
            Veh_Sun_Pnt_Bdy => Zero_Vec);
         T.Gyro_Measurement := (Gyro_B => Zero_Vec);
         T.Rw_Speeds        := (Wheel_Speeds => [0.0, 0.0, 0.0, 0.0]);

         -- Trigger component execution.
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Both data products must have been published.
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
         Natural_Assert.Eq (T.Nav_Att_Estimate_History.Get_Count, 1);
         Natural_Assert.Eq (T.Filter_Data_History.Get_Count, 1);

         -- Verify Nav_Att_Estimate: time tag promoted float->double, sigma and
         -- omega passed through unchanged, sun-pointing vector remains zero.
         Nav_Out := T.Nav_Att_Estimate_History.Get (1);
         Long_Float_Assert.Eq (
            Nav_Out.Time_Tag, Long_Float (Time_Tag_In), Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Nav_Out.Sigma_Bn, Expected_Sigma, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Nav_Out.Omega_Bn_B, Expected_Omega, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Nav_Out.Veh_Sun_Pnt_Bdy, Zero_Vec, Epsilon => Epsilon);

         -- Verify Filter_Data: time tag matches, numObs = 0 (not yet computed
         -- in the pass-through implementation).
         Filter_Out := T.Filter_Data_History.Get (1);
         Long_Float_Assert.Eq (
            Filter_Out.Time_Tag, Long_Float (Time_Tag_In), Epsilon => Epsilon);
         Assert (Filter_Out.Num_Obs = Integer_32 (0),
                 "Filter Num_Obs should be zero in pass-through mode");
      end;

      -----------------------------------------------------------------------
      -- Test Case 2: Zero-valued star-tracker attitude
      -----------------------------------------------------------------------

      declare
         Nav_Out    : Nav_Att.T;
         Filter_Out : Inertial_Filter_Output.T;
      begin
         T.Star_Tracker_Att := (
            Time_Tag        => 0.0,
            Sigma_Bn        => Zero_Vec,
            Omega_Bn_B      => Zero_Vec,
            Veh_Sun_Pnt_Bdy => Zero_Vec);

         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 4);
         Natural_Assert.Eq (T.Nav_Att_Estimate_History.Get_Count, 2);
         Natural_Assert.Eq (T.Filter_Data_History.Get_Count, 2);

         Nav_Out := T.Nav_Att_Estimate_History.Get (2);
         Long_Float_Assert.Eq (Nav_Out.Time_Tag, 0.0, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Nav_Out.Sigma_Bn, Zero_Vec, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Nav_Out.Omega_Bn_B, Zero_Vec, Epsilon => Epsilon);

         Filter_Out := T.Filter_Data_History.Get (2);
         Long_Float_Assert.Eq (Filter_Out.Time_Tag, 0.0, Epsilon => Epsilon);
         Assert (Filter_Out.Num_Obs = Integer_32 (0),
                 "Filter Num_Obs should be zero in pass-through mode");
      end;

   end Test_Pass_Through;

end Inertial_Ukf_Tests.Implementation;
