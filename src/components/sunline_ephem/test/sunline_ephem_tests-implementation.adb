--------------------------------------------------------------------------------
-- Sunline_Ephem Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Packed_F64x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;

package body Sunline_Ephem_Tests.Implementation is

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
      T : Component.Sunline_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Test data based on the Python test: the sun at the origin, the spacecraft
      -- a unit length away on each axis, and an attitude that makes the inertial and
      -- body frame directions differ. The body frame truth is the inertial truth
      -- rotated by [BN] for sigma_BN = [0.1, 0.2, -0.3].
      type Test_Vector is record
         Sc_Position : Packed_F64x3.T;  -- Spacecraft position
         Expected_Sunline_N : Packed_F32x3.T;  -- Expected sunline direction, inertial frame
         Expected_Sunline_B : Packed_F32x3.T;  -- Expected sunline direction, body frame
      end record;

      Bn_X : constant Packed_F32x3.T := [0.1997538, 0.9172053, 0.3447215];
      Bn_Y : constant Packed_F32x3.T := [-0.6709757, 0.3844260, -0.6340412];
      Bn_Z : constant Packed_F32x3.T := [-0.7140659, -0.1046476, 0.6922130];

      Test_Cases : constant array (1 .. 7) of Test_Vector := [
         (Sc_Position => [-1.0, 0.0, 0.0], Expected_Sunline_N => [1.0, 0.0, 0.0], Expected_Sunline_B => Bn_X),
         (Sc_Position => [0.0, -1.0, 0.0], Expected_Sunline_N => [0.0, 1.0, 0.0], Expected_Sunline_B => Bn_Y),
         (Sc_Position => [0.0, 0.0, -1.0], Expected_Sunline_N => [0.0, 0.0, 1.0], Expected_Sunline_B => Bn_Z),
         (Sc_Position => [1.0, 0.0, 0.0], Expected_Sunline_N => [-1.0, 0.0, 0.0],
          Expected_Sunline_B => [-Bn_X (0), -Bn_X (1), -Bn_X (2)]),
         (Sc_Position => [0.0, 1.0, 0.0], Expected_Sunline_N => [0.0, -1.0, 0.0],
          Expected_Sunline_B => [-Bn_Y (0), -Bn_Y (1), -Bn_Y (2)]),
         (Sc_Position => [0.0, 0.0, 1.0], Expected_Sunline_N => [0.0, 0.0, -1.0],
          Expected_Sunline_B => [-Bn_Z (0), -Bn_Z (1), -Bn_Z (2)]),
         -- Degenerate case:
         (Sc_Position => [0.0, 0.0, 0.0], Expected_Sunline_N => [0.0, 0.0, 0.0], Expected_Sunline_B => [0.0, 0.0, 0.0])
      ];
   begin
      -- Run each test case
      for I in Test_Cases'Range loop
         -- Set sun Cartesian state at origin. Only position is used by the
         -- algorithm; velocity is carried for type consistency with upstream
         -- Oe_State_Ephem / Ephemerides_Recenter producers.
         T.Sun_Ephemeris := (
            Position => [0.0, 0.0, 0.0],
            Velocity => [0.0, 0.0, 0.0]
         );

         -- Set spacecraft position to test vector.
         T.Spacecraft_Position := (
            Position => Test_Cases (I).Sc_Position,
            Velocity => [0.0, 0.0, 0.0]
         );

         -- Set the spacecraft attitude. Only sigma_BN is used by the algorithm.
         T.Spacecraft_Attitude := (
            Time_Tag => 0.0,
            Sigma_Bn => [0.1, 0.2, -0.3],
            Omega_Bn_B => [0.0, 0.0, 0.0],
            Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]
         );

         -- Call algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Make sure both data products are produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 2 * I);
         Natural_Assert.Eq (T.Sunline_Inertial_Frame_History.Get_Count, I);
         Natural_Assert.Eq (T.Sunline_Body_Frame_History.Get_Count, I);

         -- Check the sunline outputs in both frames.
         Packed_F32x3_Assert.Eq (
            T.Sunline_Inertial_Frame_History.Get (I),
            Test_Cases (I).Expected_Sunline_N,
            Epsilon => 0.0001
         );
         Packed_F32x3_Assert.Eq (
            T.Sunline_Body_Frame_History.Get (I),
            Test_Cases (I).Expected_Sunline_B,
            Epsilon => 0.0001
         );
      end loop;
   end Test;

end Sunline_Ephem_Tests.Implementation;
