--------------------------------------------------------------------------------
-- Sunline_Srukf Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Nav_Att;
with Sunline_Srukf_Output;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;

package body Sunline_Srukf_Tests.Implementation is

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

   -- Run algorithm to ensure integration is sound.
   -- The sunlineSRuKF algorithm is a pass-through: it copies sigma_BN,
   -- omega_BN_B, vehSunPntBdy, and timeTag from input to output.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Sunline_Srukf.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Test data structure for pass-through verification
      type Test_Vector is record
         Att_Input : Nav_Att.T;
         Expected_Sigma_Bn : Packed_F32x3.T;
         Expected_Omega_Bn_B : Packed_F32x3.T;
         Expected_Veh_Sun_Pnt_Bdy : Packed_F32x3.T;
      end record;

      -- Test cases: verify several different attitude values pass through correctly
      Test_Cases : constant array (1 .. 3) of Test_Vector := [
         -- Case 1: Typical attitude values
         (
            Att_Input => (
               Time_Tag => 11.11,
               Sigma_Bn => [0.1, 0.01, -0.1],
               Omega_Bn_B => [1.0, -0.5, 0.25],
               Veh_Sun_Pnt_Bdy => [0.577, 0.577, 0.577]
            ),
            Expected_Sigma_Bn => [0.1, 0.01, -0.1],
            Expected_Omega_Bn_B => [1.0, -0.5, 0.25],
            Expected_Veh_Sun_Pnt_Bdy => [0.577, 0.577, 0.577]
         ),
         -- Case 2: Zero values
         (
            Att_Input => (
               Time_Tag => 0.0,
               Sigma_Bn => [0.0, 0.0, 0.0],
               Omega_Bn_B => [0.0, 0.0, 0.0],
               Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]
            ),
            Expected_Sigma_Bn => [0.0, 0.0, 0.0],
            Expected_Omega_Bn_B => [0.0, 0.0, 0.0],
            Expected_Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]
         ),
         -- Case 3: Negative values
         (
            Att_Input => (
               Time_Tag => 99.99,
               Sigma_Bn => [-0.3, 0.2, -0.15],
               Omega_Bn_B => [-2.0, 3.0, -1.5],
               Veh_Sun_Pnt_Bdy => [-1.0, 0.0, 0.0]
            ),
            Expected_Sigma_Bn => [-0.3, 0.2, -0.15],
            Expected_Omega_Bn_B => [-2.0, 3.0, -1.5],
            Expected_Veh_Sun_Pnt_Bdy => [-1.0, 0.0, 0.0]
         )
      ];
   begin
      -- Provide a defined CSS input. The current sunline_srukf algorithm
      -- copies attitude fields straight through (Cos_Values are not yet
      -- consumed), but the wrapper now down-casts each F64 cosine to F32
      -- and any uninitialized bit pattern would raise Constraint_Error.
      T.Css_Sensor_Input := (Data => [others => 0.0]);

      -- Run each test case
      for I in Test_Cases'Range loop
         -- Set data dependency via tester
         T.Spacecraft_Attitude := Test_Cases (I).Att_Input;

         -- Call algorithm by sending tick
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Verify data product was produced
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Sunline_Srukf_State_History.Get_Count, I);

         -- Check output matches expected pass-through values
         declare
            Output : constant Sunline_Srukf_Output.T := T.Sunline_Srukf_State_History.Get (I);
         begin
            Packed_F32x3_Assert.Eq (
               Output.Sigma_Bn,
               Test_Cases (I).Expected_Sigma_Bn,
               Epsilon => 0.0001
            );
            Packed_F32x3_Assert.Eq (
               Output.Omega_Bn_B,
               Test_Cases (I).Expected_Omega_Bn_B,
               Epsilon => 0.0001
            );
            Packed_F32x3_Assert.Eq (
               Output.Veh_Sun_Pnt_Bdy,
               Test_Cases (I).Expected_Veh_Sun_Pnt_Bdy,
               Epsilon => 0.0001
            );
         end;
      end loop;
   end Test;

end Sunline_Srukf_Tests.Implementation;
