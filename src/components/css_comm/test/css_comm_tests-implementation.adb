--------------------------------------------------------------------------------
-- Css_Comm Tests Body
--------------------------------------------------------------------------------

with Ada.Real_Time;
with Basic_Assertions; use Basic_Assertions;
with Packed_F64x8.Assertion; use Packed_F64x8.Assertion;
with Packed_F64x11;
with Packed_U32;
with Interfaces;
with Css_Array_Adc_8;
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
   -- ADC_count / U16 full scale. The Ada wrapper passes raw counts; the C
   -- algorithm performs the divide and output clamp.
   overriding procedure Test_Zero_Cheby_Is_Identity (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;

      -- Configuration
      Full_Scale : constant Long_Float := Long_Float (Interfaces.Unsigned_16'Last);
      Cheby_Count_Val : constant Packed_U32.T := (Value => 3);
      Cheby_Poly_Val : constant Packed_F64x11.T := [others => 0.0];

      -- Input ADC counts: [50, 0, 100, 0, 110, 0, 0, 0]
      -- (ADC is unsigned, so the legacy negative-input case is not
      -- representable here; replaced with 0.)
      -- Expected output: each count divided by the U16 full scale; cheby = 0
      -- so the C algorithm passes the normalized value through unchanged.
      Input_Data : constant Css_Array_Adc_8.T := (
         Adc_Value => [50, 0, 100, 0, 110, 0, 0, 0]
      );
      Expected_Output : constant Packed_F64x8.T :=
         [50.0 / Full_Scale, 0.0, 100.0 / Full_Scale, 0.0, 110.0 / Full_Scale, others => 0.0];

      Output : Css_Sensor_Values.T;
   begin
      -- Initialize component
      T.Component_Instance.Init;

      -- Stage and update parameters
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

   -- When the CSS sensor data dependency is stale, the implementation zeroes the
   -- ADC input before passing it to the algorithm, so the output is all zeros
   -- regardless of the (stale) reading that was actually fetched.
   overriding procedure Test_Stale_Input_Is_Zeroed (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;

      -- Configuration (same as the identity test).
      Cheby_Count_Val : constant Packed_U32.T := (Value => 3);
      Cheby_Poly_Val : constant Packed_F64x11.T := [others => 0.0];

      -- A non-zero reading that would produce a non-zero output if it were
      -- processed. Because the fetch returns Stale, it must NOT be.
      Input_Data : constant Css_Array_Adc_8.T := (
         Adc_Value => [50, 0, 100, 0, 110, 0, 0, 0]
      );
      -- Stale input is zeroed, so the entire output is expected to be zero.
      Expected_Output : constant Packed_F64x8.T := [others => 0.0];

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
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Count (Cheby_Count_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Polynomials (Cheby_Poly_Val)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- Provide a non-zero reading stamped well in the past.
      T.Css_Sensor_Input := Input_Data;
      T.Data_Dependency_Timestamp_Override := (Seconds => 1, Subseconds => 0);

      -- Send a tick whose time (the stale reference) is far enough ahead of the
      -- data product timestamp to exceed the 1-second stale limit, so the fetch
      -- returns Stale.
      T.Tick_T_Send ((Time => (Seconds => 100, Subseconds => 0), Count => 0));

      -- Verify output was produced (the component still runs on Stale)
      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Css_Sensor_Output_History.Get_Count, 1);

      -- Output must be all zeros because the stale ADC input was zeroed.
      Output := T.Css_Sensor_Output_History.Get (1);
      Packed_F64x8_Assert.Eq (Output.Data, Expected_Output, Epsilon => 1.0e-10);

   end Test_Stale_Input_Is_Zeroed;

   -- An out-of-range Cheby_Count is rejected by Validate_Parameters before it
   -- can reach the C algorithm's setter, which raises a C++ exception for such
   -- counts; that exception must never cross the FFI boundary.
   overriding procedure Test_Cheby_Count_Validation (Self : in out Instance) is
      T : Component.Css_Comm.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Css_Comm_Parameters.Instance;
   begin
      -- Initialize component
      T.Component_Instance.Init;

      -- A count one past the coefficient array length stages (it is a valid
      -- U32) but must be rejected by validation:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Cheby_Count ((Value => Interfaces.Unsigned_32 (Packed_F64x11.Length + 1)))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A zero count must also be rejected:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Cheby_Count ((Value => 0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The full coefficient count validates:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (
         Params.Cheby_Count ((Value => Interfaces.Unsigned_32 (Packed_F64x11.Length)))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
   end Test_Cheby_Count_Validation;

end Css_Comm_Tests.Implementation;
