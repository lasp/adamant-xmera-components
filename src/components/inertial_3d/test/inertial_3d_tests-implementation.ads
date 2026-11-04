--------------------------------------------------------------------------------
-- Inertial_3d Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Inertial 3D component.
package Inertial_3d_Tests.Implementation is

   -- Test data and state:
   type Instance is new Inertial_3d_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound. The reference attitude is set as
   -- a parameter and the returned reference echoes it with zero reference rates.
   overriding procedure Test (Self : in out Instance);
   -- An updated attitude is applied on the next tick, later ticks keep it without
   -- any new update, and a new update replaces it.
   overriding procedure Test_Holds_Attitude_Between_Updates (Self : in out Instance);
   -- Ensure a non-finite attitude is refused at validation and the attitude in
   -- effect is kept.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Inertial_3d_Tests.Base_Instance with record
      null;
   end record;
end Inertial_3d_Tests.Implementation;
