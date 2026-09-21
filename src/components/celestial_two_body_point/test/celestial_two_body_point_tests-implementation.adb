--------------------------------------------------------------------------------
-- Celestial_Two_Body_Point Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Att_Ref;
with Att_Ref.Assertion; use Att_Ref.Assertion;
with Cartesian_State;
with Celestial_Two_Body_Point_Parameters;
with Packed_F32;
with Packed_F64x3;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Celestial_Two_Body_Point_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The geometry of the Python reference test (_tests/test_celestialTwoBodyPoint.py):
   -- the primary body sits at the state of a circular equatorial orbit at 2.8 Earth
   -- radii and 60 degrees true anomaly, the secondary body is nearby off the orbit
   -- plane, and the spacecraft is at the inertial origin. The expected reference was
   -- evaluated with the reference model in that test.
   Primary_Position : constant Packed_F64x3.T := [8_929_391.24, 15_466_159.30834046, 0.0];
   Primary_Velocity : constant Packed_F64x3.T := [-4_091.41558928, 2_362.17989184, 0.0];
   Secondary_Position : constant Packed_F64x3.T := [500.0, 500.0, 500.0];
   Secondary_Velocity : constant Packed_F64x3.T := [100.0, -10.0, 20.0];
   Zero_Vector : constant Packed_F64x3.T := [0.0, 0.0, 0.0];

   Expected_Reference : constant Att_Ref.T := (
      Sigma_Rn => [0.474475084038, 0.273938317493, 0.191443718765],
      Omega_Rn_N => [0.074483781795, 0.129009694409, 0.000264539858],
      Domega_Rn_N => [-0.014107942863, -0.024290245594, -0.019199756471]
   );
   Zero_Reference : constant Att_Ref.T := (
      Sigma_Rn => [0.0, 0.0, 0.0],
      Omega_Rn_N => [0.0, 0.0, 0.0],
      Domega_Rn_N => [0.0, 0.0, 0.0]
   );

   -- One degree, as in the reference test.
   Alignment_Threshold : constant Packed_F32.T := (Value => 0.017453292);

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

   -- Run the geometry of the Python reference test to ensure the Ada to C to C++
   -- integration is sound. The second case shifts every state by the same offset,
   -- which must not change the reference, and the third puts the primary body at the
   -- spacecraft, which is degenerate and yields an all-zero reference.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Celestial_Two_Body_Point.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Celestial_Two_Body_Point_Parameters.Instance;

      type Test_Vector is record
         Primary : Cartesian_State.T;
         Secondary : Cartesian_State.T;
         Spacecraft : Cartesian_State.T;
         Expected : Att_Ref.T;
      end record;

      Test_Cases : constant array (1 .. 3) of Test_Vector := [
         -- The reference geometry:
         (Primary => (Position => Primary_Position, Velocity => Primary_Velocity),
          Secondary => (Position => Secondary_Position, Velocity => Secondary_Velocity),
          Spacecraft => (Position => Zero_Vector, Velocity => Zero_Vector),
          Expected => Expected_Reference),
         -- The same geometry with every state shifted by the same position and velocity:
         (Primary => (Position => [9_929_391.24, 17_466_159.30834046, 3_000_000.0],
                      Velocity => [-4_081.41558928, 2_382.17989184, 30.0]),
          Secondary => (Position => [1_000_500.0, 2_000_500.0, 3_000_500.0], Velocity => [110.0, 10.0, 50.0]),
          Spacecraft => (Position => [1.0E6, 2.0E6, 3.0E6], Velocity => [10.0, 20.0, 30.0]),
          Expected => Expected_Reference),
         -- The primary body at the spacecraft position:
         (Primary => (Position => Zero_Vector, Velocity => Primary_Velocity),
          Secondary => (Position => Secondary_Position, Velocity => Secondary_Velocity),
          Spacecraft => (Position => Zero_Vector, Velocity => Zero_Vector),
          Expected => Zero_Reference)
      ];
   begin
      -- Apply the alignment threshold of the reference test:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold (Alignment_Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      for I in Test_Cases'Range loop
         -- Set the data dependencies for this case:
         T.Primary_Body_State := Test_Cases (I).Primary;
         T.Secondary_Body_State := Test_Cases (I).Secondary;
         T.Spacecraft_State := Test_Cases (I).Spacecraft;

         -- Send tick to trigger the algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Verify output was produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, I);

         -- Check output matches expected values:
         Att_Ref_Assert.Eq (T.Attitude_Reference_History.Get (I), Test_Cases (I).Expected, Epsilon => 1.0E-5);
      end loop;
   end Test;

   -- The algorithm requires an alignment threshold between 1e-6 and pi/2 radians.
   -- Validation is the only guard keeping a rejected value out of the throwing
   -- Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Celestial_Two_Body_Point.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Celestial_Two_Body_Point_Parameters.Instance;
   begin
      -- The reference threshold is accepted:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold (Alignment_Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A threshold of zero is rejected:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A threshold beyond 90 degrees is rejected:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold ((Value => 1.6))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative threshold is rejected:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold ((Value => -0.1))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring the reference threshold makes it acceptable again:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Alignment_Threshold (Alignment_Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Celestial_Two_Body_Point.Implementation.Tester.Instance_Access renames Self.Tester;
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

end Celestial_Two_Body_Point_Tests.Implementation;
