--------------------------------------------------------------------------------
-- Mrp_Pd Component Implementation Body
--------------------------------------------------------------------------------

with Att_Guid;
with Cmd_Torque_Body;
with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_F32x9.C;

package body Component.Mrp_Pd.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the MRP PD algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
   begin
      Self.Alg := Create (
         K                    => Self.Proportional_Gain_K.Value,
         P                    => Self.Derivative_Gain_P.Value,
         Known_Torque_Pnt_B_B => (Value => Packed_F32x3.C.To_C (Self.Known_Torque_Pnt_B_B)),
         Iscpnt_B_B           => (Value => Packed_F32x9.C.To_C (Self.Inertia))
      );
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

      -- The attitude guidance solution is produced by the attitude tracking error
      -- component earlier in the same tick, so it is fresh by construction. Any
      -- status other than Success means this component is not wired up correctly in
      -- the algorithm execution order, so we assert.
      Attitude_Guidance_Dep : Att_Guid.T;
      Attitude_Guidance_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Attitude_Guidance (Value => Attitude_Guidance_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Attitude_Guidance_Status = Success);

      Guidance : constant Att_Guid.U := Att_Guid.Unpack (Attitude_Guidance_Dep);
   begin
      -- Apply any pending parameter update (e.g. new gains or inertia):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the commanded body torque. The algorithm
      -- takes only the three error terms it acts on; Omega_Rn_B is not used.
      -- Update is qualified because Parameter_Enums also declares one.
      declare
         Torque : constant Packed_F32x3_Record.C.U_C := Mrp_Pd_Algorithm_C.Update (
            Self.Alg,
            Sigma_Br    => (Value => Packed_F32x3.C.To_C (Guidance.Sigma_Br)),
            Omega_Br_B  => (Value => Packed_F32x3.C.To_C (Guidance.Omega_Br_B)),
            Domega_Rn_B => (Value => Packed_F32x3.C.To_C (Guidance.Domega_Rn_B))
         );
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Control_Torque (
            Arg.Time,
            Cmd_Torque_Body.Pack ((Torque_Request_Body => Packed_F32x3.C.To_Ada (Torque.Value)))
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
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new gains,
   -- known torque, and inertia.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         K                    => Self.Proportional_Gain_K.Value,
         P                    => Self.Derivative_Gain_P.Value,
         Known_Torque_Pnt_B_B => (Value => Packed_F32x3.C.To_C (Self.Known_Torque_Pnt_B_B)),
         Iscpnt_B_B           => (Value => Packed_F32x9.C.To_C (Self.Inertia))
      );
   end Update_Parameters_Action;

   -- Validate a staged configuration before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate (non-negative gains, a finite known torque, and a
   -- valid inertia matrix), so the config rules live solely in the algorithm. Rejecting an
   -- invalid update here at staging keeps it from reaching the throwing Create/Set_Config
   -- across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Proportional_Gain_K : in Packed_F32.U;
      Derivative_Gain_P : in Packed_F32.U;
      Known_Torque_Pnt_B_B : in Packed_F32x3.U;
      Inertia : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
   begin
      if Validate_Config (
         K                    => Proportional_Gain_K.Value,
         P                    => Derivative_Gain_P.Value,
         Known_Torque_Pnt_B_B => (Value => Packed_F32x3.C.To_C (Known_Torque_Pnt_B_B)),
         Iscpnt_B_B           => (Value => Packed_F32x9.C.To_C (Inertia)))
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Mrp_Pd.Implementation;
