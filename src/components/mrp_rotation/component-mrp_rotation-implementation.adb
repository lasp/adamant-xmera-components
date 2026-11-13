--------------------------------------------------------------------------------
-- Mrp_Rotation Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Mrp_Rotation.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Sigma_Rcr0 : aliased Packed_F32x3_Record.C.U_C;
      Sigma_Rprc : aliased Packed_F32x3_Record.C.U_C;
      Spin_Axis_Rp : aliased Packed_F32x3_Record.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration.
   function To_Pointer_Config (
      Sigma_Rcr0 : in Packed_F32x3.U;
      Sigma_Rprc : in Packed_F32x3.U;
      Spin_Axis_Rp : in Packed_F32x3.U
   ) return Pointer_Config is
      (Sigma_Rcr0 => (Value => Packed_F32x3.C.To_C (Sigma_Rcr0)),
       Sigma_Rprc => (Value => Packed_F32x3.C.To_C (Sigma_Rprc)),
       Spin_Axis_Rp => (Value => Packed_F32x3.C.To_C (Spin_Axis_Rp)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the MRP rotation algorithm with the control period and the default
   -- parameter values.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates. The rotation advances by this much per tick, so it must
   -- equal the rate at which the component is scheduled. Fixed by the assembly, so
   -- it is not a runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Sigma_Rcr0, Self.Sigma_Rprc, Self.Spin_Axis_Rp);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (
         Sigma_Rcr0     => Cfg.Sigma_Rcr0'Access,
         Sigma_Rprc     => Cfg.Sigma_Rprc'Access,
         Spin_Axis_Rp   => Cfg.Spin_Axis_Rp'Access,
         Spin_Rate      => Self.Spin_Rate.Value,
         Control_Period => Self.Control_Period);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Rotate the attitude reference in the argument by the configured rotation,
   -- advanced to the tick in the argument, and return the result.
   overriding function Att_Ref_Tick_T_Service (Self : in out Instance; Arg : in Att_Ref_Tick.T) return Att_Ref.T is
      -- The reference crosses to the algorithm by pointer, so it needs an object to
      -- point at.
      Base_Reference_C : aliased constant Att_Ref.C.U_C := Att_Ref.C.Unpack (Arg.Reference);
   begin
      -- Apply any pending parameter update:
      Self.Update_Parameters;

      -- Call the C algorithm and hand the rotated reference back to the caller, which
      -- publishes the reference the control chain tracks. Update is qualified because
      -- Parameter_Enums also declares one.
      return Att_Ref.C.Pack (Mrp_Rotation_Algorithm_C.Update (Self.Alg, Att_Ref_Input => Base_Reference_C'Access));
   end Att_Ref_Tick_T_Service;

   -- Restart the integrated rotation at identity. Called on GNC state change so the
   -- rotation does not carry over from the previous state.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update first, so the reset starts from the
      -- configuration the component runs with next:
      Self.Update_Parameters;
      -- Restarts the rotation state only; the configuration is untouched.
      Re_Initialize (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Mrp Rotation component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new body
   -- correction, pointing offset, spin axis, and spin rate. The integrated rotation is kept. The
   -- control period is fixed at initialization.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Sigma_Rcr0, Self.Sigma_Rprc, Self.Spin_Axis_Rp);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Sigma_Rcr0     => Cfg.Sigma_Rcr0'Access,
         Sigma_Rprc     => Cfg.Sigma_Rprc'Access,
         Spin_Axis_Rp   => Cfg.Spin_Axis_Rp'Access,
         Spin_Rate      => Self.Spin_Rate.Value,
         Control_Period => Self.Control_Period);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sigma_Rcr0 : in Packed_F32x3.U;
      Sigma_Rprc : in Packed_F32x3.U;
      Spin_Axis_Rp : in Packed_F32x3.U;
      Spin_Rate : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Sigma_Rcr0, Sigma_Rprc, Spin_Axis_Rp);
      return (if Validate_Config (
                 Sigma_Rcr0     => Cfg.Sigma_Rcr0'Access,
                 Sigma_Rprc     => Cfg.Sigma_Rprc'Access,
                 Spin_Axis_Rp   => Cfg.Spin_Axis_Rp'Access,
                 Spin_Rate      => Spin_Rate.Value,
                 Control_Period => Self.Control_Period)
              then Parameter_Validation_Status.Valid else Parameter_Validation_Status.Invalid);
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the set here keeps
      -- that from unwinding into the Parameters component.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
end Component.Mrp_Rotation.Implementation;
