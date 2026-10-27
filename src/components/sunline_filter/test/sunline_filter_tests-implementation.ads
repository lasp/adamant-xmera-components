--------------------------------------------------------------------------------
-- Sunline_Filter Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Sunline Filter component
package Sunline_Filter_Tests.Implementation is

   -- Test data and state:
   type Instance is new Sunline_Filter_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Feed the sun sensor cosines and body rate of a slow rotation and check the sun
   -- direction, rate, and bias estimates converge to the truth while the covariance
   -- shrinks, as in the algorithm's Python reference test, to ensure the Ada to C to
   -- C++ integration is sound. The filter state and residual products report the
   -- updates and their times.
   overriding procedure Test (Self : in out Instance);
   -- Ensure products whose timestamps have not advanced are not fed to the filter,
   -- so the sun direction is propagated with the seeded rate and the covariance
   -- grows under the process noise.
   overriding procedure Test_Propagation (Self : in out Instance);
   -- Ensure a product not refreshed since before a reset is not consumed again,
   -- products stamped before the tick the filter synchronized its time to are
   -- consumed and dropped, and the ones after it are applied.
   overriding procedure Test_Reading_Before_Sync (Self : in out Instance);
   -- Ensure products stamped after the tick are applied at once and not again when
   -- the tick reaches them, without shutting out the readings that follow, and
   -- products stale by their stamp are still read.
   overriding procedure Test_Time_Anomalies (Self : in out Instance);
   -- Ensure only the sensors reading above the threshold count as active.
   overriding procedure Test_Sensor_Threshold (Self : in out Instance);
   -- Ensure the estimate reset re-seeds the state and covariance while the
   -- measurements reset keeps them.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure a parameter update reaches the filter while keeping the current
   -- estimate.
   overriding procedure Test_Parameter_Update (Self : in out Instance);
   -- Ensure a configured measurement delay holds a reading until the filter time has
   -- reached its time tag plus the delay, then applies it.
   overriding procedure Test_Measurement_Delay (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Sunline_Filter_Tests.Base_Instance with record
      null;
   end record;
end Sunline_Filter_Tests.Implementation;
