--------------------------------------------------------------------------------
-- Css_Weighted_Least_Squares Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Css Weighted Least Squares component
package Css_Weighted_Least_Squares_Tests.Implementation is

   -- Test data and state:
   type Instance is new Css_Weighted_Least_Squares_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Fit the sun heading along each body axis from the Python reference test, with
   -- and without measurement weights, to ensure the Ada to C to C++ integration is
   -- sound.
   overriding procedure Test (Self : in out Instance);
   -- Check the minimum norm fits with two and one lit sensors, the effect of an
   -- unavailable sensor, the residual indexing, and the no signal case against the
   -- Python reference model.
   overriding procedure Test_Partial_Coverage (Self : in out Instance);
   -- Check the body rate from two successive headings, including a slow slew, a
   -- heading reversal, and the reset connector.
   overriding procedure Test_Rate_Estimate (Self : in out Instance);
   -- Check that a parameter update changes the live fit, and that the fit weights do
   -- not carry over from a cycle with more lit sensors.
   overriding procedure Test_Reconfigure (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Css_Weighted_Least_Squares_Tests.Base_Instance with record
      null;
   end record;
end Css_Weighted_Least_Squares_Tests.Implementation;
