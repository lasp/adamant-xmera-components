--------------------------------------------------------------------------------
-- Dv_Accumulation Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with Ada.Real_Time;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Dv_Accumulation_Parameters;
with Packed_F32x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;
with Parameter;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Dv_Accumulation_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Test configuration:
   -------------------------------------------------------------------------

   -- The constant acceleration and the control period of the algorithm's Python
   -- reference test (_tests/test_dvAccumulationF32.py). Each sample after the first
   -- adds the acceleration times the control period to the accumulated delta-V.
   Acceleration : constant Packed_F32x3.T := [0.1, -0.2, 0.3];
   Control_Period : constant Short_Float := 0.5;
   Zero_Vector : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   -- An accelerometer bias of the size the burns are set up with.
   Bias : constant Packed_F32x3.T := [0.1, 0.0, -0.1];
   Epsilon : constant := 1.0E-6;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- The delta-V that N integrated samples of the acceleration, less the bias,
   -- accumulate.
   function Expected_Delta_V (Samples : in Natural; Bias : in Packed_F32x3.T := Zero_Vector) return Packed_F32x3.T is
      ([for I in Acceleration'Range => Short_Float (Samples) * Control_Period * (Acceleration (I) - Bias (I))]);

   -- The sum of two delta-V vectors.
   function "+" (Left : in Packed_F32x3.T; Right : in Packed_F32x3.T) return Packed_F32x3.T is
      ([for I in Left'Range => Left (I) + Right (I)]);

   -- Stage, validate and update the accelerometer bias, as the state manager does when
   -- a burn is commanded. It applies at the next tick.
   procedure Set_Bias (Self : in out Instance; Accel_Bias_B : in Packed_F32x3.T) is
      T : Component.Dv_Accumulation.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Accumulation_Parameters.Instance;
   begin
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Accel_Bias_B (Accel_Bias_B)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Set_Bias;

   -- Send one tick with the acceleration and check the delta-V it publishes. The
   -- history only holds the output of this tick.
   procedure Send_Tick (Self : in out Instance; Expected : in Packed_F32x3.T) is
      T : Component.Dv_Accumulation.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Accel_Average := Acceleration;
      T.Data_Product_T_Recv_Sync_History.Clear;
      T.Accumulated_Delta_V_History.Clear;
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Accumulated_Delta_V_History.Get_Count, 1);
      Packed_F32x3_Assert.Eq (T.Accumulated_Delta_V_History.Get (1), Expected, Epsilon => Epsilon);
   end Send_Tick;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- The acceleration is produced every tick, so it gets no stale limit:
      Self.Tester.Component_Instance.Map_Data_Dependencies (Accel_Average_Id => 0, Accel_Average_Stale_Limit => Ada.Real_Time.Time_Span_Zero);

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

   -- Feed a constant acceleration and check the accumulated delta-V grows by the
   -- acceleration times the control period on each tick after the first, which
   -- starts the window, to ensure the Ada to C to C++ integration is sound.
   overriding procedure Test (Self : in out Instance) is
   begin
      for Samples in 0 .. 4 loop
         Send_Tick (Self, Expected_Delta_V (Samples));
      end loop;
   end Test;

   -- Ensure a newly set accelerometer bias is subtracted from each sample from the
   -- tick after its update, and the accumulated delta-V is kept.
   overriding procedure Test_Bias (Self : in out Instance) is
   begin
      -- The default bias makes no correction:
      Send_Tick (Self, Expected_Delta_V (0));
      Send_Tick (Self, Expected_Delta_V (1));

      -- The bias applies to the samples from the tick after its update, and the
      -- accumulator is kept, so the delta-V is one unbiased sample plus the biased
      -- ones:
      Set_Bias (Self, Bias);
      for Samples in 1 .. 3 loop
         Send_Tick (Self, Expected_Delta_V (1) + Expected_Delta_V (Samples, Bias));
      end loop;
   end Test_Bias;

   -- The algorithm requires a finite bias. Validation is the only guard keeping a
   -- rejected bias out of the throwing Set_Config, so exercise it directly.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Dv_Accumulation.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Dv_Accumulation_Parameters.Instance;
   begin
      -- The bias is accepted and subtracted from every sample:
      Set_Bias (Self, Bias);
      for Samples in 0 .. 2 loop
         Send_Tick (Self, Expected_Delta_V (Samples, Bias));
      end loop;

      -- A non-finite bias is rejected. The value is injected as raw bytes because the
      -- compiler will not let a non-finite Short_Float be written as a literal, and
      -- because that is how one would arrive: as bytes from the ground. Staging accepts
      -- it, and converting it for the algorithm raises, which validation reports as a
      -- rejection.
      declare
         Par : Parameter.T := Params.Accel_Bias_B (Bias);
      begin
         -- Overwrite the first of the three big-endian floats with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The bias in effect is unchanged:
      Send_Tick (Self, Expected_Delta_V (3, Bias));

      -- Another valid bias is still accepted after the rejection. Zero makes no
      -- correction, so the next sample adds without one:
      Set_Bias (Self, Zero_Vector);
      Send_Tick (Self, Expected_Delta_V (3, Bias) + Expected_Delta_V (1));
   end Test_Invalid_Parameter;

   -- Ensure the reset connector zeroes the accumulated delta-V and the next sample
   -- starts a new window without being integrated.
   overriding procedure Test_Reset (Self : in out Instance) is
      T : Component.Dv_Accumulation.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      for Samples in 0 .. 3 loop
         Send_Tick (Self, Expected_Delta_V (Samples));
      end loop;

      -- After the reset the accumulation starts over, the first sample only opening
      -- the window:
      T.Reset_Tick_T_Send ((Time => T.System_Time, Count => 0));
      for Samples in 0 .. 2 loop
         Send_Tick (Self, Expected_Delta_V (Samples));
      end loop;
   end Test_Reset;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Dv_Accumulation.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Accumulated_Delta_V_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Dv_Accumulation_Tests.Implementation;
