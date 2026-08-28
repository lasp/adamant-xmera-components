--------------------------------------------------------------------------------
-- Mimu_Majority_Vote Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Mimu Majority Vote component
package Mimu_Majority_Vote_Tests.Implementation is

   -- Test data and state:
   type Instance is new Mimu_Majority_Vote_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Test that a malformed parameter is rejected with an error status.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Test that an out-of-range parameter is rejected by the config validator.
   overriding procedure Test_Validate_Parameters (Self : in out Instance);

   -- Test data and state:
   type Instance is new Mimu_Majority_Vote_Tests.Base_Instance with record
      null;
   end record;
end Mimu_Majority_Vote_Tests.Implementation;
