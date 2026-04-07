--------------------------------------------------------------------------------
-- Nav_Aggregate Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_F64x3;
with Packed_F64x3.Assertion; use Packed_F64x3.Assertion;
with Nav_Att;
with Nav_Trans;
with Ephemeris;

package body Nav_Aggregate_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Component init will be called per-test with different configurations
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

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Nav_Aggregate.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Test data from Python test (test_navAggregate.py)
      -- navAtt1: timeTag=11.11, sigma=[0.1, 0.01, -0.1], omega=[1., 1., -1.], sun=[-0.1, 0.1, 0.1]
      Att_Msg_0 : constant Nav_Att.T := (
         Time_Tag => 11.11,
         Sigma_Bn => [0.1, 0.01, -0.1],
         Omega_Bn_B => [1.0, 1.0, -1.0],
         Veh_Sun_Pnt_Bdy => [-0.1, 0.1, 0.1]
      );

      -- navAtt2: timeTag=22.22, sigma=[0.2, 0.02, -0.2], omega=[2., 2., -2.], sun=[-0.2, 0.2, 0.2]
      Att_Msg_1 : constant Nav_Att.T := (
         Time_Tag => 22.22,
         Sigma_Bn => [0.2, 0.02, -0.2],
         Omega_Bn_B => [2.0, 2.0, -2.0],
         Veh_Sun_Pnt_Bdy => [-0.2, 0.2, 0.2]
      );

      -- Ephemeris1: timeTag=11.1, r=[1000.0, 100.0, -1000.0], v=[1., 1., -1.]
      Trans_Msg_0 : constant Ephemeris.T := (
         R_Bdy_Zero_N => [1000.0, 100.0, -1000.0],
         V_Bdy_Zero_N => [1.0, 1.0, -1.0],
         Sigma_Bn => [0.0, 0.0, 0.0],
         Omega_Bn_B => [0.0, 0.0, 0.0],
         Time_Tag => 11.1
      );

      -- Ephemeris2: timeTag=22.2, r=[2000.0, 200.0, -2000.0], v=[2., 2., -2.]
      Trans_Msg_1 : constant Ephemeris.T := (
         R_Bdy_Zero_N => [2000.0, 200.0, -2000.0],
         V_Bdy_Zero_N => [2.0, 2.0, -2.0],
         Sigma_Bn => [0.0, 0.0, 0.0],
         Omega_Bn_B => [0.0, 0.0, 0.0],
         Time_Tag => 22.2
      );

   begin
      -----------------------------------------------------------------------
      -- Test Case 1: numAttNav=2, numTransNav=2, indices point to message 1
      -- Expected: Output should be message 1 for all fields
      -----------------------------------------------------------------------
      T.Component_Instance.Init (
         Att_Time_Idx => 1,
         Trans_Time_Idx => 1,
         Att_Idx => 1,
         Rate_Idx => 1,
         Pos_Idx => 1,
         Vel_Idx => 1,
         Dv_Idx => 1,
         Sun_Idx => 1,
         Att_Msg_Count => 2,
         Trans_Msg_Count => 2
      );
      T.Component_Instance.Set_Up;

      -- Set data dependencies
      T.Att_Msg_0 := Att_Msg_0;
      T.Att_Msg_1 := Att_Msg_1;
      T.Trans_Msg_0 := Trans_Msg_0;
      T.Trans_Msg_1 := Trans_Msg_1;

      -- Call algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data products were produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2);
      Natural_Assert.Eq (T.Aggregated_Nav_Att_History.Get_Count, 1);
      Natural_Assert.Eq (T.Aggregated_Nav_Trans_History.Get_Count, 1);

      -- Check attitude output (should be message 1 since all indices = 1)
      declare
         Output : constant Nav_Att.T := T.Aggregated_Nav_Att_History.Get (1);
      begin
         -- Time tag from message 1
         pragma Assert (abs (Output.Time_Tag - 22.22) < 0.01);
         -- Sigma from message 1
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, [0.2, 0.02, -0.2], Epsilon => 0.0001);
         -- Omega from message 1
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, [2.0, 2.0, -2.0], Epsilon => 0.0001);
         -- Sun vector from message 1
         Packed_F32x3_Assert.Eq (Output.Veh_Sun_Pnt_Bdy, [-0.2, 0.2, 0.2], Epsilon => 0.0001);
      end;

      -- Check translation output (should be message 1 since all indices = 1)
      declare
         Output : constant Nav_Trans.T := T.Aggregated_Nav_Trans_History.Get (1);
      begin
         -- Time tag from message 1
         pragma Assert (abs (Output.Time_Tag - 22.2) < 0.01);
         -- Position from message 1
         Packed_F64x3_Assert.Eq (Output.R_Bn_N, [2000.0, 200.0, -2000.0], Epsilon => 0.1);
         -- Velocity from message 1
         Packed_F64x3_Assert.Eq (Output.V_Bn_N, [2.0, 2.0, -2.0], Epsilon => 0.0001);
         -- Accumulated DV zeroed by Ephemeris-to-Nav_Trans conversion
         Packed_F32x3_Assert.Eq (Output.Vehaccumdv, [0.0, 0.0, 0.0], Epsilon => 0.0001);
      end;

      -- Destroy before next test
      T.Component_Instance.Destroy;

      -----------------------------------------------------------------------
      -- Test Case 2: numAttNav=2, numTransNav=2, indices point to message 0
      -- Expected: Output should be message 0 for all fields
      -----------------------------------------------------------------------
      T.Component_Instance.Init (
         Att_Time_Idx => 0,
         Trans_Time_Idx => 0,
         Att_Idx => 0,
         Rate_Idx => 0,
         Pos_Idx => 0,
         Vel_Idx => 0,
         Dv_Idx => 0,
         Sun_Idx => 0,
         Att_Msg_Count => 2,
         Trans_Msg_Count => 2
      );
      T.Component_Instance.Set_Up;

      -- Set data dependencies (same as before)
      T.Att_Msg_0 := Att_Msg_0;
      T.Att_Msg_1 := Att_Msg_1;
      T.Trans_Msg_0 := Trans_Msg_0;
      T.Trans_Msg_1 := Trans_Msg_1;

      -- Call algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data products were produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 4);  -- 2 from first test + 2 from this
      Natural_Assert.Eq (T.Aggregated_Nav_Att_History.Get_Count, 2);
      Natural_Assert.Eq (T.Aggregated_Nav_Trans_History.Get_Count, 2);

      -- Check attitude output (should be message 0 since all indices = 0)
      declare
         Output : constant Nav_Att.T := T.Aggregated_Nav_Att_History.Get (2);
      begin
         -- Time tag from message 0
         pragma Assert (abs (Output.Time_Tag - 11.11) < 0.01);
         -- Sigma from message 0
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, [0.1, 0.01, -0.1], Epsilon => 0.0001);
         -- Omega from message 0
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, [1.0, 1.0, -1.0], Epsilon => 0.0001);
         -- Sun vector from message 0
         Packed_F32x3_Assert.Eq (Output.Veh_Sun_Pnt_Bdy, [-0.1, 0.1, 0.1], Epsilon => 0.0001);
      end;

      -- Check translation output (should be message 0 since all indices = 0)
      declare
         Output : constant Nav_Trans.T := T.Aggregated_Nav_Trans_History.Get (2);
      begin
         -- Time tag from message 0
         pragma Assert (abs (Output.Time_Tag - 11.1) < 0.01);
         -- Position from message 0
         Packed_F64x3_Assert.Eq (Output.R_Bn_N, [1000.0, 100.0, -1000.0], Epsilon => 0.1);
         -- Velocity from message 0
         Packed_F64x3_Assert.Eq (Output.V_Bn_N, [1.0, 1.0, -1.0], Epsilon => 0.0001);
         -- Accumulated DV from message 0
         Packed_F32x3_Assert.Eq (Output.Vehaccumdv, [0.0, 0.0, 0.0], Epsilon => 0.0001);
      end;

      -- Destroy before next test
      T.Component_Instance.Destroy;

      -----------------------------------------------------------------------
      -- Test Case 3: numAttNav=1, numTransNav=1 (only fetch message 0)
      -- Expected: Output should be message 0 (the only one available)
      -----------------------------------------------------------------------
      T.Component_Instance.Init (
         Att_Time_Idx => 0,
         Trans_Time_Idx => 0,
         Att_Idx => 0,
         Rate_Idx => 0,
         Pos_Idx => 0,
         Vel_Idx => 0,
         Dv_Idx => 0,
         Sun_Idx => 0,
         Att_Msg_Count => 1,  -- Only 1 message
         Trans_Msg_Count => 1  -- Only 1 message
      );
      T.Component_Instance.Set_Up;

      -- Set only message 0 (message 1 won't be fetched due to count=1)
      T.Att_Msg_0 := Att_Msg_0;
      T.Trans_Msg_0 := Trans_Msg_0;

      -- Call algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data products were produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 6);  -- 4 + 2
      Natural_Assert.Eq (T.Aggregated_Nav_Att_History.Get_Count, 3);
      Natural_Assert.Eq (T.Aggregated_Nav_Trans_History.Get_Count, 3);

      -- Check attitude output (should be message 0)
      declare
         Output : constant Nav_Att.T := T.Aggregated_Nav_Att_History.Get (3);
      begin
         pragma Assert (abs (Output.Time_Tag - 11.11) < 0.01);
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, [0.1, 0.01, -0.1], Epsilon => 0.0001);
      end;

      -- Check translation output (should be message 0)
      declare
         Output : constant Nav_Trans.T := T.Aggregated_Nav_Trans_History.Get (3);
      begin
         pragma Assert (abs (Output.Time_Tag - 11.1) < 0.01);
         Packed_F64x3_Assert.Eq (Output.R_Bn_N, [1000.0, 100.0, -1000.0], Epsilon => 0.1);
      end;

      -- Destroy before next test
      T.Component_Instance.Destroy;

      -----------------------------------------------------------------------
      -- Test Case 4: Mixed counts - numAttNav=1, numTransNav=2
      -- Expected: Attitude from message 0 (only one), Translation from message 1
      -----------------------------------------------------------------------
      T.Component_Instance.Init (
         Att_Time_Idx => 0,
         Trans_Time_Idx => 1,
         Att_Idx => 0,
         Rate_Idx => 0,
         Pos_Idx => 1,
         Vel_Idx => 1,
         Dv_Idx => 1,
         Sun_Idx => 0,
         Att_Msg_Count => 1,   -- Only 1 attitude message
         Trans_Msg_Count => 2  -- 2 translation messages
      );
      T.Component_Instance.Set_Up;

      -- Set data dependencies
      T.Att_Msg_0 := Att_Msg_0;
      T.Trans_Msg_0 := Trans_Msg_0;
      T.Trans_Msg_1 := Trans_Msg_1;

      -- Call algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify data products were produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 8);  -- 6 + 2
      Natural_Assert.Eq (T.Aggregated_Nav_Att_History.Get_Count, 4);
      Natural_Assert.Eq (T.Aggregated_Nav_Trans_History.Get_Count, 4);

      -- Check attitude output (should be message 0, the only one available)
      declare
         Output : constant Nav_Att.T := T.Aggregated_Nav_Att_History.Get (4);
      begin
         pragma Assert (abs (Output.Time_Tag - 11.11) < 0.01);
         Packed_F32x3_Assert.Eq (Output.Sigma_Bn, [0.1, 0.01, -0.1], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Omega_Bn_B, [1.0, 1.0, -1.0], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Veh_Sun_Pnt_Bdy, [-0.1, 0.1, 0.1], Epsilon => 0.0001);
      end;

      -- Check translation output (should be message 1, selected by indices)
      declare
         Output : constant Nav_Trans.T := T.Aggregated_Nav_Trans_History.Get (4);
      begin
         pragma Assert (abs (Output.Time_Tag - 22.2) < 0.01);
         Packed_F64x3_Assert.Eq (Output.R_Bn_N, [2000.0, 200.0, -2000.0], Epsilon => 0.1);
         Packed_F64x3_Assert.Eq (Output.V_Bn_N, [2.0, 2.0, -2.0], Epsilon => 0.0001);
         Packed_F32x3_Assert.Eq (Output.Vehaccumdv, [0.0, 0.0, 0.0], Epsilon => 0.0001);
      end;

   end Test;

end Nav_Aggregate_Tests.Implementation;
