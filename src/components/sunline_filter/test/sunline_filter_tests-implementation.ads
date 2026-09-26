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
   -- Ensure products stamped before the time base restarted by a reset are dropped,
   -- and later ones are applied.
   overriding procedure Test_Reading_Before_Time_Base (Self : in out Instance);
   -- Ensure products stamped after the tick wait until the tick reaches them, and a
   -- tick before the time base restarts it, without either shutting out the readings
   -- that follow.
   overriding procedure Test_Time_Anomalies (Self : in out Instance);
   -- Ensure only the configured number of sensors is read and only those above the
   -- threshold count as active.
   overriding procedure Test_Fewer_Sensors (Self : in out Instance);
   -- Ensure the estimate reset re-seeds the state and covariance while the
   -- measurements reset keeps them.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure a parameter update reaches the filter while keeping the current
   -- estimate.
   overriding procedure Test_Parameter_Update (Self : in out Instance);
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
