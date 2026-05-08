--------------------------------------------------------------------------------
-- Ephemerides_Recenter Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Interfaces;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_F64x3;
with Packed_F64x3.Assertion; use Packed_F64x3.Assertion;
with Ephemeris;

package body Ephemerides_Recenter_Tests.Implementation is

   -- SPICE IDs from the Python reference test (test_ephemeridesRecenter.py):
   Sun_Id   : constant Interfaces.Integer_32 := 10;
   Earth_Id : constant Interfaces.Integer_32 := 399;
   Mars_Id  : constant Interfaces.Integer_32 := 499;
   Moon_Id  : constant Interfaces.Integer_32 := 301;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Configure the algorithm to recenter Sun, Earth, Mars, and Moon onto
      -- Mars, with Sun as the previous common central body. Moon is a moon of
      -- Earth (its original_central_body is Earth, not Sun).
      Self.Tester.Component_Instance.Init (
         New_Zero_Base_Id => Mars_Id,
         Previous_Common_Zero_Base_Id => Sun_Id,
         Body_Count => 4,
         Body_0_Spice_Id => Sun_Id,
         Body_0_Original_Central_Body_Id => Sun_Id,
         Body_1_Spice_Id => Earth_Id,
         Body_1_Original_Central_Body_Id => Sun_Id,
         Body_2_Spice_Id => Mars_Id,
         Body_2_Original_Central_Body_Id => Sun_Id,
         Body_3_Spice_Id => Moon_Id,
         Body_3_Original_Central_Body_Id => Earth_Id
      );

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

   -- Reproduces the mars_central_body case from the Python reference test.
   -- Inputs are expressed about the Sun (the previous common base); outputs
   -- should be relative to Mars (the new central body). Sigma_Bn, Omega_Bn_B,
   -- and Time_Tag pass through from each input to its corresponding output.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Ephemerides_Recenter.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Distinct sigma/omega values per body so the pass-through behaviour is
      -- testable (the C++ algorithm only computes r/v).
      Sun_Eph : constant Ephemeris.T := (
         R_Bdy_Zero_N => [0.0, 0.0, 0.0],
         V_Bdy_Zero_N => [0.0, 0.0, 0.0],
         Sigma_Bn     => [0.10, 0.20, 0.30],
         Omega_Bn_B   => [0.01, 0.02, 0.03],
         Time_Tag     => 1234.0
      );
      Earth_Eph : constant Ephemeris.T := (
         R_Bdy_Zero_N => [1000.0, -200.0, 100.0],
         V_Bdy_Zero_N => [10.0, 0.0, -8.0],
         Sigma_Bn     => [0.11, 0.21, 0.31],
         Omega_Bn_B   => [0.11, 0.12, 0.13],
         Time_Tag     => 1234.0
      );
      Mars_Eph : constant Ephemeris.T := (
         R_Bdy_Zero_N => [-4000.0, 3000.0, 10000.0],
         V_Bdy_Zero_N => [-1.0, -2.0, 1.0],
         Sigma_Bn     => [0.12, 0.22, 0.32],
         Omega_Bn_B   => [0.21, 0.22, 0.23],
         Time_Tag     => 1234.0
      );
      Moon_Eph : constant Ephemeris.T := (
         R_Bdy_Zero_N => [-50.0, 30.0, 100.0],
         V_Bdy_Zero_N => [-0.5, -0.2, 0.1],
         Sigma_Bn     => [0.13, 0.23, 0.33],
         Omega_Bn_B   => [0.31, 0.32, 0.33],
         Time_Tag     => 1234.0
      );

      Eps_Rv : constant Long_Float := 1.0e-9;
   begin
      -- Set data dependencies:
      T.Body_0_Ephemeris := Sun_Eph;
      T.Body_1_Ephemeris := Earth_Eph;
      T.Body_2_Ephemeris := Mars_Eph;
      T.Body_3_Ephemeris := Moon_Eph;

      -- Call algorithm:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data products were produced (one per body, four total):
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 4);
      Natural_Assert.Eq (T.Body_0_Recentered_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_1_Recentered_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_2_Recentered_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_3_Recentered_History.Get_Count, 1);

      -- Sun output: r = sun_r - mars_r = [4000, -3000, -10000]; v = [1, 2, -1].
      -- Sigma/Omega/Time pass through from Sun input.
      declare
         Output : constant Ephemeris.T := T.Body_0_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.R_Bdy_Zero_N, [4000.0, -3000.0, -10000.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.V_Bdy_Zero_N, [1.0, 2.0, -1.0], Epsilon => Eps_Rv);
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, Sun_Eph.Sigma_Bn, Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, Sun_Eph.Omega_Bn_B, Epsilon => 0.0001);
         pragma Assert (Output.Time_Tag = Sun_Eph.Time_Tag);
      end;

      -- Earth output: r = earth_r - mars_r = [5000, -3200, -9900]; v = [11, 2, -9].
      declare
         Output : constant Ephemeris.T := T.Body_1_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.R_Bdy_Zero_N, [5000.0, -3200.0, -9900.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.V_Bdy_Zero_N, [11.0, 2.0, -9.0], Epsilon => Eps_Rv);
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, Earth_Eph.Sigma_Bn, Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, Earth_Eph.Omega_Bn_B, Epsilon => 0.0001);
         pragma Assert (Output.Time_Tag = Earth_Eph.Time_Tag);
      end;

      -- Mars output: relative to itself, so r = v = 0.
      declare
         Output : constant Ephemeris.T := T.Body_2_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.R_Bdy_Zero_N, [0.0, 0.0, 0.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.V_Bdy_Zero_N, [0.0, 0.0, 0.0], Epsilon => Eps_Rv);
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, Mars_Eph.Sigma_Bn, Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, Mars_Eph.Omega_Bn_B, Epsilon => 0.0001);
         pragma Assert (Output.Time_Tag = Mars_Eph.Time_Tag);
      end;

      -- Moon output: parent (Earth) is recentered relative to Mars, then the
      -- moon's own position adds back: r = (earth_r - mars_r) + moon_r.
      declare
         Output : constant Ephemeris.T := T.Body_3_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.R_Bdy_Zero_N, [4950.0, -3170.0, -9800.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.V_Bdy_Zero_N, [10.5, 1.8, -8.9], Epsilon => Eps_Rv);
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, Moon_Eph.Sigma_Bn, Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, Moon_Eph.Omega_Bn_B, Epsilon => 0.0001);
         pragma Assert (Output.Time_Tag = Moon_Eph.Time_Tag);
      end;
   end Test;

end Ephemerides_Recenter_Tests.Implementation;
