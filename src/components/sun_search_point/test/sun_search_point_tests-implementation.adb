--------------------------------------------------------------------------------
-- Sun_Search_Point Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Basic_Assertions; use Basic_Assertions;
with Packed_U32;
with Parameter;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Packed_Boolean.Assertion; use Packed_Boolean.Assertion;
with Rotation_Properties_X4_Record;
with Sun_Search_Point_Enums; use Sun_Search_Point_Enums;
with Sun_Search_Point_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Sun_Search_Point_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Each rotation runs for one second about a different axis, so the active
   -- rotation is identifiable from the published Omega_Rn_B alone.
   Test_Rotations : constant Rotation_Properties_X4_Record.T :=
      (Rotations => [
         (Rotation_Duration => 1.0, Rotation_Rate =>  0.1, Rotation_Axis => Body_Axis.B1_Hat_B),
         (Rotation_Duration => 1.0, Rotation_Rate => -0.2, Rotation_Axis => Body_Axis.B2_Hat_B),
         (Rotation_Duration => 1.0, Rotation_Rate =>  0.3, Rotation_Axis => Body_Axis.B3_Hat_B),
         (Rotation_Duration => 1.0, Rotation_Rate =>  0.4, Rotation_Axis => Body_Axis.B1_Hat_B)
      ]);

   -- The commanded body vector, and the sun direction the tests report. They are
   -- aligned, so the pointing phase produces a zero attitude error and, with a zero
   -- spin rate, a zero reference rate. The search phase is then the only phase that
   -- publishes a non-zero Omega_Rn_B, which is what the tests key on.
   Test_S_Hat_Bdy_Cmd : constant Packed_F32x3.T := [0.0, 0.0, 1.0];

   -- Body rate reported by the filter state dependency.
   Test_Omega_Bn_B : constant Packed_F32x3.T := [0.05, 0.06, 0.07];

   -- Half-second control period against one-second rotations: two ticks per rotation,
   -- and the whole four-second sequence elapses on the ninth tick.
   Test_Control_Period : constant Packed_F32.T := (Value => 0.5);
   Test_Observation_Threshold : constant Packed_U32.T := (Value => 4);

   Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];

   -- Reference rate commanded by each rotation, in tick order.
   Expected_Search_Omega_Rn_B : constant array (1 .. 8) of Packed_F32x3.T := [
      [0.1, 0.0, 0.0], [0.1, 0.0, 0.0],
      [0.0, -0.2, 0.0], [0.0, -0.2, 0.0],
      [0.0, 0.0, 0.3], [0.0, 0.0, 0.3],
      [0.4, 0.0, 0.0], [0.4, 0.0, 0.0]
   ];

   Epsilon : constant Long_Float := 0.0001;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply the full test configuration. Every test starts from this set so
   -- that a later rejection can only come from a value the test itself perturbed.
   procedure Apply_Test_Parameters (Self : in out Instance) is
      T : Component.Sun_Search_Point.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Sun_Search_Point_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rotations (Test_Rotations)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.S_Hat_Bdy_Cmd (Test_S_Hat_Bdy_Cmd)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sun_Axis_Spin_Rate ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Rn_B_Cfg (Zero_Vector)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Observation_Threshold (Test_Observation_Threshold)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Test_Control_Period)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Test_Parameters;

   -- Report the given observation count and the aligned sun direction, then tick once.
   procedure Tick_With (Self : in out Instance; Num_Css_Viewing_Sun : in Unsigned_32) is
      T : Component.Sun_Search_Point.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Omega_Bn_B := Test_Omega_Bn_B;
      T.R_Hat_Sb_B := Test_S_Hat_Bdy_Cmd;
      T.Num_Css_Viewing_Sun := (Value => Num_Css_Viewing_Sun);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Tick_With;

   -- The body rate error the algorithm must produce for a given reference rate.
   function Expected_Omega_Br_B (Omega_Rn_B : in Packed_F32x3.T) return Packed_F32x3.T is
      ([for I in Omega_Rn_B'Range => Test_Omega_Bn_B (I) - Omega_Rn_B (I)]);

   -- Assert the outputs of the most recent tick.
   procedure Assert_Latest_Output (
      Self : in out Instance;
      Tick_Number : in Natural;
      Omega_Rn_B : in Packed_F32x3.T;
      Fault_Detected : in Boolean
   ) is
      T : Component.Sun_Search_Point.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Every tick publishes all four data products.
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number * 4);
      Natural_Assert.Eq (T.Omega_Rn_B_History.Get_Count, Tick_Number);

      -- The sun is aligned with the commanded body vector, so the attitude error is
      -- zero in both phases.
      Packed_F32x3_Assert.Eq (T.Sigma_Br_History.Get (Tick_Number), Zero_Vector, Epsilon => Epsilon);
      Packed_F32x3_Assert.Eq (T.Omega_Rn_B_History.Get (Tick_Number), Omega_Rn_B, Epsilon => Epsilon);
      Packed_F32x3_Assert.Eq (T.Omega_Br_B_History.Get (Tick_Number), Expected_Omega_Br_B (Omega_Rn_B), Epsilon => Epsilon);
      Packed_Boolean_Assert.Eq (T.Fault_Detected_History.Get (Tick_Number), (Value => Fault_Detected));
   end Assert_Latest_Output;

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

   -- Run the search phase to ensure integration is sound.
   overriding procedure Test (Self : in out Instance) is
   begin
      Apply_Test_Parameters (Self);

      -- With no sensor observing the sun, the search runs the whole sequence. Each
      -- rotation commands its own axis and rate for two ticks.
      for I in Expected_Search_Omega_Rn_B'Range loop
         Tick_With (Self, Num_Css_Viewing_Sun => 0);
         Assert_Latest_Output (Self, Tick_Number => I,
            Omega_Rn_B => Expected_Search_Omega_Rn_B (I), Fault_Detected => False);
      end loop;
   end Test;

   -- Verify the search phase transitions to pointing once the observation count
   -- reaches the threshold after the first rotation.
   overriding procedure Test_Search_To_Point_Transition (Self : in out Instance) is
   begin
      Apply_Test_Parameters (Self);

      -- The first rotation always runs to completion, so the observation count is
      -- ignored until it has elapsed.
      Tick_With (Self, Num_Css_Viewing_Sun => 4);
      Assert_Latest_Output (Self, Tick_Number => 1, Omega_Rn_B => [0.1, 0.0, 0.0], Fault_Detected => False);
      Tick_With (Self, Num_Css_Viewing_Sun => 4);
      Assert_Latest_Output (Self, Tick_Number => 2, Omega_Rn_B => [0.1, 0.0, 0.0], Fault_Detected => False);

      -- Third tick: the first rotation has elapsed and the count is at the threshold,
      -- so the sun is acquired and pointing takes over. Pointing at an aligned sun
      -- with a zero spin rate commands a zero reference rate.
      Tick_With (Self, Num_Css_Viewing_Sun => 4);
      Assert_Latest_Output (Self, Tick_Number => 3, Omega_Rn_B => Zero_Vector, Fault_Detected => False);

      -- Pointing is terminal: losing the observations does not return to the search.
      Tick_With (Self, Num_Css_Viewing_Sun => 0);
      Assert_Latest_Output (Self, Tick_Number => 4, Omega_Rn_B => Zero_Vector, Fault_Detected => False);
   end Test_Search_To_Point_Transition;

   -- Verify the full rotation sequence elapsing without acquiring the sun forces
   -- pointing and latches the search-failure flag.
   overriding procedure Test_Forced_Transition_Sets_Fault (Self : in out Instance) is
   begin
      Apply_Test_Parameters (Self);

      -- Eight ticks cover the four-second sequence, all still searching.
      for I in Expected_Search_Omega_Rn_B'Range loop
         Tick_With (Self, Num_Css_Viewing_Sun => 0);
         Assert_Latest_Output (Self, Tick_Number => I,
            Omega_Rn_B => Expected_Search_Omega_Rn_B (I), Fault_Detected => False);
      end loop;

      -- Ninth tick: the sequence has elapsed without acquiring the sun, so pointing is
      -- forced and the failure latches.
      Tick_With (Self, Num_Css_Viewing_Sun => 0);
      Assert_Latest_Output (Self, Tick_Number => 9, Omega_Rn_B => Zero_Vector, Fault_Detected => True);

      -- The latch holds.
      Tick_With (Self, Num_Css_Viewing_Sun => 0);
      Assert_Latest_Output (Self, Tick_Number => 10, Omega_Rn_B => Zero_Vector, Fault_Detected => True);
   end Test_Forced_Transition_Sets_Fault;

   -- Verify the reset connector re-arms the search sequence after the terminal
   -- pointing phase.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Sun_Search_Point.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Apply_Test_Parameters (Self);

      -- Drive the sequence out without acquiring the sun, landing in pointing with the
      -- failure latched.
      for I in 1 .. 9 loop
         Tick_With (Self, Num_Css_Viewing_Sun => 0);
      end loop;
      Assert_Latest_Output (Self, Tick_Number => 9, Omega_Rn_B => Zero_Vector, Fault_Detected => True);

      -- The reset connector re-arms the state machine, so the next tick is back at the
      -- first rotation with the failure cleared.
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Tick_With (Self, Num_Css_Viewing_Sun => 0);
      Assert_Latest_Output (Self, Tick_Number => 10, Omega_Rn_B => [0.1, 0.0, 0.0], Fault_Detected => False);
   end Test_Reset;

   -- Ensure staged parameter values the algorithm would reject are refused at
   -- validation.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Sun_Search_Point.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Sun_Search_Point_Parameters.Instance;

      -- Stage the full valid set. Every case below starts from this baseline so a
      -- rejection can only come from the single field that was perturbed.
      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rotations (Test_Rotations)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.S_Hat_Bdy_Cmd (Test_S_Hat_Bdy_Cmd)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sun_Axis_Spin_Rate ((Value => 0.0))), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Rn_B_Cfg (Zero_Vector)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Observation_Threshold (Test_Observation_Threshold)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period (Test_Control_Period)), Success);
      end Stage_Valid_Set;

      Zero_Duration_Rotations : constant Rotation_Properties_X4_Record.T :=
         (Rotations => [
            (Rotation_Duration => 0.0, Rotation_Rate => 0.1, Rotation_Axis => Body_Axis.B1_Hat_B),
            (Rotation_Duration => 1.0, Rotation_Rate => 0.1, Rotation_Axis => Body_Axis.B1_Hat_B),
            (Rotation_Duration => 1.0, Rotation_Rate => 0.1, Rotation_Axis => Body_Axis.B1_Hat_B),
            (Rotation_Duration => 1.0, Rotation_Rate => 0.1, Rotation_Axis => Body_Axis.B1_Hat_B)
         ]);
   begin
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A rotation duration of zero is rejected (must be finite and > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Rotations (Zero_Duration_Rotations)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A commanded body vector that is not a unit vector is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.S_Hat_Bdy_Cmd (Zero_Vector)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.S_Hat_Bdy_Cmd ([2.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A control period of zero is rejected (must be finite and > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Control_Period ((Value => -0.5))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite fallback rate is rejected. The value is injected as raw bytes because
      -- the compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground.
      Stage_Valid_Set;
      declare
         Par : Parameter.T := Params.Omega_Rn_B_Cfg (Zero_Vector);
      begin
         -- Overwrite the second of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First + 4 .. Par.Buffer'First + 7) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above
      -- were caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Sun_Search_Point_Tests.Implementation;
