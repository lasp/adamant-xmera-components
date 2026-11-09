--------------------------------------------------------------------------------
-- Dv_Guidance Tests Body
--------------------------------------------------------------------------------

with Att_Ref;
with Dv_Guidance_Parameters;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Dv_Guidance_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Burn frames and their reference attitudes. The first is the one of the
   -- algorithm's Python reference test (_tests/test_dvGuidance.py), the second the
   -- stand-in frame of the parameter defaults. The third axis of the frame points
   -- along the delta-V, the first along the preferred direction crossed with it, and
   -- the second completes the frame. The MRP is that of the burn frame relative to the
   -- inertial frame.
   Reference_Dv : constant Packed_F32x3.T := [5.0, 5.0, 5.0];
   Reference_Pref : constant Packed_F32x3.T := [1.0, 0.0, 0.0];
   Reference_Sigma : constant Packed_F32x3.T := [-0.29583319, -0.03894718, -0.45731849];
   Stand_In_Sigma : constant Packed_F32x3.T := [0.0, 0.0, -0.41421356];
   Other_Dv : constant Packed_F32x3.T := [1.0, 0.0, 0.0];
   Other_Pref : constant Packed_F32x3.T := [0.0, 1.0, 0.0];
   Other_Sigma : constant Packed_F32x3.T := [0.0, 0.41421356, 0.0];

   Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   Epsilon : constant := 1.0E-6;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage the burn frame, the commanded delta-V and the preferred direction.
   procedure Stage_Frame (Self : in out Instance; Dv : in Packed_F32x3.T; Pref : in Packed_F32x3.T) is
      T : Component.Dv_Guidance.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Guidance_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cmd_Dv_N (Dv)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Hat_Pref_N (Pref)), Success);
   end Stage_Frame;

   -- Stage, validate and update the burn frame, as the state manager does when a burn
   -- is commanded.
   procedure Set_Frame (Self : in out Instance; Dv : in Packed_F32x3.T; Pref : in Packed_F32x3.T) is
      T : Component.Dv_Guidance.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Stage_Frame (Self, Dv, Pref);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Set_Frame;

   -- Request a tick and check the reference it returns: the given attitude with zero
   -- reference rate and acceleration.
   procedure Check_Reference (Self : in out Instance; Sigma : in Packed_F32x3.T) is
      T : Component.Dv_Guidance.Implementation.Tester.Instance_Access renames Self.Tester;
      Output : constant Att_Ref.T := T.Tick_T_Request ((Time => T.System_Time, Count => 0));
   begin
      Packed_F32x3_Assert.Eq (Output.Sigma_Rn, Sigma, Epsilon => Epsilon);
      Packed_F32x3_Assert.Eq (Output.Omega_Rn_N, Zero_Vector, Epsilon => Epsilon);
      Packed_F32x3_Assert.Eq (Output.Domega_Rn_N, Zero_Vector, Epsilon => Epsilon);
   end Check_Reference;

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

   -- Check the reference returned for the burn frame of the algorithm's Python
   -- reference test, with zero reference rates, to ensure the Ada to C to C++
   -- integration is sound, and that the stand-in frame serves before a burn frame
   -- is set.
   overriding procedure Test (Self : in out Instance) is
   begin
      -- Before any burn frame is set the reference is the stand-in frame of the
      -- parameter defaults:
      Check_Reference (Self, Stand_In_Sigma);

      -- The burn frame of the reference test is returned on every tick after it is
      -- set:
      Set_Frame (Self, Reference_Dv, Reference_Pref);
      for I in 1 .. 3 loop
         Check_Reference (Self, Reference_Sigma);
      end loop;
   end Test;

   -- Ensure a newly set delta-V and preferred direction reach the reference on the
   -- next tick.
   overriding procedure Test_Burn_Frame_Update (Self : in out Instance) is
   begin
      Set_Frame (Self, Reference_Dv, Reference_Pref);
      Check_Reference (Self, Reference_Sigma);

      -- A new burn frame replaces the old one on the next tick:
      Set_Frame (Self, Other_Dv, Other_Pref);
      Check_Reference (Self, Other_Sigma);
   end Test_Burn_Frame_Update;

   -- The algorithm requires a finite delta-V at least 1e-6 m/s long and a finite
   -- preferred direction of unit length that is not parallel to it. Validation is the
   -- only guard keeping a rejected frame out of the throwing Set_Config, so exercise
   -- it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Dv_Guidance.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Guidance_Parameters.Instance;

      -- Stage a frame the algorithm rejects, check validation refuses it, and check
      -- the reference in effect is unchanged.
      procedure Expect_Rejection (Dv : in Packed_F32x3.T; Pref : in Packed_F32x3.T) is
      begin
         Stage_Frame (Self, Dv, Pref);
         Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);
         Check_Reference (Self, Reference_Sigma);
      end Expect_Rejection;
   begin
      -- The reference frame is accepted:
      Set_Frame (Self, Reference_Dv, Reference_Pref);
      Check_Reference (Self, Reference_Sigma);

      -- A zero or too short delta-V has no direction:
      Expect_Rejection (Zero_Vector, Reference_Pref);
      Expect_Rejection ([1.0E-7, 0.0, 0.0], Reference_Pref);
      -- The preferred direction must be a unit vector, and not along the delta-V:
      Expect_Rejection (Reference_Dv, [0.9, 0.0, 0.0]);
      Expect_Rejection (Reference_Dv, [0.57735027, 0.57735027, 0.57735027]);

      -- A non-finite delta-V is rejected. The value is injected as raw bytes because
      -- the compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      declare
         Par : Parameter.T := Params.Cmd_Dv_N (Reference_Dv);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Hat_Pref_N (Reference_Pref)), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);
      Check_Reference (Self, Reference_Sigma);

      -- Another valid frame is still accepted after the rejections:
      Set_Frame (Self, Other_Dv, Other_Pref);
      Check_Reference (Self, Other_Sigma);
   end Test_Invalid_Parameter;

end Dv_Guidance_Tests.Implementation;
