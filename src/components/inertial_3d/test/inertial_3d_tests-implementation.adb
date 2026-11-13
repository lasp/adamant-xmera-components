--------------------------------------------------------------------------------
-- Inertial_3d Tests Body
--------------------------------------------------------------------------------

with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Component.Inertial_3d.Implementation.Tester;
with Inertial_3d_Parameters;
with Att_Ref;
with Tick;

package body Inertial_3d_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   Epsilon : constant := 1.0E-6;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Request a tick and return the reference it produces.
   function Request_Tick (Self : in out Instance; Arg : in Tick.T) return Att_Ref.T is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      return T.Tick_T_Request (Arg);
   end Request_Tick;

   -- Stage, validate, and update the attitude.
   procedure Set_Attitude (Self : in out Instance; Attitude : in Packed_F32x3.T) is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Inertial_3d_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Rn (Attitude)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Set_Attitude;

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
      -- Free the C++ algorithm heap:
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
   begin
      for I in Test_Cases'Range loop
         -- Set the attitude to hold for this tick.
         Set_Attitude (Self, Test_Cases (I).Sigma_Input);
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

   -- The attitude to hold changes sporadically, so the component applies it on the
   -- tick after its update and keeps it over the ticks that follow until a new one
   -- arrives.
   overriding procedure Test_Holds_Attitude_Between_Updates (Self : in out Instance) is
      Attitude : constant Packed_F32x3.T := [0.4, 0.5, -0.6];
      Moved : constant Packed_F32x3.T := [-0.1, 0.2, 0.3];
   begin
      -- Before any update the reference holds the zero attitude the algorithm is
      -- built with.
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 10, Subseconds => 0), Count => 0)).Sigma_Rn, Zero_Vector, Epsilon => Epsilon);

      -- An updated attitude is applied on the next tick and returned.
      Set_Attitude (Self, Attitude);
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 11, Subseconds => 0), Count => 1)).Sigma_Rn, Attitude, Epsilon => Epsilon);

      -- Later ticks keep it without any new update.
      declare
         Output : constant Att_Ref.T := Request_Tick (Self, (Time => (Seconds => 15, Subseconds => 0), Count => 2));
      begin
         Packed_F32x3_Assert.Eq (Output.Sigma_Rn, Attitude, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Output.Omega_Rn_N, Zero_Vector, Epsilon => Epsilon);
         Packed_F32x3_Assert.Eq (Output.Domega_Rn_N, Zero_Vector, Epsilon => Epsilon);
      end;

      -- A new update replaces it.
      Set_Attitude (Self, Moved);
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => (Seconds => 16, Subseconds => 0), Count => 3)).Sigma_Rn, Moved, Epsilon => Epsilon);
   end Test_Holds_Attitude_Between_Updates;

   -- The algorithm requires a finite attitude. Validation is the only guard keeping a
   -- rejected value out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Inertial_3d.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Inertial_3d_Parameters.Instance;
      Attitude : constant Packed_F32x3.T := [0.4, 0.5, -0.6];
   begin
      -- Apply an attitude, which takes effect on the tick after its update:
      Set_Attitude (Self, Attitude);
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => T.System_Time, Count => 0)).Sigma_Rn, Attitude, Epsilon => Epsilon);

      -- A non-finite attitude is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      declare
         Par : Parameter.T := Params.Sigma_Rn (Attitude);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The attitude in effect is kept on the ticks that follow:
      Packed_F32x3_Assert.Eq (Request_Tick (Self, (Time => T.System_Time, Count => 1)).Sigma_Rn, Attitude, Epsilon => Epsilon);
   end Test_Invalid_Parameter;

end Inertial_3d_Tests.Implementation;
