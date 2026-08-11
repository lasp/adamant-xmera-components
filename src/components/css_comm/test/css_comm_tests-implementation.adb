--------------------------------------------------------------------------------
-- Css_Comm Tests Body
--------------------------------------------------------------------------------

with Ada.Real_Time;
with Basic_Assertions; use Basic_Assertions;
with Packed_F64x8.Assertion; use Packed_F64x8.Assertion;
with Packed_F64x11;
with Packed_U32;
with Packed_F64;
with Css_Array_Adc_8;
with Css_Sensor_Values;
with Css_Comm_Parameters;
with Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;
use Parameter_Enums.Assertion;
with Sys_Time.Assertion; use Sys_Time.Assertion;

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
   -- ADC_count/Max_Sensor_Value clamped to [0, 1]. The Ada wrapper passes
   -- raw counts; the C algorithm performs the divide and the output clamp.
   overriding procedure Test_Zero_Cheby_Is_Identity (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;

      -- Configuration
      Max_Sensor_Val : constant Packed_F64.T := (Value => 100.0);
      Cheby_Count_Val : constant Packed_U32.T := (Value => 3);
      Cheby_Poly_Val : constant Packed_F64x11.T := [others => 0.0];

      -- Input ADC counts: [50, 0, 100, 0, 110, 0, 0, 0]
      -- (ADC is unsigned, so the legacy negative-input case is not
      -- representable here; replaced with 0.)
      -- Expected output (16 elements, last 8 are zero-padding to
      -- MAX_NUM_CSS_SENSORS): [0.5, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, ...]
      -- Rationale: cheby = 0, so the C output is clamp(adc/100, [0, 1]).
      Input_Data : constant Css_Array_Adc_8.T := (
         Adc_Value => [50, 0, 100, 0, 110, 0, 0, 0]
      );
      Expected_Output : constant Packed_F64x8.T :=
         [0.5, 0.0, 1.0, 0.0, 1.0, others => 0.0];

      Output : Css_Sensor_Values.T;
   begin
      -- Initialize component
      T.Component_Instance.Init;

      -- Stage and update parameters
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
      Packed_F64x8_Assert.Eq (Output.Data, Expected_Output, Epsilon => 1.0e-10);

   end Test_Zero_Cheby_Is_Identity;

   -- When the CSS sensor data dependency is stale, the implementation processes
   -- the fetched reading just like a fresh one and publishes the output with the
   -- reading's original timestamp, so the downstream filter receives the old
   -- data and can judge it by its age.
   overriding procedure Test_Stale_Input_Is_Processed (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;

      -- Configuration (same as the identity test).
      Max_Sensor_Val : constant Packed_F64.T := (Value => 100.0);
      Cheby_Count_Val : constant Packed_U32.T := (Value => 3);
      Cheby_Poly_Val : constant Packed_F64x11.T := [others => 0.0];

      -- A non-zero reading stamped well in the past. Even though the fetch
      -- returns Stale, it must be processed like a fresh reading.
      Input_Data : constant Css_Array_Adc_8.T := (
         Adc_Value => [50, 0, 100, 0, 110, 0, 0, 0]
      );
      Input_Time : constant Sys_Time.T := (Seconds => 1, Subseconds => 0);
      -- The stale reading is processed, so the output is the corrected values,
      -- not zeros (cheby = 0, so the C output is clamp(adc/100, [0, 1])).
      Expected_Output : constant Packed_F64x8.T :=
         [0.5, 0.0, 1.0, 0.0, 1.0, others => 0.0];

      Output : Css_Sensor_Values.T;
   begin
      -- Initialize component
      T.Component_Instance.Init;

      -- Configure a non-zero stale limit so the data dependency getter actually
      -- performs the staleness check (id 0 matches the tester's fetch handler).
      T.Component_Instance.Map_Data_Dependencies (
         Css_Sensor_Input_Id => 0,
         Css_Sensor_Input_Stale_Limit => Ada.Real_Time.Seconds (1)
      );

      -- Stage and update parameters
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Max_Sensor_Value (Max_Sensor_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Count (Cheby_Count_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Polynomials (Cheby_Poly_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Provide the non-zero reading stamped well in the past.
      T.Css_Sensor_Input := Input_Data;
      T.Data_Dependency_Timestamp_Override := Input_Time;

      -- Send a tick whose time (the stale reference) is far enough ahead of the
      -- data product timestamp to exceed the 1-second stale limit, so the fetch
      -- returns Stale.
      T.Tick_T_Send ((Time => (Seconds => 100, Subseconds => 0), Count => 0));

      -- Verify output was produced (the component still runs on Stale)
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Css_Sensor_Output_History.Get_Count, 1);

      -- The stale reading must be processed, not zeroed.
      Output := T.Css_Sensor_Output_History.Get (1);
      Packed_F64x8_Assert.Eq (Output.Data, Expected_Output, Epsilon => 1.0e-10);

      -- The output must carry the stale reading's original timestamp, not the
      -- tick time, so the downstream filter sees the true data age.
      Sys_Time_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get (1).Header.Time, Input_Time);

   end Test_Stale_Input_Is_Processed;

   -- Each active sensor's maximum value must be finite and strictly positive.
   -- Cheby_Count does not take part in validation, so only Max_Sensor_Value and the
   -- polynomial coefficients can be rejected here.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;

      Valid_Polys : constant Packed_F64x11.T := [others => 0.0];

      -- Stage the full valid set. Every case below starts from this baseline so a
      -- rejection can only come from the single field that was perturbed.
      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq
           (T.Stage_Parameter (Params.Max_Sensor_Value ((Value => 5.0))), Success);
         Parameter_Update_Status_Assert.Eq
           (T.Stage_Parameter (Params.Cheby_Count ((Value => 1))), Success);
         Parameter_Update_Status_Assert.Eq
           (T.Stage_Parameter (Params.Cheby_Polynomials (Valid_Polys)), Success);
      end Stage_Valid_Set;
   begin
      -- The baseline set is accepted:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A zero maximum sensor value is rejected (must be finite and > 0):
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Max_Sensor_Value ((Value => 0.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A negative maximum sensor value is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq
        (T.Stage_Parameter (Params.Max_Sensor_Value ((Value => -1.0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above
      -- were caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Css_Comm_Tests.Implementation;
