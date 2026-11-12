--------------------------------------------------------------------------------
-- Dv_Accumulation Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Dv Accumulation component
package Dv_Accumulation_Tests.Implementation is
   -- Test data and state:
   type Instance is new Dv_Accumulation_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Feed a constant acceleration and check the accumulated delta-V grows by the
   -- acceleration times the control period on each tick after the first, which
   -- starts the window, to ensure the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Ensure the accelerometer bias the state manager publishes is subtracted from
   -- each sample.
   overriding procedure Test_Bias (Self : in out Instance);
   -- Ensure a bias that is stale, since it is published once when the burn is set
   -- up, is subtracted from each sample like a fresh one.
   overriding procedure Test_Stale_Bias (Self : in out Instance);
   -- Ensure the reset connector zeroes the accumulated delta-V and the next sample
   -- starts a new window without being integrated.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Ensure a data dependency with the wrong identifier fails an assertion and
   -- nothing is published.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance);

   -- Test data and state:
   type Instance is new Dv_Accumulation_Tests.Base_Instance with record
      null;
   end record;
end Dv_Accumulation_Tests.Implementation;
