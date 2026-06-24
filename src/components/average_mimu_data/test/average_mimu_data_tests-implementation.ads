--------------------------------------------------------------------------------
-- Average_Mimu_Data Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Average Mimu Data component
package Average_Mimu_Data_Tests.Implementation is

   -- Test data and state:
   type Instance is new Average_Mimu_Data_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Placeholder test, replaced by per-scenario cases in following commits.
   overriding procedure Test (Self : in out Instance);

   -- Test data and state:
   type Instance is new Average_Mimu_Data_Tests.Base_Instance with record
      null;
   end record;
end Average_Mimu_Data_Tests.Implementation;
