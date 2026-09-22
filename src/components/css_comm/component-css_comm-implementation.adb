--------------------------------------------------------------------------------
-- Css_Comm Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values.C;
with Cheby_Polynomials.C;
with Packed_F64x8.C;
with Packed_F64x11.C;

package body Component.Css_Comm.Implementation is

   -- Local alias for the Chebyshev-polynomial C record. Validate_Parameters has a
   -- formal named Cheby_Polynomials which shadows the with'd package of the same
   -- name, so we refer to the record type through this alias instead.
   subtype Cheby_Polynomials_C_Type is Cheby_Polynomials.C.U_C;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the CSS comm algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- The array arguments cross by reference, so they need aliased objects to
      -- point at and cannot be marshalled inline.
      Max_Sensor_Values : aliased Packed_F64x8.C.U_C := [others => Self.Max_Sensor_Value.Value];
      Cheby_Poly_C : aliased Cheby_Polynomials_C_Type := (Data => Packed_F64x11.C.To_C (Self.Cheby_Polynomials));
   begin
      Self.Alg := Create (
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

      -- Pass the raw ADC counts of every sensor slot to the C algorithm, which
      -- normalizes each reading by the Max_Sensor_Value parameter, applies the
      -- Chebyshev correction, and clamps the corrected value to [0, 1]. A
      -- corrected value that is not finite is reported as zero, no signal.
      declare
         Css_Input_C : aliased Css_Sensor_Values.C.U_C := (Data => [others => 0.0]);
      begin
         for I in Css_Adc_Input.Adc_Value'Range loop
            Css_Input_C.Data (I) := Long_Float (Css_Adc_Input.Adc_Value (I));
         end loop;

         -- Publish the corrected cosine values stamped with the timestamp of the
         -- fetched ADC reading (not the tick time) so downstream consumers see
         -- the true data age.
         declare
            Css_Output : constant Css_Sensor_Values.C.U_C := Update (
               Self.Alg,
               Input_Values => Css_Input_C'Access
            );
         begin
            Self.Data_Product_T_Send (
               Self.Data_Products.Css_Sensor_Output (Css_Input_Time, Css_Sensor_Values.C.Pack (Css_Output)));
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
      Max_Sensor_Values : aliased Packed_F64x8.C.U_C := [others => Self.Max_Sensor_Value.Value];
      Cheby_Poly_C : aliased Cheby_Polynomials_C_Type := (
         Data => Packed_F64x11.C.To_C (Self.Cheby_Polynomials)
      );
   begin
      Set_Config (
         Self.Alg,
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
      Max_Sensor_Values : aliased Packed_F64x8.C.U_C := [others => Max_Sensor_Value.Value];
      Cheby_Poly_C : aliased Cheby_Polynomials_C_Type := (Data => Packed_F64x11.C.To_C (Cheby_Polynomials));
   begin
      if Validate_Config (
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
