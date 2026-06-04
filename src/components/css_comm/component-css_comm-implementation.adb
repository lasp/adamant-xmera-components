--------------------------------------------------------------------------------
-- Css_Comm Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values;
with Css_Sensor_Values.C;
with Cheby_Polynomials.C;
with Packed_F64x11.C;

package body Component.Css_Comm.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the CSS comm algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
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
      -- fetch returns Success or Stale. Stale values are acceptable: we process
      -- the last received ADC counts regardless of staleness (the value is
      -- populated on Stale). Not_Available (no value was ever made available) and
      -- Error (ID/length mismatch) indicate an assembly/configuration defect, so
      -- we assert. (Error additionally trips Invalid_Data_Dependency below before
      -- returning.)
      Css_Adc_Input : Css_Array_Adc_8.T;
      Css_Input_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Adc_Input, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success or else Css_Input_Status = Stale);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

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
      -- Construct Chebyshev polynomials C type from parameter:
      Cheby_Poly_C : aliased Cheby_Polynomials.C.U_C := (
         Data => Packed_F64x11.C.To_C (Self.Cheby_Polynomials)
      );
   begin
      Set_Num_Sensors (Self.Alg, Self.Num_Sensors.Value);
      -- Max_Sensor_Value is consumed by the Ada-side ADC->cosine conversion in
      -- Tick_T_Recv_Sync (matching the css_wls_estimator pattern). The C
      -- algorithm performs its own divide-by-max as part of the Chebyshev
      -- correction; pin it to 1.0 so the C divide is a no-op and the
      -- Ada-side conversion is the single source of truth for ADC scaling.
      Set_Max_Sensor_Value (Self.Alg, 1.0);
      Set_Cheby_Count (Self.Alg, Self.Cheby_Count.Value);
      Set_Cheby_Polynomials (Self.Alg, Cheby_Poly_C'Unchecked_Access);
   end Update_Parameters_Action;

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
