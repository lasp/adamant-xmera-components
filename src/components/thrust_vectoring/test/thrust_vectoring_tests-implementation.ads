--------------------------------------------------------------------------------
-- Thrust_Vectoring Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Thrust Vectoring component
package Thrust_Vectoring_Tests.Implementation is

   -- Test data and state:
   type Instance is new Thrust_Vectoring_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Point the thrust for a zero, a small, and a saturating torque request to ensure
   -- the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Thrust_Vectoring_Tests.Base_Instance with record
      null;
   end record;
end Thrust_Vectoring_Tests.Implementation;
