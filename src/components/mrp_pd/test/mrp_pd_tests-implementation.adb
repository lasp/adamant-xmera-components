--------------------------------------------------------------------------------
-- Mrp_Pd Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x9;
with Cmd_Torque_Body;
with Cmd_Torque_Body.Assertion; use Cmd_Torque_Body.Assertion;
with Mrp_Pd_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Mrp_Pd_Tests.Implementation is

   -- Gains, inertia, and guidance errors from the Python reference test
   -- (_tests/test_mrpPD.py).
   Gain_K : constant Packed_F32.T := (Value => 0.15);
   Gain_P : constant Packed_F32.T := (Value => 150.0);
   Inertia : constant Packed_F32x9.T := [1000.0, 0.0, 0.0,
                                         0.0, 800.0, 0.0,
                                         0.0, 0.0, 800.0];
   No_Torque : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   External_Torque : constant Packed_F32x3.T := [0.1, 0.2, 0.3];

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

   -- Run the algorithm to ensure the Ada -> C -> C++ integration is sound. The
   -- control law is Lr = -K*sigma_BR - P*omega_BR_B + I*domega_RN_B - knownTorque,
   -- so with the reference values:
   --   -K*sigma_BR  = [-0.045, 0.075, -0.105]
   --   -P*omega_BR_B = [-1.5, 3.0, -2.25]
   --   I*domega_RN_B = [0.2, 0.24, 0.08]
   -- giving [-1.345, 3.315, -2.275] with no known torque, and that less
   -- [0.1, 0.2, 0.3] when the known external torque is configured.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mrp_Pd.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Pd_Parameters.Instance;

      type Test_Vector is record
         Known_Torque_Pnt_B_B : Packed_F32x3.T;
         Expected_Torque : Packed_F32x3.T;
      end record;

      Test_Cases : constant array (1 .. 2) of Test_Vector := [
         (Known_Torque_Pnt_B_B => No_Torque,
          Expected_Torque => [-1.345, 3.315, -2.275]),
         (Known_Torque_Pnt_B_B => External_Torque,
          Expected_Torque => [-1.445, 3.115, -2.575])
      ];
   begin
      -- The attitude guidance solution is the same for both cases:
      T.Attitude_Guidance := (
         Sigma_Br => [0.3, -0.5, 0.7],
         Omega_Br_B => [0.010, -0.020, 0.015],
         Omega_Rn_B => [-0.02, -0.01, 0.005],
         Domega_Rn_B => [0.0002, 0.0003, 0.0001]
      );

      for I in Test_Cases'Range loop
         -- Stage and apply the configuration for this case:
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K (Gain_K)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (Gain_P)), Success);
         Parameter_Update_Status_Assert.Eq
           (T.Stage_Parameter (Params.Known_Torque_Pnt_B_B (Test_Cases (I).Known_Torque_Pnt_B_B)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Inertia (Inertia)), Success);
         Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

         -- Send tick to trigger algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Verify output was produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Control_Torque_History.Get_Count, I);

         -- Check output matches expected values:
         Cmd_Torque_Body_Assert.Eq
           (T.Control_Torque_History.Get (I),
            (Torque_Request_Body => Test_Cases (I).Expected_Torque),
            Epsilon => 1.0E-4);
      end loop;
   end Test;

   -- The algorithm requires non-negative gains, a finite known torque, and a valid
   -- spacecraft inertia matrix. Validation is the only guard keeping a rejected value
   -- out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mrp_Pd.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Pd_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Proportional_Gain_K (Gain_K)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Derivative_Gain_P (Gain_P)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Known_Torque_Pnt_B_B (No_Torque)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Inertia (Inertia)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A negative proportional gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Proportional_Gain_K ((Value => -0.15))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative derivative gain is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Derivative_Gain_P ((Value => -150.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An all-zero inertia is rejected (singular):
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Inertia ([0.0, 0.0, 0.0,
                                             0.0, 0.0, 0.0,
                                             0.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An asymmetric inertia is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Inertia ([1000.0, 5.0, 0.0,
                                             0.0, 800.0, 0.0,
                                             0.0, 0.0, 800.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An inertia violating the triangle inequality is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Inertia ([1000.0, 0.0, 0.0,
                                             0.0, 100.0, 0.0,
                                             0.0, 0.0, 100.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Mrp_Pd_Tests.Implementation;
