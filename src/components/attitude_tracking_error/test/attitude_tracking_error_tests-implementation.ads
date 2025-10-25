--------------------------------------------------------------------------------
-- Attitude_Tracking_Error Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Attitude Tracking Error component
package Attitude_Tracking_Error_Tests.Implementation is

   -- Test data and state:
   type Instance is new Attitude_Tracking_Error_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);

   -- Test data and state:
   type Instance is new Attitude_Tracking_Error_Tests.Base_Instance with record
      null;
   end record;
end Attitude_Tracking_Error_Tests.Implementation;
