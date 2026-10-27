--------------------------------------------------------------------------------
-- Momentum_Management Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Momentum Management component
package Momentum_Management_Tests.Implementation is

   -- Test data and state:
   type Instance is new Momentum_Management_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the algorithm through the integral accumulation and reset sequence to
   -- ensure the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Check the threshold, the dumpable projection, the desired momentum, and the
   -- wheel availability options against the Python reference model.
   overriding procedure Test_Dumping_Variants (Self : in out Instance);
   -- Ensure a parameter update takes effect on the next tick and keeps the integral
   -- state.
   overriding procedure Test_Parameter_Update (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier is treated as a wiring
   -- defect and fails the tick's assertion.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Momentum_Management_Tests.Base_Instance with record
      null;
   end record;
end Momentum_Management_Tests.Implementation;
