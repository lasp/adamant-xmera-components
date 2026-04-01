--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Nav_Att;
with Body_Rate_Fault;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Body_Rate_Fault.Assertion; use Body_Rate_Fault.Assertion;

package body Body_Rate_Miscompare_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Call component init here.
      Self.Tester.Component_Instance.Init;

      -- Call the component set up method that the assembly would normally call.
      Self.Tester.Component_Instance.Set_Up;
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      -- Free component heap:
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Body_Rate_Miscompare.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Test data based on Python test
      type Test_Vector is record
         Imu_Angular_Velocity : Packed_F32x3.T;
         St_Angular_Velocity : Packed_F32x3.T;
         Expected_Angular_Velocity : Packed_F32x3.T;
         Expected_Fault : Boolean;
      end record;

      -- Default threshold is 1.0 rad/s
      -- Test 1: Nominal - star tracker and IMU agree (diff < threshold)
      -- Test 2: Off-nominal - star tracker and IMU disagree (diff > threshold), output should be IMU rate
      Test_Cases : constant array (1 .. 2) of Test_Vector := [
         -- Nominal: ST rate close to IMU rate, output should be ST rate
         (Imu_Angular_Velocity => [-0.1, 0.2, -0.3],
          St_Angular_Velocity => [-0.09, 0.21, -0.29],
          Expected_Angular_Velocity => [-0.09, 0.21, -0.29],
          Expected_Fault => False),
         -- Off-nominal: ST rate far from IMU rate, output should be IMU rate
         (Imu_Angular_Velocity => [-0.1, 0.2, -0.3],
          St_Angular_Velocity => [1.9, 2.2, 1.7],
          Expected_Angular_Velocity => [-0.1, 0.2, -0.3],
          Expected_Fault => True)
      ];
   begin
      for I in Test_Cases'Range loop
         -- Set IMU angular velocity data dependency
         T.Imu_Body := (
            Value => Test_Cases (I).Imu_Angular_Velocity
         );

         -- Set star tracker attitude data dependency
         T.Star_Tracker_Attitude := (
            Time_Tag => 0.0,
            Mrp_Bdy_Inrtl => [0.0, 0.0, 0.0],
            Omega_Bn_B => Test_Cases (I).St_Angular_Velocity,
            Dcm_Cb => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
         );

         -- Call algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Make sure data products produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I * 2);
         Natural_Assert.Eq (T.Body_Rate_History.Get_Count, I);
         Natural_Assert.Eq (T.Rate_Fault_Status_History.Get_Count, I);

         -- Check body rate output
         declare
            Rate_Output : constant Nav_Att.T := T.Body_Rate_History.Get (I);
         begin
            Packed_F32x3_Assert.Eq (
               Rate_Output.Omega_Bn_B,
               Test_Cases (I).Expected_Angular_Velocity,
               Epsilon => 0.0001
            );
         end;

         -- Check fault status
         declare
            Fault_Output : constant Body_Rate_Fault.T := T.Rate_Fault_Status_History.Get (I);
         begin
            Body_Rate_Fault_Assert.Eq (
               Fault_Output,
               (Fault_Detected => Test_Cases (I).Expected_Fault)
            );
         end;
      end loop;
   end Test;

end Body_Rate_Miscompare_Tests.Implementation;