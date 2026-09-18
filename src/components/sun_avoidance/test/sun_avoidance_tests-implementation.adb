--------------------------------------------------------------------------------
-- Sun_Avoidance Tests Body
--------------------------------------------------------------------------------

with Interfaces; use Interfaces;
with Ada.Assertions;
with AUnit.Assertions;
with Parameter;
with Basic_Assertions; use Basic_Assertions;
with Att_Ref;
with Att_Ref.Assertion; use Att_Ref.Assertion;
with Packed_F32;
with Packed_F32x3;
with Packed_F64x3;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Sun_Avoidance_Parameters;

package body Sun_Avoidance_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The body sits at the identity attitude and the reference is rotated 60 degrees
   -- about the body z axis, so the slew is a 60 degree rotation about z: MRP
   -- [0, 0, tan (15 deg)]. The sensitive axis is body x, which sweeps through the
   -- x-y plane from +x toward the 60 degree direction. The slew rate is 1 degree per
   -- second, so the slew takes 60 seconds.
   Sensitive_Axis : constant Packed_F32x3.T := [1.0, 0.0, 0.0];
   Slew_Rate : constant Packed_F32.T := (Value => 0.017453292);
   Body_Attitude : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   Input_Reference : constant Att_Ref.T := (
      Sigma_Rn => [0.0, 0.0, 0.267949192],
      Omega_Rn_N => [0.001, -0.002, 0.003],
      Domega_Rn_N => [0.0001, 0.0002, 0.0003]
   );
   Zero_Vector : constant Packed_F64x3.T := [0.0, 0.0, 0.0];

   -- Sun directions used by the tests. Along +z the Sun sits on the sweep axis, clear
   -- of the arc the sensitive axis sweeps, so the slew goes the short way. At 30 degrees
   -- in the x-y plane the Sun sits inside that arc, so the slew must go the long way.
   Sun_Clear_Of_Sweep : constant Packed_F64x3.T := [0.0, 0.0, 1.5E11];
   Sun_Inside_Sweep : constant Packed_F64x3.T := [1.299038106E11, 0.75E11, 0.0];

   -- The MRP of a 10 degree rotation about z, tan (2.5 deg).
   Ten_Degrees : constant Short_Float := 0.043660943;

   Epsilon : constant := 1.0E-5;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Stage and apply the test configuration.
   procedure Apply_Test_Parameters (Self : in out Instance) is
      T : Component.Sun_Avoidance.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Sun_Avoidance_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensitive_Hat_B (Sensitive_Axis)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Slew_Rate (Slew_Rate)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Apply_Test_Parameters;

   -- Set the inputs and tick at the given number of seconds after the test start time.
   -- The tester stamps the data dependencies with the same time, so they are never stale.
   procedure Tick_At (Self : in out Instance; Seconds_After_Start : in Natural; Sun_Position : in Packed_F64x3.T) is
      T : Component.Sun_Avoidance.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.System_Time := (Seconds => 10_000 + Unsigned_32 (Seconds_After_Start), Subseconds => 0);
      T.Spacecraft_Attitude := (Time_Tag => 0.0, Sigma_Bn => Body_Attitude, Omega_Bn_B => [0.0, 0.0, 0.0], Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]);
      T.Input_Attitude_Reference := Input_Reference;
      T.Spacecraft_State := (Position => Zero_Vector, Velocity => Zero_Vector);
      T.Sun_State := (Position => Sun_Position, Velocity => Zero_Vector);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
   end Tick_At;

   -- Check the reference published by the most recent tick.
   procedure Assert_Latest_Output (Self : in out Instance; Tick_Number : in Natural; Expected : in Att_Ref.T) is
      T : Component.Sun_Avoidance.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, Tick_Number);
      Natural_Assert.Eq (T.Attitude_Reference_History.Get_Count, Tick_Number);
      Att_Ref_Assert.Eq (T.Attitude_Reference_History.Get (Tick_Number), Expected, Epsilon => Epsilon);
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
      -- Free the C++ algorithm heap:
      Self.Tester.Component_Instance.Destroy;
      -- Free component heap:
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run a slew with the Sun clear of the swept arc to ensure the Ada to C to C++
   -- integration is sound. The published reference starts at the body attitude and
   -- rotates toward the input reference at the slew rate, with the slew rate added to
   -- the reference rate about the slew axis. Once the slew completes the input
   -- reference passes through unchanged.
   overriding procedure Test (Self : in out Instance) is
   begin
      Apply_Test_Parameters (Self);

      -- At the start the whole 60 degree slew remains, so the reference is the body attitude:
      Tick_At (Self, Seconds_After_Start => 0, Sun_Position => Sun_Clear_Of_Sweep);
      Assert_Latest_Output (Self, 1, (
         Sigma_Rn => [0.0, 0.0, 0.0],
         Omega_Rn_N => [0.001, -0.002, 0.003 + Slew_Rate.Value],
         Domega_Rn_N => Input_Reference.Domega_Rn_N));

      -- Ten seconds in, the reference has turned 10 degrees about +z:
      Tick_At (Self, Seconds_After_Start => 10, Sun_Position => Sun_Clear_Of_Sweep);
      Assert_Latest_Output (Self, 2, (
         Sigma_Rn => [0.0, 0.0, Ten_Degrees],
         Omega_Rn_N => [0.001, -0.002, 0.003 + Slew_Rate.Value],
         Domega_Rn_N => Input_Reference.Domega_Rn_N));

      -- Well after the 60 second slew, the input reference passes through:
      Tick_At (Self, Seconds_After_Start => 100, Sun_Position => Sun_Clear_Of_Sweep);
      Assert_Latest_Output (Self, 3, Input_Reference);
   end Test;

   -- Check that a Sun inside the swept arc makes the slew go the long way around. The
   -- short slew about +z would carry the sensitive axis across the Sun, so the slew
   -- runs about -z instead and the reference turns the other way.
   overriding procedure Test_Long_Way_Around (Self : in out Instance) is
   begin
      Apply_Test_Parameters (Self);

      Tick_At (Self, Seconds_After_Start => 0, Sun_Position => Sun_Inside_Sweep);
      Assert_Latest_Output (Self, 1, (
         Sigma_Rn => [0.0, 0.0, 0.0],
         Omega_Rn_N => [0.001, -0.002, 0.003 - Slew_Rate.Value],
         Domega_Rn_N => Input_Reference.Domega_Rn_N));

      Tick_At (Self, Seconds_After_Start => 10, Sun_Position => Sun_Inside_Sweep);
      Assert_Latest_Output (Self, 2, (
         Sigma_Rn => [0.0, 0.0, -Ten_Degrees],
         Omega_Rn_N => [0.001, -0.002, 0.003 - Slew_Rate.Value],
         Domega_Rn_N => Input_Reference.Domega_Rn_N));
   end Test_Long_Way_Around;

   -- Check that an all-zero Sun position passes the input reference through unchanged,
   -- and that the reset connector is what allows a new slew to be planned.
   overriding procedure Test_Pass_Through_Without_Sun (Self : in out Instance) is
      T : Component.Sun_Avoidance.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      Apply_Test_Parameters (Self);

      -- With no Sun information, no slew is planned and the reference passes through:
      Tick_At (Self, Seconds_After_Start => 0, Sun_Position => Zero_Vector);
      Assert_Latest_Output (Self, 1, Input_Reference);
      Tick_At (Self, Seconds_After_Start => 10, Sun_Position => Zero_Vector);
      Assert_Latest_Output (Self, 2, Input_Reference);

      -- The slew is planned once, so the Sun appearing later changes nothing:
      Tick_At (Self, Seconds_After_Start => 20, Sun_Position => Sun_Clear_Of_Sweep);
      Assert_Latest_Output (Self, 3, Input_Reference);

      -- After a reset the next tick plans a slew from the current geometry, so the
      -- reference starts over from the body attitude:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      Tick_At (Self, Seconds_After_Start => 30, Sun_Position => Sun_Clear_Of_Sweep);
      Assert_Latest_Output (Self, 4, (
         Sigma_Rn => [0.0, 0.0, 0.0],
         Omega_Rn_N => [0.001, -0.002, 0.003 + Slew_Rate.Value],
         Domega_Rn_N => Input_Reference.Domega_Rn_N));
   end Test_Pass_Through_Without_Sun;

   -- The algorithm requires a unit sensitive axis and a positive slew rate. Validation
   -- is the only guard keeping a rejected value out of the throwing Set_Config, so
   -- exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Sun_Avoidance.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Sun_Avoidance_Parameters.Instance;

      -- Stage a known-good set, so each rejection below is caused by the single
      -- perturbed value rather than by leftover staging state.
      procedure Stage_Valid_Configuration is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensitive_Hat_B (Sensitive_Axis)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Slew_Rate (Slew_Rate)), Success);
      end Stage_Valid_Configuration;
   begin
      -- The reference configuration is accepted:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A sensitive axis that is not a unit vector is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensitive_Hat_B ([2.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Sensitive_Hat_B ([0.0, 0.0, 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A slew rate of zero is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Slew_Rate ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative slew rate is rejected:
      Stage_Valid_Configuration;
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Slew_Rate ((Value => -0.01))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A non-finite sensitive axis is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      Stage_Valid_Configuration;
      declare
         Par : Parameter.T := Params.Sensitive_Hat_B (Sensitive_Axis);
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

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Sun_Avoidance.Implementation.Tester.Instance_Access renames Self.Tester;
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

end Sun_Avoidance_Tests.Implementation;
