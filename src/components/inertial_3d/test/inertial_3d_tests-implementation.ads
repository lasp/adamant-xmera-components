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

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- A non-finite reference MRP survives parameter staging but is refused by
   -- Validate_Parameters, keeping it out of the throwing Set_Config.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Inertial_3d_Tests.Base_Instance with record
      null;
   end record;
end Inertial_3d_Tests.Implementation;
