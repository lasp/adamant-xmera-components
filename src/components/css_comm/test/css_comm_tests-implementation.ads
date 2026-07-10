--------------------------------------------------------------------------------
-- Css_Comm Tests Spec
--------------------------------------------------------------------------------

-- Unit tests for the Css Comm component
package Css_Comm_Tests.Implementation is

   -- Test data and state:
   type Instance is new Css_Comm_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- With zero Chebyshev coefficients, output equals input/maxSensorValue clamped to
   -- [0, 1].
   overriding procedure Test_Zero_Cheby_Is_Identity (Self : in out Instance);

   -- When the CSS sensor data dependency is stale, the ADC input is zeroed before
   -- the algorithm runs, producing an all-zero output.
   overriding procedure Test_Stale_Input_Is_Zeroed (Self : in out Instance);

   -- Verify parameter validation rejects configs the algorithm would reject.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Css_Comm_Tests.Base_Instance with record
      null;
   end record;
end Css_Comm_Tests.Implementation;
