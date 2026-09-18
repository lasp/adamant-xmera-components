--------------------------------------------------------------------------------
-- Hill_Point Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Hill Point component
package Hill_Point_Tests.Implementation is

   -- Test data and state:
   type Instance is new Hill_Point_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the algorithm to ensure the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Hill_Point_Tests.Base_Instance with record
      null;
   end record;
end Hill_Point_Tests.Implementation;
