--------------------------------------------------------------------------------
-- Dv_Maneuver Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Dv Maneuver component
package Dv_Maneuver_Tests.Implementation is
   -- Test data and state:
   type Instance is new Dv_Maneuver_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run the burn of the algorithm's Python reference test, with the delta-V
   -- accumulating at a constant rate, and check the force command and the burn state
   -- on every tick until the commanded delta-V completes the burn, to ensure the Ada
   -- to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure the minimum burn time holds a burn whose delta-V is reached early, and
   -- the maximum burn time ends one whose delta-V is never reached.
   overriding procedure Test_Time_Limits (Self : in out Instance);
   -- Ensure a complete burn stays complete, through a new burn as well, until the
   -- reset starts a new one.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure staged burn times the algorithm would reject are refused at validation
   -- and leave the previous burn in place.
   overriding procedure Test_Invalid_Burn (Self : in out Instance);
   -- Ensure a staged body force the algorithm would reject is refused at validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier fails an assertion and
   -- nothing is published.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Dv_Maneuver_Tests.Base_Instance with record
      null;
   end record;
end Dv_Maneuver_Tests.Implementation;
