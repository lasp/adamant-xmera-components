--------------------------------------------------------------------------------
-- Gimbal_Angles_To_Motor_Angles Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Gimbal Angles To Motor Angles component
package Gimbal_Angles_To_Motor_Angles_Tests.Implementation is

   -- Test data and state:
   type Instance is new Gimbal_Angles_To_Motor_Angles_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Compute the motor angles for known gimbal angles with the linear configuration
   -- of the algorithm's own unit tests, whose surfaces have known values, to ensure
   -- the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Check that a request outside the addressable rhombus keeps the last computed
   -- motor angles, and that before a first valid request and after a reset it gives
   -- the motor angles at zero gimbal angles.
   overriding procedure Test_Outside_Rhombus (Self : in out Instance);
   -- Check that a reset, not a tick, applies a parameter update.
   overriding procedure Test_Parameter_Update (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Gimbal_Angles_To_Motor_Angles_Tests.Base_Instance with record
      null;
   end record;
end Gimbal_Angles_To_Motor_Angles_Tests.Implementation;
