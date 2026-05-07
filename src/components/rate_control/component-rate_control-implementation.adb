--------------------------------------------------------------------------------
-- Rate_Control Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record;
with Packed_F32x3_Record.C;
with Packed_F32x9.C;
with Packed_F32x9_Record.C;

package body Component.Rate_Control.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the rate control algorithm.
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
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      Att_Guid_Dep : Att_Guid.T;
      Att_Guid_Status : constant Data_Dependency_Status.E :=
         Self.Get_Attitude_Guidance (Value => Att_Guid_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Att_Guid_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call algorithm:
      declare
         -- Wrap the two Att_Guid fields the algorithm uses (omega_BR_B,
         -- domega_RN_B) in C-pass-by-copy records that map to Vector3f_c on
         -- the C++ side. The remaining Att_Guid fields are unused by the
         -- current algorithm.
         Omega_BR_B_C : aliased Packed_F32x3_Record.C.U_C :=
            (Value => Packed_F32x3.C.To_C (Packed_F32x3.Unpack (Att_Guid_Dep.Omega_Br_B)));
         Domega_RN_B_C : aliased Packed_F32x3_Record.C.U_C :=
            (Value => Packed_F32x3.C.To_C (Packed_F32x3.Unpack (Att_Guid_Dep.Domega_Rn_B)));

         -- Call the C algorithm. Vector3f_c is returned by value into the
         -- Packed_F32x3_Record.C.U_C record; both are 3 contiguous floats
         -- with the same C_Pass_By_Copy ABI.
         Torque_Cmd : constant Packed_F32x3_Record.C.U_C := Update (
            Self.Alg,
            Omega_BR_B  => Omega_BR_B_C'Unchecked_Access,
            Domega_RN_B => Domega_RN_B_C'Unchecked_Access
         );
      begin
         -- Send out data product:
         Self.Data_Product_T_Send (Self.Data_Products.Torque_Command (
            Arg.Time,
            Packed_F32x3_Record.Pack (Packed_F32x3_Record.C.To_Ada (Torque_Cmd))
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
   -- This procedure is called when the parameters of a component have been updated. The default implementation of this
   -- subprogram in the implementation package is a null procedure. However, this procedure can, and should be implemented if
   -- something special needs to happen after a parameter update. Examples of this might be copying certain parameters to
   -- hardware registers, or performing other special functionality that only needs to be performed after parameters have
   -- been updated.
   --
   -- In this case we need update the inertia and the P gain if they changed.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- Wrap the inertia parameter in a C-pass-by-copy record that maps to
      -- Matrix3f_c on the C++ side. Layout is row-major; the algorithm rejects
      -- non-symmetric inertias so row/column-major are equivalent.
      Inertia_C : aliased Packed_F32x9_Record.C.U_C :=
         (Value => Packed_F32x9.C.To_C (Self.Spacecraft_Inertia));
   begin
      -- Set spacecraft inertia and gain before each update:
      Set_Spacecraft_Inertia (Self.Alg, Inertia_C'Unchecked_Access);
      Set_Derivative_Gain_P (Self.Alg, Self.Derivative_Gain_P.Value);
   end Update_Parameters_Action;

   -- Description:
   --    Parameters for the Rate Control component
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
   --    Data dependencies for the Rate Control component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Rate_Control.Implementation;
