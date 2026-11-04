--------------------------------------------------------------------------------
-- Solar_Array_Reference Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Solar Array Reference component
package Solar_Array_Reference_Tests.Implementation is

   -- Test data and state:
   type Instance is new Solar_Array_Reference_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the algorithm on the sun tracking cases of the Python reference test to
   -- ensure the Ada to C to C++ integration is sound. The mode and the angles are
   -- set as parameters.
   overriding procedure Test (Self : in out Instance);
   -- Check the aligned sun fallback to the retained angle, the offset in sun
   -- tracking mode, and the specified angle mode against the Python reference model.
   overriding procedure Test_Tracking_Mode_Variants (Self : in out Instance);
   -- Ensure the reset connector zeroes the retained reference angle and leaves the
   -- configuration in place.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure the mode and angles stay in effect on the ticks that follow their
   -- update, including across a later update of the array axes alone.
   overriding procedure Test_Mode_Retained (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation, whether the rejected value is an array axis, the threshold, or an
   -- angle.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure the angle bounds the algorithm accepts, plus and minus pi, pass
   -- validation and the first values outside them are rejected, so an angle is
   -- refused exactly when the algorithm would refuse it.
   overriding procedure Test_Angle_Range (Self : in out Instance);
   -- Ensure the specified angle mode runs without the attitude inputs and the sun
   -- tracking mode requires them.
   overriding procedure Test_Specified_Angle_Without_Attitude (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Solar_Array_Reference_Tests.Base_Instance with record
      null;
   end record;
end Solar_Array_Reference_Tests.Implementation;
