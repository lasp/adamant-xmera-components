--------------------------------------------------------------------------------
-- Thr_Firing_Schmitt Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Thr Firing Schmitt component
package Thr_Firing_Schmitt_Tests.Implementation is

   -- Test data and state:
   type Instance is new Thr_Firing_Schmitt_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);

   -- Verify the reset connector clears the Schmitt-trigger hysteresis state.
   overriding procedure Test_Reset (Self : in out Instance);

   -- A duty cycle at or above Level_On latches the thruster on at the minimum
   -- fire time, and one at or below Level_Off latches it off, regardless of the
   -- previous state.
   overriding procedure Test_Min_Fire_Time_Floor (Self : in out Instance);

   -- An on-time request that reaches the control period saturates to
   -- On_Time_Saturation_Factor times the control period.
   overriding procedure Test_On_Time_Saturation (Self : in out Instance);

   -- Off-pulsing adds the maximum thrust to the requested force and clamps the
   -- sum at zero.
   overriding procedure Test_Off_Pulsing_Offset (Self : in out Instance);

   -- Each thruster carries its own hysteresis state, so the same intermediate
   -- force yields different on-times.
   overriding procedure Test_Thruster_Independence (Self : in out Instance);

   -- Thrusters beyond the configured count are left at zero on-time and their
   -- zero maximum thrust is never divided by.
   overriding procedure Test_Num_Thrusters_Bound (Self : in out Instance);

   -- A byte outside the pulsing regime enumeration is rejected at parameter
   -- staging by E8 type validation.
   overriding procedure Test_Pulsing_Regime_Validation (Self : in out Instance);

   -- A staged parameter set the algorithm's config validators would reject is
   -- refused by Validate_Parameters, one field at a time.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Thr_Firing_Schmitt_Tests.Base_Instance with record
      null;
   end record;
end Thr_Firing_Schmitt_Tests.Implementation;
