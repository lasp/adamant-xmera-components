--------------------------------------------------------------------------------
-- Triad Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Triad.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Sada_Hat_B : aliased Packed_F32x3_Record.C.U_C;
      Thrust_Req_Hat_N : aliased Packed_F32x3_Record.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration.
   function To_Pointer_Config (
      Sada_Hat_B : in Packed_F32x3.U;
      Thrust_Req_Hat_N : in Packed_F32x3.U
   ) return Pointer_Config is
      (Sada_Hat_B => (Value => Packed_F32x3.C.To_C (Sada_Hat_B)),
       Thrust_Req_Hat_N => (Value => Packed_F32x3.C.To_C (Thrust_Req_Hat_N)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the triad algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Sada_Hat_B, Self.Thrust_Req_Hat_N);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Sada_Hat_B       => Cfg.Sada_Hat_B'Access,
         Thrust_Req_Hat_N => Cfg.Thrust_Req_Hat_N'Access,
         N3_Axis          => To_C (Self.N3_Axis.Value));
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
      -- Both directions are produced earlier in the same tick, so any other status
      -- indicates that this component is not wired up correctly in the algorithm
      -- execution order. That should never happen, so we assert.
      Sun_Direction : Packed_F32x3.T;
      Sun_Direction_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sun_Direction_Inertial (Value => Sun_Direction, Stale_Reference => Arg.Time);
      pragma Assert (Sun_Direction_Status = Success);
      Thrust_Direction : Packed_F32x3.T;
      Thrust_Direction_Status : constant Data_Dependency_Status.E :=
         Self.Get_Thrust_Direction_Body (Value => Thrust_Direction, Stale_Reference => Arg.Time);
      pragma Assert (Thrust_Direction_Status = Success);

      -- Convert to C types. Both cross by pointer, so they need objects to point at.
      Sun_Direction_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Sun_Direction));
      Thrust_Direction_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Thrust_Direction));
   begin
      -- Apply any pending parameter update:
      Self.Update_Parameters;

      -- Call the C algorithm and publish the reference. The algorithm produces an
      -- attitude only, so the reference rate and acceleration are zero. Update is
      -- qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Attitude_Reference (
         Arg.Time,
         (Sigma_Rn => Packed_F32x3.C.Pack (Triad_Algorithm_C.Update (
             Self.Alg,
             R_Hat_Sb_N   => Sun_Direction_C'Access,
             Thrust_Hat_B => Thrust_Direction_C'Access).Value),
          Omega_Rn_N => [others => 0.0],
          Domega_Rn_N => [others => 0.0])
      ));
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
   -- Description:
   --    Parameters for the Triad component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new axes.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Sada_Hat_B, Self.Thrust_Req_Hat_N);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Sada_Hat_B       => Cfg.Sada_Hat_B'Access,
         Thrust_Req_Hat_N => Cfg.Thrust_Req_Hat_N'Access,
         N3_Axis          => To_C (Self.N3_Axis.Value));
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sada_Hat_B : in Packed_F32x3.U;
      Thrust_Req_Hat_N : in Packed_F32x3.U;
      N3_Axis : in Packed_N3_Axis.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Sada_Hat_B, Thrust_Req_Hat_N);
      if Validate_Config (
         Sada_Hat_B       => Cfg.Sada_Hat_B'Access,
         Thrust_Req_Hat_N => Cfg.Thrust_Req_Hat_N'Access,
         N3_Axis          => To_C (N3_Axis.Value))
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
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
   --    Data dependencies for the Triad component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Triad.Implementation;
