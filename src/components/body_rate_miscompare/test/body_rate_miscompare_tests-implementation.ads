--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Body Rate Miscompare component
package Body_Rate_Miscompare_Tests.Implementation is

   -- Test data and state:
   type Instance is new Body_Rate_Miscompare_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance);
   -- Verify the Use_Imu_Rates command forces and releases IMU-rate output and
   -- reports the new setting.
   overriding procedure Test_Use_Imu_Rates_Command (Self : in out Instance);
   -- Verify the reset connector clears the algorithm's fault persistence counter.
   overriding procedure Test_Reset (Self : in out Instance);
   -- Verify fault flag transitions publish the latch-time data product and
   -- latched/cleared events exactly once per transition, for both the miscompare
   -- latch and the commanded override.
   overriding procedure Test_Fault_Latch_Transition (Self : in out Instance);
   -- Verify a malformed command is rejected and reported via the
   -- Invalid_Command_Received event.
   overriding procedure Test_Invalid_Command (Self : in out Instance);

   -- Test data and state:
   type Instance is new Body_Rate_Miscompare_Tests.Base_Instance with record
      null;
   end record;
end Body_Rate_Miscompare_Tests.Implementation;
