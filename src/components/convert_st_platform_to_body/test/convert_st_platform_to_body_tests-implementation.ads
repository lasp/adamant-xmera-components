--------------------------------------------------------------------------------
-- Convert_St_Platform_To_Body Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Convert St Platform To Body component
package Convert_St_Platform_To_Body_Tests.Implementation is

   -- Test data and state:
   type Instance is new Convert_St_Platform_To_Body_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound, and check the output is stamped
   -- with the timestamp of the attitude solution.
   overriding procedure Test (Self : in out Instance);

   -- Ensure a staged mounting attitude the algorithm would reject is refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Convert_St_Platform_To_Body_Tests.Base_Instance with record
      null;
   end record;
end Convert_St_Platform_To_Body_Tests.Implementation;
