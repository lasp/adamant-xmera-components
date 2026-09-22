--------------------------------------------------------------------------------
-- Mrp_Rotation Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Att_Ref.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Mrp_Rotation.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Initial_Sigma_Rr0 : aliased Packed_F32x3_Record.C.U_C;
      Omega_Rr0_R : aliased Packed_F32x3_Record.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration.
   function To_Pointer_Config (
      Initial_Sigma_Rr0 : in Packed_F32x3.U;
      Omega_Rr0_R : in Packed_F32x3.U
   ) return Pointer_Config is
      (Initial_Sigma_Rr0 => (Value => Packed_F32x3.C.To_C (Initial_Sigma_Rr0)),
       Omega_Rr0_R => (Value => Packed_F32x3.C.To_C (Omega_Rr0_R)));

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
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Initial_Sigma_Rr0, Self.Omega_Rr0_R);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (
         Initial_Sigma_Rr0 => Cfg.Initial_Sigma_Rr0'Access,
         Omega_Rr0_R       => Cfg.Omega_Rr0_R'Access,
         Control_Period    => Self.Control_Period);
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
      -- The base reference is produced by a pointing component earlier in the same
      -- tick, so any other status indicates that this component is not wired up
      -- correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Base_Reference : Att_Ref.T;
      Base_Reference_Status : constant Data_Dependency_Status.E :=
         Self.Get_Base_Attitude_Reference (Value => Base_Reference, Stale_Reference => Arg.Time);
      pragma Assert (Base_Reference_Status = Success);

      -- Convert to the C type. The reference record and the algorithm's input share
      -- one layout, so the dependency crosses with no intermediate record. It crosses
      -- by pointer, so it needs an object to point at.
      Base_Reference_C : aliased constant Att_Ref.C.U_C := Att_Ref.C.Unpack (Base_Reference);
   begin
      -- Apply any pending parameter update:
      Self.Update_Parameters;

      -- Call the C algorithm and publish the rotated reference. Update is qualified
      -- because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Attitude_Reference (
         Arg.Time,
         Att_Ref.C.Pack (Mrp_Rotation_Algorithm_C.Update (Self.Alg, Att_Ref_Input => Base_Reference_C'Access))
      ));
   end Tick_T_Recv_Sync;

   -- Restart the rotation from the configured initial attitude. Called on GNC state
   -- change so the rotation does not carry over from the previous state.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Re-seeds the rotation state only; the configuration is untouched.
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
   -- push the whole configuration into the C algorithm so subsequent updates use the new initial
   -- attitude and rotation rate. The control period is fixed at initialization.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Initial_Sigma_Rr0, Self.Omega_Rr0_R);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Initial_Sigma_Rr0 => Cfg.Initial_Sigma_Rr0'Access,
         Omega_Rr0_R       => Cfg.Omega_Rr0_R'Access,
         Control_Period    => Self.Control_Period);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Initial_Sigma_Rr0 : in Packed_F32x3.U;
      Omega_Rr0_R : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Initial_Sigma_Rr0, Omega_Rr0_R);
      -- The algorithm only requires finite values, and marshalling a non-finite one
      -- raises above, so the predicate cannot fail here today. It is still the guard
      -- should the algorithm's rules grow.
      return (if Validate_Config (
                 Initial_Sigma_Rr0 => Cfg.Initial_Sigma_Rr0'Access,
                 Omega_Rr0_R       => Cfg.Omega_Rr0_R'Access,
                 Control_Period    => Self.Control_Period)
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
   -- Description:
   --    Data dependencies for the Mrp Rotation component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Mrp_Rotation.Implementation;
