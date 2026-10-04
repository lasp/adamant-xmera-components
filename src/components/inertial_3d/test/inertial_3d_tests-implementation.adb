--------------------------------------------------------------------------------
-- Inertial_3d Tests Body
--------------------------------------------------------------------------------

with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Ada.Real_Time;
with Component.Inertial_3d.Implementation.Tester;
with Att_Ref;
with Tick;

package body Inertial_3d_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Request a tick and return the reference it produces.
   function Request_Tick (Self : in out Instance; Arg : in Tick.T) return Att_Ref.T is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      return T.Tick_T_Request (Arg);
   end Request_Tick;

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
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Test inputs based on Python unit test scenarios with and without a set sigma reference.
      type Test_Case is record
         Sigma_Input : Packed_F32x3.T;
      end record;

      Test_Cases : constant array (1 .. 2) of Test_Case := [
         (Sigma_Input => [0.0, 0.0, 0.0]),
         (Sigma_Input => [0.1, -0.2, 0.3])
      ];

      Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      Epsilon : constant := 1.0E-6;
   begin
      for I in Test_Cases'Range loop
         -- Provide sigma reference input for this tick.
         T.Sigma_Reference := (Value => Test_Cases (I).Sigma_Input);

         -- Trigger the component execution and check the reference it returns.
         declare
            Output : constant Att_Ref.T := Request_Tick (Self, (Time => T.System_Time, Count => 0));
         begin
            Packed_F32x3_Assert.Eq (Output.Sigma_Rn, Test_Cases (I).Sigma_Input, Epsilon => Epsilon);
            Packed_F32x3_Assert.Eq (Output.Omega_Rn_N, Zero_Vector, Epsilon => Epsilon);
            Packed_F32x3_Assert.Eq (Output.Domega_Rn_N, Zero_Vector, Epsilon => Epsilon);
         end;
      end loop;
   end Test;

   -- The reference attitude is commanded sporadically, so the component applies a
   -- fresh value and keeps the last one while the dependency comes back stale. The
   -- tester serves the product with the timestamp override, and the dependency is
   -- mapped with a one second stale limit, so a tick a few seconds past the product
   -- fetches it stale.
   overriding procedure Test_Keeps_Attitude_While_Stale (Self : in out Instance) is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
      Attitude : constant Packed_F32x3.T := [0.4, 0.5, -0.6];
      Moved : constant Packed_F32x3.T := [-0.1, 0.2, 0.3];
      Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      Epsilon : constant := 1.0E-6;
   begin
      T.Component_Instance.Map_Data_Dependencies (Sigma_Reference_Id => 0, Sigma_Reference_Stale_Limit => Ada.Real_Time.Seconds (1));

      -- A tick at the time of the product fetches it fresh and applies the attitude.
      T.Sigma_Reference := (Value => Attitude);
      T.Data_Dependency_Timestamp_Override := (Seconds => 10, Subseconds => 0);
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 10, Subseconds => 0), Count => 0)).Sigma_Rn, Attitude, Epsilon => Epsilon);

      -- A tick well past the product fetches it stale, so a moved attitude is not
      -- applied and the reference keeps the one last given.
      T.Sigma_Reference := (Value => Moved);
      declare
         Output : constant Att_Ref.T := Request_Tick (Self, (Time => (Seconds => 15, Subseconds => 0), Count => 1));
      begin
         Packed_F32x3_Assert.Eq (Output.Sigma_Rn, Attitude, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Output.Omega_Rn_N, Zero_Vector, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Output.Domega_Rn_N, Zero_Vector, Epsilon => Epsilon);
      end;

      -- Once the product is fresh again the moved attitude is applied.
      T.Data_Dependency_Timestamp_Override := (Seconds => 15, Subseconds => 0);
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 15, Subseconds => 0), Count => 2)).Sigma_Rn, Moved, Epsilon => Epsilon);
   end Test_Keeps_Attitude_While_Stale;

end Inertial_3d_Tests.Implementation;
