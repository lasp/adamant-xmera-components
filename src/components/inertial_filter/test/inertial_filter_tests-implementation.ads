--------------------------------------------------------------------------------
-- Inertial_Filter Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Inertial Filter component
package Inertial_Filter_Tests.Implementation is

   -- Test data and state:
   type Instance is new Inertial_Filter_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Feed a constant star tracker attitude and check the estimate converges to it
   -- while the covariance shrinks, as in the algorithm's Python reference test, to
   -- ensure the Ada to C to C++ integration is sound. The filter state and residual
   -- products report the update and its time.
   overriding procedure Test (Self : in out Instance);
   -- Feed a constant body rate about one axis with the attitude that rotation gives,
   -- and check the rate estimate converges to it while the attitude tracks the
   -- truth.
   overriding procedure Test_Rate_Update (Self : in out Instance);
   -- Ensure a star tracker product whose time tag has not advanced is not fed to the
   -- filter, so the estimate holds and the covariance carries the process noise.
   overriding procedure Test_Propagation (Self : in out Instance);
   -- Ensure the estimate reset re-seeds the state and covariance while the
   -- measurements reset keeps them.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure a star tracker reading not refreshed since before a reset is not
   -- consumed again, one stamped before the tick the filter synchronized its time to
   -- is consumed and dropped, and a later one is applied.
   overriding procedure Test_Reading_Before_Sync (Self : in out Instance);
   -- Ensure a reading stamped after the tick is applied at once without shutting out
   -- the readings that follow for good, and a product stale between star tracker
   -- solutions is still read.
   overriding procedure Test_Time_Anomalies (Self : in out Instance);
   -- Ensure a parameter update is not applied by a tick, which keeps the estimate
   -- tracking, and is applied by a reset.
   overriding procedure Test_Parameter_Update (Self : in out Instance);
   -- Ensure an estimate reset applies a pending configuration update, so the filter
   -- restarts from the new seed.
   overriding procedure Test_Reset_Applies_Pending_Parameters (Self : in out Instance);
   -- Ensure a measurements reset applies a pending configuration update while
   -- keeping the estimate, so a new delay holds the readings that follow.
   overriding procedure Test_Reset_Measurements_Applies_Pending_Parameters (Self : in out Instance);
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
   type Instance is new Inertial_Filter_Tests.Base_Instance with record
      null;
   end record;
end Inertial_Filter_Tests.Implementation;
