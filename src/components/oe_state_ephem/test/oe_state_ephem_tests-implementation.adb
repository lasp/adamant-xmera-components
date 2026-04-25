--------------------------------------------------------------------------------
-- Oe_State_Ephem Tests Body
--------------------------------------------------------------------------------

with Ada.Numerics.Long_Elementary_Functions;
with Basic_Assertions; use Basic_Assertions;
with Cartesian_State;
with Interfaces.C;
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

   -- Single-arc Chebyshev expansion at the arc midpoint reconstructs a known circular equatorial orbit within 0.1 percent.
   overriding procedure Test_Cheby_Fit (Self : in out Instance) is
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Closed-form circular equatorial orbit at the arc midpoint. At t = 0
      -- in normalised Chebyshev coordinates only the constant coefficient
      -- contributes, so each orbital element collapses to its first
      -- coefficient and the resulting state has an analytic form.
      Radius_M : constant Long_Float := 7.0E6;
      Mu : constant Long_Float := 3.986004418E14;
      Middle_Time_S : constant Long_Float := 1000.0;
      Radius_Time_S : constant Long_Float := 500.0;
      Circular_Speed : constant Long_Float :=
         Ada.Numerics.Long_Elementary_Functions.Sqrt (Mu / Radius_M);

      -- Build coefficient arrays where only Data(0) is non-zero:
      function Constant_Coeff (Value : in Long_Float) return Oe_Coefficients.T is
         Data : Packed_F64x20.U := [others => 0.0];
      begin
         Data (0) := Value;
         return Oe_Coefficients.Pack ((Data => Data));
      end Constant_Coeff;

      Zero_Coeff : constant Oe_Coefficients.T :=
         Oe_Coefficients.Pack ((Data => Packed_F64x20.U'(others => 0.0)));
      Rp_Coeff : constant Oe_Coefficients.T := Constant_Coeff (Radius_M);

      Tolerance_Rel : constant Long_Float := 1.0E-3;
      Position_Tol : constant Long_Float := Radius_M * Tolerance_Rel;
      Velocity_Tol : constant Long_Float := Circular_Speed * Tolerance_Rel;

      Expected_Position : constant Packed_F64x3.T := [Radius_M, 0.0, 0.0];
      Expected_Velocity : constant Packed_F64x3.T := [0.0, Circular_Speed, 0.0];
   begin
      -- Configure central body and arc:
      T.Set_Central_Body_Mu (Interfaces.C.double (Mu));
      T.Configure_Arc (
         Arc_Number => 0,
         Number_Of_Coefficients => 1,
         Middle_Time => Interfaces.C.double (Middle_Time_S),
         Radius_Time => Interfaces.C.double (Radius_Time_S),
         Anomaly_Flag => 0, -- TRUE_ANOMALY
         Radius_Periapsis => Rp_Coeff,
         Eccentricity => Zero_Coeff,
         Inclination => Zero_Coeff,
         Arg_Periapsis => Zero_Coeff,
         Raan => Zero_Coeff,
         True_Anomaly => Zero_Coeff
      );

      -- Vehicle epoch maps to the arc midpoint, so Chebyshev t = 0:
      T.Clock_Correlation := (Ephemeris_Time => Middle_Time_S, Vehicle_Clock_Time => 0.0);

      -- Run the algorithm:
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Validate one data product was emitted:
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Ephemeris_State_History.Get_Count, 1);

      -- Validate position and velocity match the analytic circular orbit:
      declare
         Output : constant Cartesian_State.T := T.Ephemeris_State_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, Expected_Position, Epsilon => Position_Tol);
         Packed_F64x3_Assert.Eq (Output.Velocity, Expected_Velocity, Epsilon => Velocity_Tol);
      end;
   end Test_Cheby_Fit;

end Oe_State_Ephem_Tests.Implementation;
