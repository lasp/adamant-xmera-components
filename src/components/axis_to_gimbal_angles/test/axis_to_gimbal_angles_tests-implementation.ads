--------------------------------------------------------------------------------
-- Axis_To_Gimbal_Angles Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Axis To Gimbal Angles component
package Axis_To_Gimbal_Angles_Tests.Implementation is

   -- Test data and state:
   type Instance is new Axis_To_Gimbal_Angles_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Recover known gimbal angle pairs from requests built from them, as in the
   -- Python reference test, to ensure the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);
   -- Check that a request beyond the travel is pulled back onto the cone of the
   -- largest deflection, and that a request with no direction leaves the gimbal at
   -- neutral.
   overriding procedure Test_Deflection_Limit (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Axis_To_Gimbal_Angles_Tests.Base_Instance with record
      null;
   end record;
end Axis_To_Gimbal_Angles_Tests.Implementation;
