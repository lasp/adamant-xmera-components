--------------------------------------------------------------------------------
-- Sunline_Srukf Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x32;
with Css_Sensor_Values;
with Sunline_Srukf_Input.C;
with Sunline_Srukf_Output.C;
with Sunline_Srukf_Algorithm_C; use Sunline_Srukf_Algorithm_C;

package body Component.Sunline_Srukf.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sunline SRuKF algorithm.
   overriding procedure Init (Self : in out Instance) is
      pragma Unreferenced (Self);
   begin
      -- Stateless algorithm, nothing to initialize.
      null;
   end Init;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      -- Body angular velocity (omega_BN_B) from body_rate_miscompare. The
      -- upstream product carries only the body rate; the SRuKF's other
      -- attitude inputs (MRP, sun vector, time tag) are not produced upstream
      -- and are zeroed below (preserving prior behavior).
      Sc_Att : Packed_F32x3.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);

      -- Coarse sun sensor cosine measurements (pre-converted from ADC by
      -- css_comm). Css_Sensor_Values.T's Data field carries the 8 physical
      -- CSS ADC channels.
      Css_Input : Css_Sensor_Values.T;
      Css_Input_Status : constant Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Input, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success);

      -- Build algorithm input from the body rate and CSS cosine data. Only
      -- Omega_Bn_B is supplied upstream; Sigma_Bn, Veh_Sun_Pnt_Bdy, and
      -- Time_Tag are zeroed (no upstream producer). N_Css tells the C
      -- algorithm how many real sensors it receives; cast each F64 cosine
      -- down to Short_Float and zero-pad the trailing entries of the wider
      -- Cos_Values FFI array past Css_Input.
      Input_C : aliased Sunline_Srukf_Input.C.U_C := (
         Time_Tag        => 0.0,
         Sigma_Bn        => Packed_F32x3.C.Unpack (Packed_F32x3.T'[0.0, 0.0, 0.0]),
         Omega_Bn_B      => Packed_F32x3.C.Unpack (Sc_Att),
         Veh_Sun_Pnt_Bdy => Packed_F32x3.C.Unpack (Packed_F32x3.T'[0.0, 0.0, 0.0]),
         N_Css           => Css_Input.Data'Length,
         Cos_Values      => [for I in Packed_F32x32.Constrained_Index_Type =>
            (if I <= Css_Input.Data'Last then Short_Float (Css_Input.Data (I)) else 0.0)]
      );

      -- Call the C algorithm:
      Output_C : constant Sunline_Srukf_Output.C.U_C := Update_State (
         Input => Input_C'Access
      );
   begin
      -- Send out data product:
      Self.Data_Product_T_Send (Self.Data_Products.Sunline_Srukf_State (
         Arg.Time,
         Sunline_Srukf_Output.Pack (Sunline_Srukf_Output.C.To_Ada (Output_C))
      ));
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Sunline SRuKF component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Sunline_Srukf.Implementation;
