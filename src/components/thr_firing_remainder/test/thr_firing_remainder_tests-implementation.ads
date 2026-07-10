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

   -- Verify parameter validation rejects configs the algorithm would reject.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Thr_Firing_Remainder_Tests.Base_Instance with record
      null;
   end record;
end Thr_Firing_Remainder_Tests.Implementation;
