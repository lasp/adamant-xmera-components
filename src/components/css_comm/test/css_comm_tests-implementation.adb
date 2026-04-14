--------------------------------------------------------------------------------
-- Css_Comm Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Packed_F64x16.Assertion; use Packed_F64x16.Assertion;
with Packed_F64x10;
with Packed_U32;
with Packed_F64;
with Css_Sensor_Values;
with Css_Comm_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;

package body Css_Comm_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      Self.Tester.Init_Base;
      Self.Tester.Connect;
      Self.Tester.Component_Instance.Set_Up;
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Adapted from C++ test ZeroChebyIsIdentity:
   -- With all zero Chebyshev coefficients, the output equals
   -- input/maxSensorValue clamped to [0, 1].
   overriding procedure Test_Zero_Cheby_Is_Identity (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;

      -- Configuration
      Num_Sensors_Val : constant Packed_U32.T := (Value => 5);
      Max_Sensor_Val : constant Packed_F64.T := (Value => 100.0);
      Cheby_Count_Val : constant Packed_U32.T := (Value => 3);
      Cheby_Poly_Val : constant Packed_F64x10.T := [others => 0.0];

      -- Input: [50.0, 0.0, 100.0, -10.0, 110.0, rest zeros]
      -- Expected output: [0.5, 0.0, 1.0, 0.0, 1.0, rest zeros]
      -- Rationale: output = clamp(input/maxSensor + 0, 0, 1) since cheby = 0
      Input_Data : constant Css_Sensor_Values.T := (
         Data => [50.0, 0.0, 100.0, -10.0, 110.0, others => 0.0]
      );
      Expected_Output : constant Packed_F64x16.T :=
         [0.5, 0.0, 1.0, 0.0, 1.0, others => 0.0];

      Output : Css_Sensor_Values.T;
   begin
      -- Initialize component
      T.Component_Instance.Init;

      -- Stage and update parameters
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Num_Sensors (Num_Sensors_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Max_Sensor_Value (Max_Sensor_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Count (Cheby_Count_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Polynomials (Cheby_Poly_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Set data dependency
      T.Css_Sensor_Input := Input_Data;

      -- Send tick to trigger algorithm
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Verify output was produced
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Css_Sensor_Output_History.Get_Count, 1);

      -- Check output matches expected value
      Output := T.Css_Sensor_Output_History.Get (1);
      Packed_F64x16_Assert.Eq (Output.Data, Expected_Output, Epsilon => 1.0e-10);

   end Test_Zero_Cheby_Is_Identity;

end Css_Comm_Tests.Implementation;
