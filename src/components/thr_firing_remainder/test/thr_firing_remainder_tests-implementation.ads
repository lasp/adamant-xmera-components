--------------------------------------------------------------------------------
-- Thr_Firing_Remainder Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Thr Firing Remainder component
package Thr_Firing_Remainder_Tests.Implementation is

   -- Test data and state:
   type Instance is new Thr_Firing_Remainder_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- A byte outside the pulsing regime enumeration is rejected at parameter staging
   -- by E8 type validation.
   overriding procedure Test_Pulsing_Regime_Validation (Self : in out Instance);

   -- Test data and state:
   type Instance is new Thr_Firing_Remainder_Tests.Base_Instance with record
      null;
   end record;
end Thr_Firing_Remainder_Tests.Implementation;
