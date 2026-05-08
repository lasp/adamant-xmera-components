--------------------------------------------------------------------------------
-- Ephemerides_Recenter Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Ephemerides Recenter component
package Ephemerides_Recenter_Tests.Implementation is

   -- Test data and state:
   type Instance is new Ephemerides_Recenter_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);

   -- Test data and state:
   type Instance is new Ephemerides_Recenter_Tests.Base_Instance with record
      null;
   end record;
end Ephemerides_Recenter_Tests.Implementation;
