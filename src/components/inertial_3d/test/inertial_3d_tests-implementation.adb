--------------------------------------------------------------------------------
-- Inertial_3d Tests Body
--------------------------------------------------------------------------------

with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
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
         -- Send the attitude to hold for this tick.
         T.Attitude_T_Send ((Value => Test_Cases (I).Sigma_Input));

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

   -- The attitude to hold is commanded sporadically, so the component applies it
   -- on receipt and keeps it over the ticks that follow until a new one arrives.
   overriding procedure Test_Holds_Attitude_Between_Commands (Self : in out Instance) is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
      Attitude : constant Packed_F32x3.T := [0.4, 0.5, -0.6];
      Moved : constant Packed_F32x3.T := [-0.1, 0.2, 0.3];
      Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
      Epsilon : constant := 1.0E-6;
   begin
      -- Before any command the reference holds the zero attitude the algorithm is
      -- built with.
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 10, Subseconds => 0), Count => 0)).Sigma_Rn, Zero_Vector, Epsilon => Epsilon);

      -- A commanded attitude is applied on receipt and returned on the next tick.
      T.Attitude_T_Send ((Value => Attitude));
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 11, Subseconds => 0), Count => 1)).Sigma_Rn, Attitude, Epsilon => Epsilon);

      -- Later ticks keep it without any new command.
      declare
         Output : constant Att_Ref.T := Request_Tick (Self, (Time => (Seconds => 15, Subseconds => 0), Count => 2));
      begin
         Packed_F32x3_Assert.Eq (Output.Sigma_Rn, Attitude, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Output.Omega_Rn_N, Zero_Vector, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Output.Domega_Rn_N, Zero_Vector, Epsilon => Epsilon);
      end;

      -- A new command replaces it.
      T.Attitude_T_Send ((Value => Moved));
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 16, Subseconds => 0), Count => 3)).Sigma_Rn, Moved, Epsilon => Epsilon);
   end Test_Holds_Attitude_Between_Commands;

end Inertial_3d_Tests.Implementation;
