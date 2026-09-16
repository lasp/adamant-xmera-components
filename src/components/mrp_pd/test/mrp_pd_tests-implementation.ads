--------------------------------------------------------------------------------
-- Mrp_Pd Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Mrp Pd component
package Mrp_Pd_Tests.Implementation is

   -- Test data and state:
   type Instance is new Mrp_Pd_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a staged configuration the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Mrp_Pd_Tests.Base_Instance with record
      null;
   end record;
end Mrp_Pd_Tests.Implementation;
