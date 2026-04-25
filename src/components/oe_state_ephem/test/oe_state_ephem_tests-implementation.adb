--------------------------------------------------------------------------------
-- Oe_State_Ephem Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Cartesian_State;
with Oe_Coefficients;
with Packed_F64x3;
with Packed_F64x3.Assertion; use Packed_F64x3.Assertion;
with Packed_F64x20;

package body Oe_State_Ephem_Tests.Implementation is

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

   -- Zero coefficients and zero gravitational parameter must produce zero Cartesian state.
   overriding procedure Test_Zero_Inputs (Self : in out Instance) is
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Mirrors test_oeStateEphem.py::test_zero_inputs: arc midpoint at t=1,
      -- arc half-width 0.5, vehicle time 0 maps to ephemeris time 0.5
      -- (the start of the arc).
      Zero_Coeff : constant Oe_Coefficients.T :=
         Oe_Coefficients.Pack ((Data => Packed_F64x20.U'(others => 0.0)));
      Expected_Zero : constant Packed_F64x3.T := [0.0, 0.0, 0.0];
      Epsilon : constant Long_Float := 1.0E-7;
   begin
      -- Set Mu directly via the C binding (bypassing the parameter pipeline):
      T.Set_Central_Body_Mu (0.0);

      -- Configure arc 0 with all-zero Chebyshev coefficients:
      T.Configure_Arc (
         Arc_Number => 0,
         Number_Of_Coefficients => 1,
         Middle_Time => 1.0,
         Radius_Time => 0.5,
         Anomaly_Flag => 0, -- TRUE_ANOMALY
         Radius_Periapsis => Zero_Coeff,
         Eccentricity => Zero_Coeff,
         Inclination => Zero_Coeff,
         Arg_Periapsis => Zero_Coeff,
         Raan => Zero_Coeff,
         True_Anomaly => Zero_Coeff
      );

      -- Provide clock correlation: vehicle 0 -> ephemeris 0.5 (middle - radius):
      T.Clock_Correlation := (Ephemeris_Time => 0.5, Vehicle_Clock_Time => 0.0);

      -- Run the algorithm:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Validate one data product was emitted:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Ephemeris_State_History.Get_Count, 1);

      -- Validate position and velocity are zero within tolerance:
      declare
         Output : constant Cartesian_State.T := T.Ephemeris_State_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, Expected_Zero, Epsilon => Epsilon);
         Packed_F64x3_Assert.Eq (Output.Velocity, Expected_Zero, Epsilon => Epsilon);
      end;
   end Test_Zero_Inputs;

end Oe_State_Ephem_Tests.Implementation;
