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
   -- ensure the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Check the aligned sun fallback to the retained angle, the offset in sun tracking
   -- mode, and the commanded angle mode against the Python reference model.
   overriding procedure Test_Tracking_Mode_Variants (Self : in out Instance);
   -- Ensure the reset connector zeroes the retained reference angle and leaves the
   -- configuration in place.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure a stale command leaves the last configuration in place, including across
   -- a parameter update.
   overriding procedure Test_Stale_Command (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure the range of the commanded angle type is exactly the range the algorithm
   -- accepts, so command validation rejects what the algorithm would.
   overriding procedure Test_Array_Angle_Range (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Solar_Array_Reference_Tests.Base_Instance with record
      null;
   end record;
end Solar_Array_Reference_Tests.Implementation;
