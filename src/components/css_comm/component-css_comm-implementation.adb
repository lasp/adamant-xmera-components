--------------------------------------------------------------------------------
-- Css_Comm Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values;
with Css_Adc_U16_8;
with Cheby_Polynomials.C;
with Packed_F64x11.C;
with Interfaces;

package body Component.Css_Comm.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the CSS comm algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
      -- The number of CSS sensors is fixed by the hardware interface: the
      -- ADC data dependency carries exactly Css_Adc_U16_8.Length channels.
      Set_Num_Sensors (Self.Alg, Interfaces.Unsigned_32 (Css_Adc_U16_8.Length));
      -- Apply the Ada parameter defaults to the algorithm: the framework
      -- invokes Update_Parameters_Action only after a ground parameter
      -- update, and the C++ constructor defaults do not match the Ada
      -- defaults.
      Self.Update_Parameters_Action;
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
      -- Construct Chebyshev polynomials C type from parameter:
      Cheby_Poly_C : aliased Cheby_Polynomials.C.U_C := (
         Data => Packed_F64x11.C.To_C (Self.Cheby_Polynomials)
      );
   begin
      Set_Max_Sensor_Value (Self.Alg, Self.Max_Sensor_Value.Value);
      Set_Cheby_Count (Self.Alg, Self.Cheby_Count.Value);
      Set_Cheby_Polynomials (Self.Alg, Cheby_Poly_C'Access);
   end Update_Parameters_Action;

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
