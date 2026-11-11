--------------------------------------------------------------------------------
-- Mrp_Rotation Tests Body
--------------------------------------------------------------------------------

with Parameter;
with Att_Ref.Assertion; use Att_Ref.Assertion;
with Mrp_Rotation_Parameters;
with Packed_F32x3;
with Parameter_Enums.Assertion;
with Sys_Time.Arithmetic;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Mrp_Rotation_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Rotation configuration and base reference frame from the Python reference test
   -- (_tests/test_mrpRotation.py).
   Body_Correction : constant Packed_F32x3.T := [0.3, 0.5, 0.0];
   Pointing_Offset : constant Packed_F32x3.T := [0.0, 0.0, 0.05];
   -- The pointing offset the reference test reconfigures to:
   New_Pointing_Offset : constant Packed_F32x3.T := [0.04, -0.02, 0.0];
   -- 0.1 degrees per second about the first body axis.
   Rotation_Rate : constant Packed_F32x3.T := [0.00174532925, 0.0, 0.0];
   -- The control period is fixed at initialization, half a second as in the reference test.
   Control_Period : constant Short_Float := 0.5;
   Base_Reference : constant Att_Ref.T := (
      Sigma_Rn => [0.1, 0.2, 0.3],
      Omega_Rn_N => [0.1, 0.0, 0.0],
      Domega_Rn_N => [0.0, 0.0, 0.0]
   );

   -- Expected reference frames, computed independently with the forward Euler MRP
   -- integration and frame composition [RN] = [RRp][RpRc][RcR0][R0N] of the
   -- reference model. The rotation starts at identity and its axis is fixed in the
   -- body, so the rates are the same on every tick.
   --
   -- The first four ticks with the configured pointing offset:
   Expected : constant array (1 .. 4) of Att_Ref.T := [
      (Sigma_Rn => [0.1271924180, 0.9562164045, 0.2327778772],
       Omega_Rn_N => [0.0983122227, 0.0004374178, 0.0000790414],
       Domega_Rn_N => [0.0, -0.0000079041, 0.0000437418]),
      (Sigma_Rn => [0.1272028006, 0.9563709595, 0.2323735235],
       Omega_Rn_N => [0.0983122227, 0.0004374178, 0.0000790414],
       Domega_Rn_N => [0.0, -0.0000079041, 0.0000437418]),
      (Sigma_Rn => [0.1272131602, 0.9565253509, 0.2319690809],
       Omega_Rn_N => [0.0983122227, 0.0004374178, 0.0000790414],
       Domega_Rn_N => [0.0, -0.0000079041, 0.0000437418]),
      (Sigma_Rn => [0.1272234970, 0.9566795788, 0.2315645497],
       Omega_Rn_N => [0.0983122227, 0.0004374178, 0.0000790414],
       Domega_Rn_N => [0.0, -0.0000079041, 0.0000437418])
   ];

   -- The reference model integrates in double precision. The rates are computed from
   -- single precision attitudes, so they agree to about a part in a million.
   Epsilon : constant := 1.0E-6;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply the rotation configuration. The body correction and the rotation
   -- rate are the same in every case, and the pointing offset is the reference one
   -- unless a case sets another.
   procedure Apply_Configuration (Self : in out Instance; Sigma_Rprc : in Packed_F32x3.T := Pointing_Offset) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Rotation_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Rcr0 (Body_Correction)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Rprc (Sigma_Rprc)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Rrp_R (Rotation_Rate)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Request one tick with the base reference frame and check the reference it returns.
   procedure Send_Tick_And_Check (Self : in out Instance; Expected : in Att_Ref.T) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Att_Ref_Assert.Eq (
         T.Att_Ref_Tick_T_Request ((
            Current_Tick => (Time => T.System_Time, Count => 0),
            Call_Time => Sys_Time.Arithmetic.To_Nanoseconds (T.System_Time),
            Reference => Base_Reference)),
         Expected, Epsilon => Epsilon);
   end Send_Tick_And_Check;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Call component init here.
      Self.Tester.Component_Instance.Init (Control_Period => Control_Period);

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

   -- Run the algorithm through a rotation, pointing offset change, and reset
   -- sequence built from the cases of the Python reference test, with expected
   -- values from its reference model, to ensure the Ada to C to C++ integration is
   -- sound. Each tick advances the rotation by one control period
   -- before applying it to the base reference, so the attitude changes from tick to
   -- tick while the rates stay constant. A new pointing offset applies at the next
   -- tick and keeps the integrated rotation. A reset restarts the rotation at
   -- identity.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;

      -- The two ticks after the pointing offset change, which continue the rotation
      -- from the fourth tick:
      Expected_After_Offset_Change : constant array (1 .. 2) of Att_Ref.T := [
         (Sigma_Rn => [0.0405112672, 0.9232220497, 0.1416304095],
          Omega_Rn_N => [0.0982769650, 0.0001841562, -0.0002083537],
          Domega_Rn_N => [0.0, 0.0000208354, 0.0000184156]),
         (Sigma_Rn => [0.0405394605, 0.9233000859, 0.1412300618],
          Omega_Rn_N => [0.0982769650, 0.0001841562, -0.0002083537],
          Domega_Rn_N => [0.0, 0.0000208354, 0.0000184156])
      ];
      -- The two ticks after the reset, which restart the rotation at identity with
      -- the new pointing offset:
      Expected_After_Reset : constant array (1 .. 2) of Att_Ref.T := [
         (Sigma_Rn => [0.0403984316, 0.9229082859, 0.1432314057],
          Omega_Rn_N => [0.0982769650, 0.0001841562, -0.0002083537],
          Domega_Rn_N => [0.0, 0.0000208354, 0.0000184156]),
         (Sigma_Rn => [0.0404266498, 0.9229869697, 0.1428312159],
          Omega_Rn_N => [0.0982769650, 0.0001841562, -0.0002083537],
          Domega_Rn_N => [0.0, 0.0000208354, 0.0000184156])
      ];
   begin
      -- The configuration applies at the first tick, and the rotation starts at
      -- identity, so four ticks follow the reference sequence from its start:
      Apply_Configuration (Self);
      for I in Expected'Range loop
         Send_Tick_And_Check (Self, Expected (I));
      end loop;

      -- A new pointing offset applies at the next tick, and the rotation continues
      -- from where it is:
      Apply_Configuration (Self, Sigma_Rprc => New_Pointing_Offset);
      for I in Expected_After_Offset_Change'Range loop
         Send_Tick_And_Check (Self, Expected_After_Offset_Change (I));
      end loop;

      -- The reset connector restarts the rotation at identity:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for I in Expected_After_Reset'Range loop
         Send_Tick_And_Check (Self, Expected_After_Reset (I));
      end loop;
   end Test;

   -- The algorithm requires a finite body correction, pointing offset, and rotation
   -- rate. Validation is the only guard keeping a rejected value out of the throwing
   -- Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Rotation_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Rcr0 (Body_Correction)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sigma_Rprc (Pointing_Offset)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Rrp_R (Rotation_Rate)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A non-finite rotation rate is rejected. The value is injected as raw bytes because
      -- the compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Omega_Rrp_R (Rotation_Rate);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite pointing offset is rejected the same way:
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Sigma_Rprc (Pointing_Offset);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejections above were caused by the perturbed values:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A configuration updated while the component is not being ticked is still
   -- pending when a state change resets it. The reset applies it before restarting
   -- the rotation, so the first tick starts at identity with the new pointing offset
   -- rather than continuing the rotation with the old one.
   overriding procedure Test_Reset_Applies_Pending_Parameters (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
      -- The rotation restarted at identity with the new pointing offset:
      Expected_After_Reset : constant array (1 .. 2) of Att_Ref.T := [
         (Sigma_Rn => [0.0403984316, 0.9229082859, 0.1432314057],
          Omega_Rn_N => [0.0982769650, 0.0001841562, -0.0002083537],
          Domega_Rn_N => [0.0, 0.0000208354, 0.0000184156]),
         (Sigma_Rn => [0.0404266498, 0.9229869697, 0.1428312159],
          Omega_Rn_N => [0.0982769650, 0.0001841562, -0.0002083537],
          Domega_Rn_N => [0.0, 0.0000208354, 0.0000184156])
      ];
   begin
      -- Advance the rotation by two ticks:
      Apply_Configuration (Self);
      for I in 1 .. 2 loop
         Send_Tick_And_Check (Self, Expected (I));
      end loop;

      -- Update the pointing offset without ticking, so it is still pending at the reset:
      Apply_Configuration (Self, Sigma_Rprc => New_Pointing_Offset);
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for I in Expected_After_Reset'Range loop
         Send_Tick_And_Check (Self, Expected_After_Reset (I));
      end loop;
   end Test_Reset_Applies_Pending_Parameters;

end Mrp_Rotation_Tests.Implementation;
