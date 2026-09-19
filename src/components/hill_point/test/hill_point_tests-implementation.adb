--------------------------------------------------------------------------------
-- Hill_Point Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Att_Ref;
with Att_Ref.Assertion; use Att_Ref.Assertion;
with Cartesian_State;
with Packed_F64x3;

package body Hill_Point_Tests.Implementation is

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
      -- Free the C++ algorithm heap:
      Self.Tester.Component_Instance.Destroy;
      -- Free component heap:
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run the algorithm to ensure the Ada to C to C++ integration is sound. The
   -- inputs follow the Python reference test (_tests/test_hillPoint.py): a circular
   -- equatorial orbit at 2.8 Earth radii and a true anomaly of 60 degrees. The Hill
   -- frame is then rotated 60 degrees about the orbit normal, so the reference MRP is
   -- [0, 0, tan (15 deg)] and the reference rate is the orbit mean motion about the
   -- same axis. A circular orbit has no reference acceleration. The Python test runs
   -- the case with the primary body at the origin and with it offset to a heliocentric
   -- state, expecting the same output; the third case checks the algorithm's
   -- degenerate fallback, where a zero relative velocity yields an all-zero reference.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Hill_Point.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Spacecraft state relative to the primary body, in meters and meters per second.
      Orbit_Position : constant Packed_F64x3.T := [8_929_391.24, 15_466_159.30834046, 0.0];
      Orbit_Velocity : constant Packed_F64x3.T := [-4_091.41558928, 2_362.17989184, 0.0];
      Zero_Vector : constant Packed_F64x3.T := [0.0, 0.0, 0.0];

      -- Heliocentric state of the primary body for the offset case.
      Body_Position : constant Packed_F64x3.T := [1.5E11, 0.0, 0.0];
      Body_Velocity : constant Packed_F64x3.T := [0.0, 29_800.0, 0.0];

      Expected_Reference : constant Att_Ref.T := (
         Sigma_Rn => [0.0, 0.0, 0.267949192431],
         Omega_Rn_N => [0.0, 0.0, 0.000264539877],
         Domega_Rn_N => [0.0, 0.0, 0.0]
      );
      Zero_Reference : constant Att_Ref.T := (
         Sigma_Rn => [0.0, 0.0, 0.0],
         Omega_Rn_N => [0.0, 0.0, 0.0],
         Domega_Rn_N => [0.0, 0.0, 0.0]
      );

      type Test_Vector is record
         Spacecraft : Cartesian_State.T;
         Primary_Body : Cartesian_State.T;
         Expected : Att_Ref.T;
      end record;

      Test_Cases : constant array (1 .. 3) of Test_Vector := [
         -- Primary body at the inertial origin:
         (Spacecraft => (Position => Orbit_Position, Velocity => Orbit_Velocity),
          Primary_Body => (Position => Zero_Vector, Velocity => Zero_Vector),
          Expected => Expected_Reference),
         -- Primary body on a heliocentric orbit, spacecraft state given inertially:
         (Spacecraft => (Position => [1.5E11 + 8_929_391.24, 15_466_159.30834046, 0.0],
                         Velocity => [-4_091.41558928, 29_800.0 + 2_362.17989184, 0.0]),
          Primary_Body => (Position => Body_Position, Velocity => Body_Velocity),
          Expected => Expected_Reference),
         -- Degenerate geometry, zero relative velocity:
         (Spacecraft => (Position => Orbit_Position, Velocity => Zero_Vector),
          Primary_Body => (Position => Zero_Vector, Velocity => Zero_Vector),
          Expected => Zero_Reference)
      ];
   begin
      for I in Test_Cases'Range loop
         -- Set the data dependencies for this case:
         T.Spacecraft_State := Test_Cases (I).Spacecraft;
         T.Primary_Body_State := Test_Cases (I).Primary_Body;

         -- Send tick to trigger the algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Verify output was produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, I);

         -- Check output matches expected values:
         Att_Ref_Assert.Eq (T.Attitude_Reference_History.Get (I), Test_Cases (I).Expected, Epsilon => 1.0E-6);
      end loop;
   end Test;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Hill_Point.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Hill_Point_Tests.Implementation;
