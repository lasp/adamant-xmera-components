--------------------------------------------------------------------------------
-- Css_Comm Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values.C;
with Cheby_Polynomials.C;
with Packed_F64x10.C;

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
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      Css_Input : Css_Sensor_Values.T;
      Css_Input_Status : constant Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Input, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call algorithm:
      declare
         -- Convert Ada types to C types:
         Css_Input_C : aliased Css_Sensor_Values.C.U_C := Css_Sensor_Values.C.To_C (Css_Sensor_Values.Unpack (Css_Input));

         -- Call the C algorithm:
         Css_Output : constant Css_Sensor_Values.C.U_C := Update (
            Self.Alg,
            Input_Values => Css_Input_C'Unchecked_Access
         );
      begin
         -- Send out data product:
         Self.Data_Product_T_Send (Self.Data_Products.Css_Sensor_Output (
            Arg.Time,
            Css_Sensor_Values.Pack (Css_Sensor_Values.C.To_Ada (Css_Output))
         ));
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
         Data => Packed_F64x10.C.To_C (Self.Cheby_Polynomials)
      );
   begin
      Set_Num_Sensors (Self.Alg, Self.Num_Sensors.Value);
      Set_Max_Sensor_Value (Self.Alg, Long_Float (Self.Max_Sensor_Value.Value));
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
