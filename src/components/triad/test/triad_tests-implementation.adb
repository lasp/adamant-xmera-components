--------------------------------------------------------------------------------
-- Triad Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Att_Ref.Assertion; use Att_Ref.Assertion;
with Packed_F32x3;
with Packed_N3_Axis;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Triad_Enums; use Triad_Enums;
with Triad_Parameters;

package body Triad_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Axes and directions from the Python reference test (_tests/test_triad.py). The
   -- sun and earth directions there are normalized position vectors; the unit vectors
   -- are used directly here.
   Sada_Axis : constant Packed_F32x3.T := [1.0, 0.0, 0.0];
   Thrust_Body : constant Packed_F32x3.T := [0.0, 1.0, 0.0];
   -- Sun to probe angle below 90 degrees.
   Sun_A : constant Packed_F32x3.T := [0.7067497544, 0.7074636278, 0.0];
   Earth_A : constant Packed_F32x3.T := [0.7772755531, 0.6259869915, 0.0631110211];
   -- Sun to probe angle above 90 degrees.
   Sun_B : constant Packed_F32x3.T := [-0.9999917806, -0.0040544759, 0.0];
   Earth_B : constant Packed_F32x3.T := [0.6295314680, 0.7123448335, 0.3102498493];
   Plus_Z : constant Packed_N3_Axis.T := (Value => N3_Axis.Plus_Z_Hat_N);
   Minus_Z : constant Packed_N3_Axis.T := (Value => N3_Axis.Minus_Z_Hat_N);

   -- The reference attitudes are computed in double precision; the single precision
   -- triad agrees to a few parts in a million.
   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply a configuration. The solar array drive axis is the same in every
   -- case.
   procedure Apply_Configuration (Self : in out Instance; Thrust_Req_N : in Packed_F32x3.T; Fallback_Axis : in Packed_N3_Axis.T) is
      T : Component.Triad.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Triad_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sada_Hat_B (Sada_Axis)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Req_Hat_N (Thrust_Req_N)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.N3_Axis (Fallback_Axis)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the given directions and check the published reference attitude.
   -- The rate and acceleration are always zero.
   procedure Send_Tick_And_Check (
      Self : in out Instance;
      Tick_Number : in Natural;
      Sun_N : in Packed_F32x3.T;
      Thrust_B : in Packed_F32x3.T;
      Expected_Sigma_Rn : in Packed_F32x3.T
   ) is
      T : Component.Triad.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Sun_Direction_Inertial := Sun_N;
      T.Thrust_Direction_Body := Thrust_B;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, Tick_Number);
      Att_Ref_Assert.Eq
        (T.Attitude_Reference_History.Get (Tick_Number),
         (Sigma_Rn => Expected_Sigma_Rn, Omega_Rn_N => [0.0, 0.0, 0.0], Domega_Rn_N => [0.0, 0.0, 0.0]),
         Epsilon => Epsilon);
   end Send_Tick_And_Check;

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

   -- Run the algorithm on the input sets of the Python reference test to ensure the
   -- Ada to C to C++ integration is sound. The expected attitudes are computed
   -- independently from the triad construction of the reference model: in each the
   -- body thrust direction maps onto the requested inertial direction and the drive
   -- axis is orthogonal to the sun.
   overriding procedure Test (Self : in out Instance) is
   begin
      -- Sun to probe angle below 90 degrees:
      Apply_Configuration (Self, Thrust_Req_N => Earth_A, Fallback_Axis => Plus_Z);
      Send_Tick_And_Check (Self, 1, Sun_A, Thrust_Body, [0.1340293018, 0.2445811641, -0.2012511038]);

      -- Sun to probe angle above 90 degrees:
      Apply_Configuration (Self, Thrust_Req_N => Earth_B, Fallback_Axis => Plus_Z);
      Send_Tick_And_Check (Self, 2, Sun_B, Thrust_Body, [0.2289772991, 0.4373198849, -0.0591493951]);
   end Test;

   -- Check the fallback constraint axis when the sun is parallel to the requested thrust
   -- direction, and the zero attitude when the triad cannot be formed.
   overriding procedure Test_Degenerate_Geometry (Self : in out Instance) is
   begin
      -- With the sun along the requested thrust direction the triad is completed with
      -- the configured inertial z axis instead:
      Apply_Configuration (Self, Thrust_Req_N => Earth_A, Fallback_Axis => Plus_Z);
      Send_Tick_And_Check (Self, 1, Earth_A, Thrust_Body, [-0.1750657677, -0.3975377473, -0.1998057895]);
      Apply_Configuration (Self, Thrust_Req_N => Earth_A, Fallback_Axis => Minus_Z);
      Send_Tick_And_Check (Self, 2, Earth_A, Thrust_Body, [0.1974675631, 0.3811830676, -0.1730170613]);

      -- A thrust direction along the drive axis leaves no triad to form, so the
      -- reference attitude is zero:
      Send_Tick_And_Check (Self, 3, Sun_A, Sada_Axis, [0.0, 0.0, 0.0]);
   end Test_Degenerate_Geometry;

   -- The algorithm requires unit drive and requested thrust axes. Validation is the only
   -- guard keeping a rejected value out of the throwing Set_Config, so exercise it
   -- directly. An undefined fallback axis code is an invalid enumeration, which staging
   -- rejects before validation runs.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Triad.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Triad_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sada_Hat_B (Sada_Axis)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Req_Hat_N (Earth_A)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.N3_Axis (Plus_Z)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A drive axis that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sada_Hat_B ([2.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A requested thrust direction that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Thrust_Req_Hat_N ([0.5, 0.5, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite drive axis is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Sada_Hat_B (Sada_Axis);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- An undefined fallback axis code is rejected at staging by type validation:
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.N3_Axis (Plus_Z);
      begin
         Par.Buffer (Par.Buffer'First) := 2;
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Validation_Error);
      end;

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Triad.Implementation.Tester.Instance_Access renames Self.Tester;
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

end Triad_Tests.Implementation;
