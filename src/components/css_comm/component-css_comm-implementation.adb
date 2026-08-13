--------------------------------------------------------------------------------
-- Css_Comm Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values;
with Css_Adc_U16_8;
with Cheby_Polynomials.C;
with Packed_F64x11.C;
with Interfaces;

package body Component.Css_Comm.Implementation is

   -- Local alias for the Chebyshev-polynomial C record. Validate_Parameters has a
   -- formal named Cheby_Polynomials which shadows the with'd package of the same
   -- name, so we refer to the record type through this alias instead.
   subtype Cheby_Polynomials_C_Type is Cheby_Polynomials.C.U_C;

   -- Build the per-sensor max-value array by broadcasting the single Max_Sensor_Value
   -- parameter across the active channels. The C algorithm scales each sensor by its
   -- own maxSensorValues entry; the component uses one shared scale factor, and the
   -- number of active sensors is fixed by the ADC data dependency width. Trailing
   -- (non-physical) entries stay zero.
   function Make_Max_Sensor_Values (Max_Value : Long_Float) return Css_Values_Array_C is
      Result : Css_Values_Array_C := [others => 0.0];
   begin
      for I in 0 .. Css_Adc_U16_8.Length - 1 loop
         Result (I) := Max_Value;
      end loop;
      return Result;
   end Make_Max_Sensor_Values;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the CSS comm algorithm.
   overriding procedure Init (Self : in out Instance) is
      use Parameter_Validation_Status;

      -- The array arguments cross by reference, so they need aliased objects to
      -- point at and cannot be marshalled inline.
      Max_Sensor_Values : aliased Css_Values_Array_C := Make_Max_Sensor_Values (Self.Max_Sensor_Value.Value);
      Cheby_Poly_C : aliased Cheby_Polynomials_C_Type := (Data => Packed_F64x11.C.To_C (Self.Cheby_Polynomials));
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form
      -- a valid one. Assert through Validate_Parameters, the component's single
      -- validation gate, rather than calling Validate_Config a second time here.
      pragma Assert (Self.Validate_Parameters (
         Max_Sensor_Value  => Self.Max_Sensor_Value,
         Cheby_Count       => Self.Cheby_Count,
         Cheby_Polynomials => Self.Cheby_Polynomials) = Valid);
      -- The number of CSS sensors is fixed by the hardware interface: the ADC data
      -- dependency carries exactly Css_Adc_U16_8.Length channels.
      Self.Alg := Create (
         Num_Sensors       => Interfaces.Unsigned_32 (Css_Adc_U16_8.Length),
         Max_Sensor_Values => Max_Sensor_Values'Access,
         Polynomials       => Cheby_Poly_C'Access);
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
      -- fetch returns Success or Stale. A stale reading is processed just like a
      -- fresh one and published with the reading's original timestamp, so the
      -- downstream filter receives the old data and can judge it by its age.
      -- Not_Available (no value was ever made available) and Error (ID/length
      -- mismatch) indicate an assembly/configuration defect, so we assert.
      -- (Error additionally trips Invalid_Data_Dependency below before
      -- returning.)
      Css_Adc_Input : Css_Array_Adc_8.T;
      Css_Input_Time : Sys_Time.T;
      Css_Input_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Adc_Input, Timestamp => Css_Input_Time, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success or else Css_Input_Status = Stale);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Pass the raw ADC counts to the C algorithm, which normalizes each
      -- reading by the Max_Sensor_Value parameter, applies the Chebyshev
      -- correction, and clamps the corrected value to [0, 1]. Entries beyond
      -- the physical ADC channels are zero-padded up to the C algorithm's
      -- MAX_NUM_CSS_SENSORS bound.
      declare
         Css_Input_C : aliased Css_Sensor_Values_C := (Data => [others => 0.0]);
      begin
         for I in Css_Adc_Input.Adc_Value'Range loop
            Css_Input_C.Data (Css_Input_C.Data'First + Natural (I - Css_Adc_Input.Adc_Value'First)) :=
               Long_Float (Css_Adc_Input.Adc_Value (I));
         end loop;

         -- Call the algorithm and publish the corrected cosine values as the
         -- data product, stamped with the timestamp of the fetched ADC reading
         -- (not the tick time) so downstream consumers see the true data age.
         -- Css_Sensor_Values.T is narrower than the C algorithm's
         -- MAX_NUM_CSS_SENSORS bound; the trailing entries of the C output
         -- correspond to no physical sensor and are not published.
         declare
            Css_Output : constant Css_Sensor_Values_C := Update (
               Self.Alg,
               Input_Values => Css_Input_C'Access
            );
            Out_Product : Css_Sensor_Values.T := (Data => [others => 0.0]);
         begin
            for I in Out_Product.Data'Range loop
               Out_Product.Data (I) := Css_Output.Data (Css_Output.Data'First + Natural (I - Out_Product.Data'First));
            end loop;
            Self.Data_Product_T_Send (Self.Data_Products.Css_Sensor_Output (Css_Input_Time, Out_Product));
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
      -- Rebuild the algorithm configuration from the updated parameters. The values
      -- were checked by Validate_Parameters at staging, so Set_Config will not reject
      -- them. Cheby_Count has no counterpart in the flattened config (the algorithm
      -- uses all MAX_NUM_CHEBY_POLYS coefficients) and is intentionally not applied.
      Max_Sensor_Values : aliased Css_Values_Array_C := Make_Max_Sensor_Values (Self.Max_Sensor_Value.Value);
      Cheby_Poly_C : aliased Cheby_Polynomials_C_Type := (
         Data => Packed_F64x11.C.To_C (Self.Cheby_Polynomials)
      );
   begin
      Set_Config (
         Self.Alg,
         Num_Sensors       => Interfaces.Unsigned_32 (Css_Adc_U16_8.Length),
         Max_Sensor_Values => Max_Sensor_Values'Access,
         Polynomials       => Cheby_Poly_C'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's
   -- own non-throwing Validate_Config predicate, so the config rules live solely in
   -- the algorithm. Rejecting an invalid update here at staging keeps it from reaching
   -- the throwing Create/Set_Config across the FFI boundary. Cheby_Count does not
   -- participate in the flattened config and is not validated here.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Max_Sensor_Value : in Packed_F64.U;
      Cheby_Count : in Packed_U32.U;
      Cheby_Polynomials : in Packed_F64x11.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self, Cheby_Count);
      Max_Sensor_Values : aliased Css_Values_Array_C := Make_Max_Sensor_Values (Max_Sensor_Value.Value);
      Cheby_Poly_C : aliased Cheby_Polynomials_C_Type := (Data => Packed_F64x11.C.To_C (Cheby_Polynomials));
   begin
      if Validate_Config (
            Num_Sensors       => Interfaces.Unsigned_32 (Css_Adc_U16_8.Length),
            Max_Sensor_Values => Max_Sensor_Values'Access,
            Polynomials       => Cheby_Poly_C'Access)
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
   --    Data dependencies for the Css Comm component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Css_Comm.Implementation;
