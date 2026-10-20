--------------------------------------------------------------------------------
-- Average_Rw_Speed_Data Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Average Rw Speed Data component
package Average_Rw_Speed_Data_Tests.Implementation is

   -- Test data and state:
   type Instance is new Average_Rw_Speed_Data_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Feed a ramp of wheel speed measurements and check the output is the mean of the
   -- samples in the window, including the sample at the window's edge, and is stamped
   -- with the time of the measurement, to ensure the Ada to C to C++ integration is
   -- sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a tick on which the wheel speed product is stale is treated as a wiring
   -- defect and fails the tick's assertion, since the speeds are measured on every
   -- tick.
   overriding procedure Test_Stale_Data_Dependency (Self : in out Instance);
   -- Ensure a new averaging window reaches the algorithm on the next tick and is
   -- applied to the stored samples.
   overriding procedure Test_Window_Update (Self : in out Instance);
   -- Ensure the reset connector clears the stored samples, so the next measurement is
   -- averaged alone.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure a staged averaging window the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Average_Rw_Speed_Data_Tests.Base_Instance with record
      null;
   end record;
end Average_Rw_Speed_Data_Tests.Implementation;
