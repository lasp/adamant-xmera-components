--------------------------------------------------------------------------------
-- Sun_Avoidance Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Sun Avoidance component
package Sun_Avoidance_Tests.Implementation is

   -- Test data and state:
   type Instance is new Sun_Avoidance_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run a slew with the Sun clear of the swept arc to ensure the Ada to C to C++
   -- integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);
   -- Check that a Sun inside the swept arc makes the slew go the long way around.
   overriding procedure Test_Long_Way_Around (Self : in out Instance);
   -- Check that an all-zero Sun position passes the input reference through
   -- unchanged.
   overriding procedure Test_Pass_Through_Without_Sun (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Sun_Avoidance_Tests.Base_Instance with record
      null;
   end record;
end Sun_Avoidance_Tests.Implementation;
