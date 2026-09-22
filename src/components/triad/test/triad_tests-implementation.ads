--------------------------------------------------------------------------------
-- Triad Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Triad component
package Triad_Tests.Implementation is

   -- Test data and state:
   type Instance is new Triad_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the algorithm on the input sets of the Python reference test to ensure the
   -- Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Check the fallback constraint axis when the sun is parallel to the requested
   -- thrust direction, and the zero attitude when the triad cannot be formed.
   overriding procedure Test_Degenerate_Geometry (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Triad_Tests.Base_Instance with record
      null;
   end record;
end Triad_Tests.Implementation;
