--------------------------------------------------------------------------------
-- Oe_State_Ephem Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the OE State Ephem component
package Oe_State_Ephem_Tests.Implementation is

   -- Test data and state:
   type Instance is new Oe_State_Ephem_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Zero coefficients and zero gravitational parameter must produce zero Cartesian state.
   overriding procedure Test_Zero_Inputs (Self : in out Instance);

   -- Test data and state:
   type Instance is new Oe_State_Ephem_Tests.Base_Instance with record
      null;
   end record;
end Oe_State_Ephem_Tests.Implementation;
