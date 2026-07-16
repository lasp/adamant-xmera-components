--------------------------------------------------------------------------------
-- Convert_St_Platform_To_Body Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_F32x9;
with St_Platform_Attitude;
with St_Platform_Angular_Velocity;
with St_Att;
with Convert_St_Platform_To_Body_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Convert_St_Platform_To_Body_Tests.Implementation is

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
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run algorithm with representative vectors to ensure the Ada->C->C++
   -- integration is sound. Input conventions (per the updated C interface):
   --   Platform_Attitude        : unit quaternion [s, v0, v1, v2] (scalar FIRST,
   --                              Basilisk convention consumed by epToMrp)
   --                              representing q_CN (inertial -> case frame)
   --   Platform_Angular_Velocity: delta quaternion [v0, v1, v2, s] (scalar LAST,
   --                              matches algorithm source that reads dq_CN[3]
   --                              as scalar and dq_CN[0..2] as vector part)
   --                              encoding case-frame angular rate via
   --                              omega_CN_C = 2 * acos(v3) / |v_vec| * [v0, v1, v2]
   --   Time_Tag                 : uint64 nanoseconds
   overriding procedure Test (Self : in out Instance) is
      T : Component.Convert_St_Platform_To_Body.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Convert_St_Platform_To_Body_Parameters.Instance;

      type Test_Vector is record
         Dcm_Cb                    : Packed_F32x9.T;
         Platform_Attitude         : St_Platform_Attitude.T;
         Platform_Angular_Velocity : St_Platform_Angular_Velocity.T;
         Expected_Time_Tag         : Interfaces.Unsigned_64;
         Expected_Sigma_Bn         : Packed_F32x3.T;
         Expected_Omega_Bn_B       : Packed_F32x3.T;
      end record;

      -- Case 1: Identity mounting DCM, 30-deg rotation about z, small rate about
      -- [0.01, -0.02, 0.03] rad. With identity DCM sigma_BN = sigma_CN and
      -- omega_BN_B = omega_CN_C.
      --   q_CN (scalar first) = [cos(pi/12), 0, 0, sin(pi/12)]
      --                       = [0.96592583, 0, 0, 0.25881905]
      --   sigma_CN = v/(1+s) = [0, 0, 0.25881905/1.96592583]
      --                      = [0, 0, 0.13165250]
      --   |omega| = sqrt(0.0014) ~= 0.03741657
      --   axis = omega / |omega|
      --   dq (scalar last) = [axis*sin(|omega|/2), cos(|omega|/2)]
      --                    ~= [0.00499996, -0.00999992, 0.01499988, 0.99982493]
      --
      -- Case 2: Identity mounting DCM, 60-deg rotation about x, zero rate
      -- (dq = identity). Expect sigma_BN = sigma_CN, omega_BN_B = 0.
      --   q_CN (scalar first) = [cos(pi/6), sin(pi/6), 0, 0]
      --                       = [0.86602540, 0.5, 0, 0]
      --   sigma_CN = [0.5/1.86602540, 0, 0] = [0.26794919, 0, 0]
      --
      -- Case 3: 45-deg z-axis mounting DCM + 60-deg x-axis case attitude +
      -- omega_CN_C = [-0.015, 0.008, 0.022] rad. Mirrors the Python
      -- test_rotated_dcm in _tests/test_convertStPlatformToBody.py.
      --   q_CN (scalar first) = [0.86602540, 0.5, 0, 0]
      --   dq_CN (scalar last) ~= [-0.00750022, 0.00400012, 0.01100032, 0.99990336]
      --   sigma_BN = addMRP(sigma_CN, C2MRP(dcm_CB^T))
      --            ~= [0.25661850, 0.10629486, -0.18410810]
      --   omega_BN_B = dcm_CB^T * omega_CN_C
      --            ~= [-0.01626346, -0.00494975, 0.022]
      Test_Cases : constant array (1 .. 3) of Test_Vector := [
         (
            Dcm_Cb => [1.0, 0.0, 0.0,
                       0.0, 1.0, 0.0,
                       0.0, 0.0, 1.0],
            Platform_Attitude => (
               Time_Tag          => 1_000_000_000,
               Platform_Attitude => [0.96592583, 0.0, 0.0, 0.25881905]),
            Platform_Angular_Velocity => (
               Time_Tag                  => 1_000_000_000,
               Platform_Angular_Velocity => [0.00499996, -0.00999992, 0.01499988, 0.99982493]),
            Expected_Time_Tag      => 1_000_000_000,
            Expected_Sigma_Bn => [0.0, 0.0, 0.13165250],
            Expected_Omega_Bn_B    => [0.01, -0.02, 0.03]
         ),
         (
            Dcm_Cb => [1.0, 0.0, 0.0,
                       0.0, 1.0, 0.0,
                       0.0, 0.0, 1.0],
            Platform_Attitude => (
               Time_Tag          => 1_500_000_000,
               Platform_Attitude => [0.86602540, 0.5, 0.0, 0.0]),
            Platform_Angular_Velocity => (
               Time_Tag                  => 1_500_000_000,
               Platform_Angular_Velocity => [0.0, 0.0, 0.0, 1.0]),
            Expected_Time_Tag      => 1_500_000_000,
            Expected_Sigma_Bn => [0.26794919, 0.0, 0.0],
            Expected_Omega_Bn_B    => [0.0, 0.0, 0.0]
         ),
         (
            Dcm_Cb => [0.70710678,  0.70710678, 0.0,
                      -0.70710678,  0.70710678, 0.0,
                       0.0,         0.0,        1.0],
            Platform_Attitude => (
               Time_Tag          => 2_000_000_000,
               Platform_Attitude => [0.86602540, 0.5, 0.0, 0.0]),
            Platform_Angular_Velocity => (
               Time_Tag                  => 2_000_000_000,
               Platform_Angular_Velocity => [-0.00750022, 0.00400012, 0.01100032, 0.99990336]),
            Expected_Time_Tag      => 2_000_000_000,
            Expected_Sigma_Bn => [0.25661850, 0.10629486, -0.18410810],
            Expected_Omega_Bn_B    => [-0.01626346, -0.00494975, 0.022]
         )
      ];
   begin
      for I in Test_Cases'Range loop
         -- Stage and apply the mounting DCM parameter for this case:
         Parameter_Update_Status_Assert.Eq
           (T.Stage_Parameter (Params.Dcm_Cb (Test_Cases (I).Dcm_Cb)), Success);
         Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

         -- Set data dependencies:
         T.Platform_Attitude := Test_Cases (I).Platform_Attitude;
         T.Platform_Angular_Velocity := Test_Cases (I).Platform_Angular_Velocity;

         -- Send tick to trigger algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Verify output was produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Star_Tracker_Body_Attitude_History.Get_Count, I);

         -- Check output matches expected values:
         declare
            Output : constant St_Att.T := T.Star_Tracker_Body_Attitude_History.Get (I);
         begin
            Unsigned_64_Assert.Eq (Output.Time_Tag, Test_Cases (I).Expected_Time_Tag);
            Packed_F32x3_Assert.Eq
              (Output.Sigma_Bn,
               Test_Cases (I).Expected_Sigma_Bn,
               Epsilon => 1.0E-4);
            Packed_F32x3_Assert.Eq
              (Output.Omega_Bn_B,
               Test_Cases (I).Expected_Omega_Bn_B,
               Epsilon => 1.0E-4);
         end;
      end loop;
   end Test;

end Convert_St_Platform_To_Body_Tests.Implementation;
