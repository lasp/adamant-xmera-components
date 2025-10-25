--------------------------------------------------------------------------------
-- Attitude_Tracking_Error Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Att_Guid.Assertion; use Att_Guid.Assertion;

package body Attitude_Tracking_Error_Tests.Implementation is

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

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Attitude_Tracking_Error.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Set data dependencies:
      T.Attitude_Reference := (
         Sigma_Rn => [0.35, -0.25, 0.15],
         Omega_Rn_N => [0.018, -0.032, 0.015],
         Domega_Rn_N => [0.048, -0.022, 0.025]
      );
      T.Navigation_Attitude := (
         Time_Tag => 0.0,
         Sigma_Bn => [0.25, -0.45, 0.75],
         Omega_Bn_B => [-0.015, -0.012, 0.005],
         Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]
      );

      -- Call Algo:
      Self.Tester.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Make sure data product produced:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Attitude_Guidance_History.Get_Count, 1);
      Att_Guid_Assert.Eq (T.Attitude_Guidance_History.Get (1), (
         Sigma_Br => [0.18368415, -0.09744478, -0.0989607],
         Omega_Br_B => [-0.01181208, -0.00891603, -0.03441226],
         Omega_Rn_B => [-0.00318792, -0.00308397, 0.03941226],
         Domega_Rn_B => [-0.02388623, -0.028356, 0.04514848]
      ), Epsilon => 0.001);
   end Test;

end Attitude_Tracking_Error_Tests.Implementation;
