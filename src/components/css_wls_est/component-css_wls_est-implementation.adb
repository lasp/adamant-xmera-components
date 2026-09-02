--------------------------------------------------------------------------------
-- Css_Wls_Est Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values;
with Css_Wls_Est_Constellation.C;
with Css_Wls_Est_Inputs.C;
with Css_Wls_Est_Output.C;
with Packed_F32x3.C;
with Packed_F32x8;
with Packed_F32x24;
with Packed_F64x8;
with Interfaces;

package body Component.Css_Wls_Est.Implementation is

   -- The number of coarse sun sensors is fixed by the hardware interface: the CSS
   -- cosine data dependency carries exactly this many channels, and the boresight
   -- parameter carries three components for each of them.
   Num_Sensors : constant Natural := Packed_F64x8.Length;

   -- Assemble the C constellation record from the boresight and bias parameters. The
   -- C type is sized to the algorithm's own sensor bound, which is wider than the
   -- physical channel count; the trailing entries correspond to no sensor and stay
   -- zero, where the C validators ignore them.
   function To_Constellation (
      Css_N_Hat_B : in Packed_F32x24.U;
      Css_Bias : in Packed_F32x8.U
   ) return Css_Wls_Est_Constellation.C.U_C is
      Result : Css_Wls_Est_Constellation.C.U_C := (
         Num_Css => Interfaces.Unsigned_32 (Num_Sensors),
         Css_N_Hat_B => [others => [others => 0.0]],
         Css_Bias => [others => 0.0]
      );
   begin
      for Sensor in 0 .. Num_Sensors - 1 loop
         for Axis in 0 .. 2 loop
            Result.Css_N_Hat_B (Sensor) (Axis) := Css_N_Hat_B (Sensor * 3 + Axis);
         end loop;
         Result.Css_Bias (Sensor) := Css_Bias (Sensor);
      end loop;
      return Result;
   end To_Constellation;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the CSS weighted least squares estimator algorithm.
   overriding procedure Init (Self : in out Instance) is
      use Parameter_Validation_Status;

      -- The constellation crosses by reference, so it needs an aliased object to
      -- point at and cannot be marshalled inline.
      Constellation : aliased Css_Wls_Est_Constellation.C.U_C :=
         To_Constellation (Self.Css_N_Hat_B, Self.Css_Bias);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form
      -- a valid one. Assert through Validate_Parameters, the component's single
      -- validation gate, rather than calling Validate_Config a second time here.
      pragma Assert (Self.Validate_Parameters (
         Css_N_Hat_B       => Self.Css_N_Hat_B,
         Css_Bias          => Self.Css_Bias,
         Sensor_Use_Thresh => Self.Sensor_Use_Thresh,
         Use_Weights       => Self.Use_Weights) = Valid);
      Self.Alg := Create (
         Constellation     => Constellation'Access,
         Use_Weights       => Self.Use_Weights.Value,
         Sensor_Use_Thresh => Self.Sensor_Use_Thresh.Value);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums.Data_Dependency_Status;

      -- The producer republishes the corrected cosine values on every tick of this
      -- synchronous call chain, upstream of this component, and seeds an initial value
      -- at Set_Up. Any other status indicates a wiring or execution-order defect, so
      -- we assert; the stale check is the integration-order alarm.
      Css_Input : Css_Sensor_Values.T;
      Css_Input_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Input, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call the algorithm:
      declare
         -- The measurements cross by reference. The C type is sized to the algorithm's
         -- own sensor bound, so the entries beyond the physical channels stay zero.
         Inputs : aliased Css_Wls_Est_Inputs.C.U_C := (Cos_Values => [others => 0.0]);
         Call_Time : constant Interfaces.Unsigned_64 :=
            Interfaces.Unsigned_64 (Arg.Time.Seconds) * 1_000_000_000 +
            (Interfaces.Unsigned_64 (Arg.Time.Subseconds) * 1_000_000_000) / 65_536;
      begin
         for Sensor in 0 .. Num_Sensors - 1 loop
            Inputs.Cos_Values (Sensor) := Short_Float (Css_Input.Data (Sensor));
         end loop;

         declare
            Output : constant Css_Wls_Est_Output.C.U_C := Update (
               Self.Alg,
               Call_Time => Call_Time,
               Inputs => Inputs'Access
            );
            -- Only the residuals of the physical channels are published; the trailing
            -- entries of the C output correspond to no sensor.
            Residuals : Packed_F32x8.U := [others => 0.0];
         begin
            for Sensor in Residuals'Range loop
               Residuals (Sensor) := Output.Post_Fit_Residuals (Sensor);
            end loop;

            -- Send out the data products, all stamped with the tick time so a cycle's
            -- products carry one coherent timestamp:
            Self.Data_Product_T_Send (Self.Data_Products.Sun_Heading_B (
               Arg.Time, Packed_F32x3.C.Pack (Output.Sun_Heading_B)));
            Self.Data_Product_T_Send (Self.Data_Products.Omega_Bn_B (
               Arg.Time, Packed_F32x3.C.Pack (Output.Omega_Bn_B)));
            Self.Data_Product_T_Send (Self.Data_Products.Num_Active_Css (
               Arg.Time, (Value => Output.Num_Active_Css)));
            Self.Data_Product_T_Send (Self.Data_Products.Residual_State_Heading (
               Arg.Time, Packed_F32x3.C.Pack (Output.Residual_State_Heading)));
            Self.Data_Product_T_Send (Self.Data_Products.Post_Fit_Residuals (
               Arg.Time, Packed_F32x8.Pack (Residuals)));
         end;
      end;
   end Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Apply parameters to the C algorithm when they are updated. The values were
   -- checked by Validate_Parameters at staging, so Set_Config will not reject them.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Constellation : aliased Css_Wls_Est_Constellation.C.U_C :=
         To_Constellation (Self.Css_N_Hat_B, Self.Css_Bias);
   begin
      Set_Config (
         Self.Alg,
         Constellation     => Constellation'Access,
         Use_Weights       => Self.Use_Weights.Value,
         Sensor_Use_Thresh => Self.Sensor_Use_Thresh.Value);
      -- Set_Config installs the configuration without touching runtime state. A new
      -- geometry or threshold invalidates the prior heading, so drop it instead of
      -- differencing the next estimate across the change and reporting a rate that
      -- the spacecraft never turned through.
      Re_Initialize (Self.Alg);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's
   -- own non-throwing Validate_Config predicate, so the config rules live solely in
   -- the algorithm. Rejecting an invalid update here at staging keeps it from reaching
   -- the throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Css_N_Hat_B : in Packed_F32x24.U;
      Css_Bias : in Packed_F32x8.U;
      Sensor_Use_Thresh : in Packed_F32.U;
      Use_Weights : in Packed_Boolean.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
      Constellation : aliased Css_Wls_Est_Constellation.C.U_C :=
         To_Constellation (Css_N_Hat_B, Css_Bias);
   begin
      if Validate_Config (
            Constellation     => Constellation'Access,
            Use_Weights       => Use_Weights.Value,
            Sensor_Use_Thresh => Sensor_Use_Thresh.Value)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Css Wls Est component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Css_Wls_Est.Implementation;
