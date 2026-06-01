--------------------------------------------------------------------------------
-- Ephemerides_Recenter Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Interfaces;
with Packed_F64x3;
with Packed_F64x3.Assertion; use Packed_F64x3.Assertion;
with Cartesian_State;

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
   -- Inputs are Cartesian states expressed about the Sun (the previous common
   -- base); outputs should be relative to Mars (the new central body).
   overriding procedure Test (Self : in out Instance) is
      T : Component.Ephemerides_Recenter.Implementation.Tester.Instance_Access renames Self.Tester;

      Sun_State : constant Cartesian_State.T := Cartesian_State.Pack (
         (Position => [0.0, 0.0, 0.0],
          Velocity => [0.0, 0.0, 0.0]));
      Earth_State : constant Cartesian_State.T := Cartesian_State.Pack (
         (Position => [1000.0, -200.0, 100.0],
          Velocity => [10.0, 0.0, -8.0]));
      Mars_State : constant Cartesian_State.T := Cartesian_State.Pack (
         (Position => [-4000.0, 3000.0, 10000.0],
          Velocity => [-1.0, -2.0, 1.0]));
      Moon_State : constant Cartesian_State.T := Cartesian_State.Pack (
         (Position => [-50.0, 30.0, 100.0],
          Velocity => [-0.5, -0.2, 0.1]));

      Eps_Rv : constant Long_Float := 1.0e-9;
   begin
      -- Set data dependencies:
      T.Body_0_Ephemeris := Sun_State;
      T.Body_1_Ephemeris := Earth_State;
      T.Body_2_Ephemeris := Mars_State;
      T.Body_3_Ephemeris := Moon_State;

      -- Call algorithm:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data products were produced (one per body, four total):
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 4);
      Natural_Assert.Eq (T.Body_0_Recentered_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_1_Recentered_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_2_Recentered_History.Get_Count, 1);
      Natural_Assert.Eq (T.Body_3_Recentered_History.Get_Count, 1);

      -- Sun output: r = sun_r - mars_r = [4000, -3000, -10000]; v = [1, 2, -1].
      declare
         Output : constant Cartesian_State.T := T.Body_0_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, [4000.0, -3000.0, -10000.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.Velocity, [1.0, 2.0, -1.0], Epsilon => Eps_Rv);
      end;

      -- Earth output: r = earth_r - mars_r = [5000, -3200, -9900]; v = [11, 2, -9].
      declare
         Output : constant Cartesian_State.T := T.Body_1_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, [5000.0, -3200.0, -9900.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.Velocity, [11.0, 2.0, -9.0], Epsilon => Eps_Rv);
      end;

      -- Mars output: relative to itself, so r = v = 0.
      declare
         Output : constant Cartesian_State.T := T.Body_2_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, [0.0, 0.0, 0.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.Velocity, [0.0, 0.0, 0.0], Epsilon => Eps_Rv);
      end;

      -- Moon output: parent (Earth) is recentered relative to Mars, then the
      -- moon's own position adds back: r = (earth_r - mars_r) + moon_r.
      declare
         Output : constant Cartesian_State.T := T.Body_3_Recentered_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, [4950.0, -3170.0, -9800.0], Epsilon => Eps_Rv);
         Packed_F64x3_Assert.Eq (Output.Velocity, [10.5, 1.8, -8.9], Epsilon => Eps_Rv);
      end;
   end Test;

end Ephemerides_Recenter_Tests.Implementation;
