--------------------------------------------------------------------------------
-- Mrp_Rotation Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Att_Ref.Assertion; use Att_Ref.Assertion;
with Mrp_Rotation_Parameters;
with Packed_F32x3;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Mrp_Rotation_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- Rotation configuration and base reference frame from the Python reference test
   -- (_tests/test_mrpRotation.py).
   Initial_Sigma : constant Packed_F32x3.T := [0.3, 0.5, 0.0];
   -- 0.1 degrees per second about the first axis.
   Rotation_Rate : constant Packed_F32x3.T := [0.00174532925, 0.0, 0.0];
   -- The control period is fixed at initialization, half a second as in the reference test.
   Control_Period : constant Short_Float := 0.5;
   Base_Reference : constant Att_Ref.T := (
      Sigma_Rn => [0.1, 0.2, 0.3],
      Omega_Rn_N => [0.1, 0.0, 0.0],
      Domega_Rn_N => [0.0, 0.0, 0.0]
   );

   -- The reference model integrates in double precision. The rates are computed from
   -- single precision attitudes, so they agree to about a part in a million.
   Epsilon : constant := 1.0E-6;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply the rotation configuration.
   procedure Apply_Configuration (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Rotation_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Initial_Sigma_Rr0 (Initial_Sigma)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Rr0_R (Rotation_Rate)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Configuration;

   -- Send one tick with the base reference frame and check the published reference.
   procedure Send_Tick_And_Check (Self : in out Instance; Tick_Number : in Natural; Expected : in Att_Ref.T) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Base_Attitude_Reference := Base_Reference;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, Tick_Number);
      Att_Ref_Assert.Eq (T.Attitude_Reference_History.Get (Tick_Number), Expected, Epsilon => Epsilon);
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
      Self.Tester.Component_Instance.Init (Control_Period => Control_Period);

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

   -- Run the algorithm through the rotation and reset sequence of the Python
   -- reference test to ensure the Ada to C to C++ integration is sound. Each tick
   -- advances the rotation by one control period before composing it with the base
   -- reference, so the attitude changes from tick to tick while the rates stay nearly
   -- constant. The reference test resets after four ticks, which here is the reset
   -- connector, so the two ticks after it repeat the first two.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Expected reference frames, computed independently with the forward Euler MRP
      -- integration and frame composition of the reference model.
      --
      -- A staged configuration reaches the algorithm on the next tick, and applying it
      -- keeps the rotation state, so that tick still rotates from the default zero seed:
      Expected_From_Default_Seed : constant Att_Ref.T :=
         (Sigma_Rn => [0.1001919892, 0.2001396216, 0.2999258040],
          Omega_Rn_N => [0.1003486361, 0.0016008252, -0.0006016524],
          Domega_Rn_N => [0.0, 0.0000601652, 0.0001600825]);
      -- After a reset the rotation starts from the configured initial attitude:
      Expected : constant array (1 .. 4) of Att_Ref.T := [
         (Sigma_Rn => [0.0304858985, 0.9422136797, 0.2255949944],
          Omega_Rn_N => [0.0982615064, 0.0001319004, -0.0000801032],
          Domega_Rn_N => [0.0, 0.0000080103, 0.0000131900]),
         (Sigma_Rn => [0.0304994707, 0.9423245984, 0.2251868890],
          Omega_Rn_N => [0.0982615064, 0.0001319003, -0.0000801031],
          Domega_Rn_N => [0.0, 0.0000080103, 0.0000131900]),
         (Sigma_Rn => [0.0305130376, 0.9424353460, 0.2247787312],
          Omega_Rn_N => [0.0982615064, 0.0001319002, -0.0000801029],
          Domega_Rn_N => [0.0, 0.0000080103, 0.0000131900]),
         (Sigma_Rn => [0.0305265993, 0.9425459226, 0.2243705210],
          Omega_Rn_N => [0.0982615064, 0.0001319002, -0.0000801028],
          Domega_Rn_N => [0.0, 0.0000080103, 0.0000131900])
      ];
   begin
      -- The first tick applies the staged configuration and rotates from the default
      -- seed:
      Apply_Configuration (Self);
      Send_Tick_And_Check (Self, 1, Expected_From_Default_Seed);

      -- The reset connector restarts the rotation from the configured initial attitude,
      -- and four ticks advance it:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for I in Expected'Range loop
         Send_Tick_And_Check (Self, 1 + I, Expected (I));
      end loop;

      -- A second reset starts the sequence over:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for I in 1 .. 2 loop
         Send_Tick_And_Check (Self, 5 + I, Expected (I));
      end loop;
   end Test;

   -- The algorithm requires a finite initial attitude and rotation rate. Validation is
   -- the only guard keeping a rejected value out of the throwing Set_Config, so exercise
   -- it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Mrp_Rotation_Parameters.Instance;

      -- Stage a known-good set, so the rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Initial_Sigma_Rr0 (Initial_Sigma)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Omega_Rr0_R (Rotation_Rate)), Success);
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
         Par : Parameter.T := Params.Omega_Rr0_R (Rotation_Rate);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring the reference configuration makes the set acceptable again, so the
      -- rejection above was caused by the perturbed value:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Mrp_Rotation.Implementation.Tester.Instance_Access renames Self.Tester;
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

end Mrp_Rotation_Tests.Implementation;
