--------------------------------------------------------------------------------
-- Sunline_Srukf Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
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

   -- Run the component to ensure the pass-through is sound. Only omega_BN_B is
   -- supplied (from body_rate_miscompare); sigma_BN, vehSunPntBdy, and timeTag
   -- have no upstream producer and are zeroed, so the output carries the input
   -- omega and zeros for the other fields.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Sunline_Srukf.Implementation.Tester.Instance_Access renames Self.Tester;

      Zero_Vec : constant Packed_F32x3.T := [0.0, 0.0, 0.0];

      -- Body-rate inputs to exercise (typical, zero, negative).
      Omega_Cases : constant array (1 .. 3) of Packed_F32x3.T := [
         [1.0, -0.5, 0.25],
         [0.0, 0.0, 0.0],
         [-2.0, 3.0, -1.5]
      ];
   begin
      -- Provide a defined CSS input. The component fetches it so a wiring
      -- defect is still caught, but publishes no CSS-derived field.
      T.Css_Sensor_Input := (Data => [others => 0.0]);

      -- Run each test case
      for I in Omega_Cases'Range loop
         -- Set the body-rate data dependency via tester
         T.Spacecraft_Attitude := Omega_Cases (I);

         -- Call algorithm by sending tick
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Verify data product was produced
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Sunline_Srukf_State_History.Get_Count, I);

         -- Omega passes through; sigma and sun vector are zeroed by the wrapper.
         declare
            Output : constant Sunline_Srukf_Output.T := T.Sunline_Srukf_State_History.Get (I);
         begin
            Packed_F32x3_Assert.Eq (
               Output.Omega_Bn_B,
               Omega_Cases (I),
               Epsilon => 0.0001
            );
            Packed_F32x3_Assert.Eq (Output.Sigma_Bn, Zero_Vec, Epsilon => 0.0001);
            Packed_F32x3_Assert.Eq (Output.Veh_Sun_Pnt_Bdy, Zero_Vec, Epsilon => 0.0001);
         end;
      end loop;
   end Test;

end Sunline_Srukf_Tests.Implementation;
