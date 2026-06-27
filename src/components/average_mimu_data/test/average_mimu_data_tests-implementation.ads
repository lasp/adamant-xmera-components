--------------------------------------------------------------------------------
-- Average_Mimu_Data Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Average Mimu Data component
package Average_Mimu_Data_Tests.Implementation is

   -- Test data and state:
   type Instance is new Average_Mimu_Data_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Identity DCM and uniform data - output equals scaled input.
   overriding procedure Test_Identity_Dcm (Self : in out Instance);
   -- 90-degree Z-rotation DCM transforms the averaged result into the body frame.
   overriding procedure Test_Dcm_Rotation (Self : in out Instance);
   -- Non-uniform data with negative values averages correctly across signs.
   overriding procedure Test_Mixed_Signs (Self : in out Instance);
   -- Per-sample time windowing excludes samples older than the averaging window.
   overriding procedure Test_Time_Filtering (Self : in out Instance);
   -- A tick with nothing buffered still publishes a zero result.
   overriding procedure Test_Empty_Buffer (Self : in out Instance);
   -- Multiple packets buffered before one tick are all averaged together.
   overriding procedure Test_Multi_Packet (Self : in out Instance);
   -- A packet beyond the buffer capacity triggers the overflow event and is dropped.
   overriding procedure Test_Buffer_Overflow (Self : in out Instance);
   -- Test that an invalid parameter throws the appropriate event and out-of-range windows are rejected.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);
   -- Independent gyro and accel averaging windows select different sample sets from one packet.
   overriding procedure Test_Asymmetric_Windows (Self : in out Instance);

   -- Test data and state:
   type Instance is new Average_Mimu_Data_Tests.Base_Instance with record
      null;
   end record;
end Average_Mimu_Data_Tests.Implementation;
