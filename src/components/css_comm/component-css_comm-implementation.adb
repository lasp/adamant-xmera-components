--------------------------------------------------------------------------------
-- Css_Comm Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values;
with Css_Sensor_Values.C;
with Packed_F64x11.C;

package body Component.Css_Comm.Implementation is

   -- Build the C config POD from the component parameters. Num_Sensors and the
   -- Chebyshev polynomials come from parameters. The per-sensor maxSensorValues
   -- are pinned to 1.0 so the C algorithm's divide-by-max is a no-op: the
   -- Ada-side ADC->cosine conversion in Tick_T_Recv_Sync (using Max_Sensor_Value)
   -- is the single source of truth for ADC scaling. (Cheby_Count is no longer a
   -- config field -- it was removed from the algorithm -- so it is not applied.)
   function Make_Config (Self : Instance) return Css_Comm_Config_C is
     (Num_Sensors       => Self.Num_Sensors.Value,
      Max_Sensor_Values => [others => 1.0],
      Cheby_Polynomials => Css_Cheby_Polynomials_C (Packed_F64x11.C.To_C (Self.Cheby_Polynomials)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the CSS comm algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- Build the initial configuration from the parameter defaults (numSensors
      -- in [1, MAX], finite polynomials, pinned maxSensorValues), all valid, so
      -- Create will not reject them.
      Config : aliased Css_Comm_Config_C := Make_Config (Self);
   begin
      -- Allocate the C++ algorithm on the heap with the initial configuration.
      Self.Alg := Create (Config'Access);
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

      -- We assume the CSS sensor data dependency is available at startup, so a
      -- fetch returns Success or Stale. On Stale the last received value may be
      -- arbitrarily old, so we zero the ADC input below rather than feed a stale
      -- reading to the algorithm. Not_Available (no value was ever made available)
      -- and Error (ID/length mismatch) indicate an assembly/configuration defect,
      -- so we assert. (Error additionally trips Invalid_Data_Dependency below
      -- before returning.)
      Css_Adc_Input : Css_Array_Adc_8.T;
      Css_Input_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Adc_Input, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success or else Css_Input_Status = Stale);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- If the data dependency is stale, zero the ADC input so the algorithm
      -- processes zeros rather than an arbitrarily old reading.
      if Css_Input_Status = Stale then
         Css_Adc_Input := (Adc_Value => [others => 0]);
      end if;

      -- Convert ADC counts to cosine values per the css_wls_estimator pattern:
      -- divide each U16 ADC value by Max_Sensor_Value and clamp to <= 1.0
      -- (lower bound is implicit since ADC is unsigned). The result is packed
      -- into a Css_Sensor_Values.T with the first 8 elements taken from the
      -- ADC source and the remaining elements zero-padded up to the
      -- C algorithm's MAX_NUM_CSS_SENSORS bound.
      declare
         Max_Value : constant Long_Float := Long_Float (Self.Max_Sensor_Value.Value);
         Cosines : Css_Sensor_Values.T := (Data => [others => 0.0]);
      begin
         for I in Css_Adc_Input.Adc_Value'Range loop
            declare
               Cos_Value : Long_Float :=
                  Long_Float (Css_Adc_Input.Adc_Value (I)) / Max_Value;
            begin
               if Cos_Value > 1.0 then
                  Cos_Value := 1.0;
               end if;
               Cosines.Data (Cosines.Data'First + Natural (I - Css_Adc_Input.Adc_Value'First)) := Cos_Value;
            end;
         end loop;

         -- Call algorithm with the converted cosine values:
         declare
            Css_Input_C : aliased Css_Sensor_Values.C.U_C := Css_Sensor_Values.C.To_C (Css_Sensor_Values.Unpack (Cosines));
            Css_Output : constant Css_Sensor_Values.C.U_C := Update (
               Self.Alg,
               Input_Values => Css_Input_C'Unchecked_Access
            );
         begin
            Self.Data_Product_T_Send (Self.Data_Products.Css_Sensor_Output (
               Arg.Time,
               Css_Sensor_Values.Pack (Css_Sensor_Values.C.To_Ada (Css_Output))
            ));
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
   -- Apply parameters to the C algorithm when they are updated.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- Rebuild the algorithm configuration from the updated parameters. The
      -- values were checked by Validate_Parameters at staging, so Set_Config
      -- will not reject them.
      Config : aliased Css_Comm_Config_C := Make_Config (Self);
   begin
      Set_Config (Self.Alg, Config'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the
   -- algorithm's own non-throwing Validate_Config predicate. Only Num_Sensors and
   -- the Chebyshev polynomials feed the config; Max_Sensor_Value (applied
   -- Ada-side) and Cheby_Count (no longer a config field) do not affect validity.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Num_Sensors : in Packed_U32.U;
      Max_Sensor_Value : in Packed_F64.U;
      Cheby_Count : in Packed_U32.U;
      Cheby_Polynomials : in Packed_F64x11.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self, Max_Sensor_Value, Cheby_Count);
      Config : aliased Css_Comm_Config_C :=
        (Num_Sensors       => Num_Sensors.Value,
         Max_Sensor_Values => [others => 1.0],
         Cheby_Polynomials => Css_Cheby_Polynomials_C (Packed_F64x11.C.To_C (Cheby_Polynomials)));
   begin
      if Validate_Config (Config'Access) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -- Description:
   --    Parameters for the Css Comm component
   -- Invalid Parameter handler. This procedure is called when a parameter's type is found to be invalid:
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the parameters should be invalid in this case.
      pragma Assert (False);
   end Invalid_Parameter;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Css Comm component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Css_Comm.Implementation;
