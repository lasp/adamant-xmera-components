--------------------------------------------------------------------------------
-- Sun_Search_Point Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Sun Search Point component
package Sun_Search_Point_Tests.Implementation is

   -- Test data and state:
   type Instance is new Sun_Search_Point_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the search phase to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Verify the search phase transitions to pointing once the observation count
   -- reaches the threshold after the first rotation.
   overriding procedure Test_Search_To_Point_Transition (Self : in out Instance);
   -- Verify the full rotation sequence elapsing without acquiring the sun forces
   -- pointing and latches the search-failure flag.
   overriding procedure Test_Forced_Transition_Sets_Fault (Self : in out Instance);
   -- Verify the reset connector re-arms the search sequence after the terminal
   -- pointing phase.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure staged parameter values the algorithm would reject are refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Sun_Search_Point_Tests.Base_Instance with record
      null;
   end record;
end Sun_Search_Point_Tests.Implementation;
