--------------------------------------------------------------------------------
-- Sun_Search_Point Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Rotation_Properties_X4_Record.C;

package body Component.Sun_Search_Point.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sun search point algorithm.
   overriding procedure Init (Self : in out Instance) is
      use Parameter_Validation_Status;
      -- Create takes the rotation sequence by pointer, so it needs an object to point at.
      Rotations_C : aliased constant Rotation_Properties_X4_Record.C.U_C :=
         Rotation_Properties_X4_Record.C.To_C (Self.Rotations);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form
      -- a valid one. Assert through Validate_Parameters, the component's single
      -- validation gate, rather than calling Validate_Config a second time here.
      pragma Assert (Self.Validate_Parameters (
         Rotations             => Self.Rotations,
         S_Hat_Bdy_Cmd         => Self.S_Hat_Bdy_Cmd,
         Sun_Axis_Spin_Rate    => Self.Sun_Axis_Spin_Rate,
         Omega_Rn_B_Cfg        => Self.Omega_Rn_B_Cfg,
         Observation_Threshold => Self.Observation_Threshold,
         Control_Period        => Self.Control_Period) = Valid);
      Self.Alg := Create (
         Rotations             => Rotations_C'Access,
         S_Hat_Bdy_Cmd         => (Value => Packed_F32x3.C.To_C (Self.S_Hat_Bdy_Cmd)),
         Sun_Axis_Spin_Rate    => Self.Sun_Axis_Spin_Rate.Value,
         Omega_Rn_B            => (Value => Packed_F32x3.C.To_C (Self.Omega_Rn_B_Cfg)),
         Observation_Threshold => Self.Observation_Threshold.Value,
         Control_Period        => Self.Control_Period.Value);
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
      Omega_Bn_B : Packed_F32x3.T;
      Omega_Bn_B_Status : constant Data_Dependency_Status.E :=
         Self.Get_Omega_Bn_B (Value => Omega_Bn_B, Stale_Reference => Arg.Time);
      pragma Assert (Omega_Bn_B_Status = Success);

      R_Hat_Sb_B : Packed_F32x3.T;
      R_Hat_Sb_B_Status : constant Data_Dependency_Status.E :=
         Self.Get_R_Hat_Sb_B (Value => R_Hat_Sb_B, Stale_Reference => Arg.Time);
      pragma Assert (R_Hat_Sb_B_Status = Success);

      Css_Count : Packed_U32.T;
      Css_Count_Status : constant Data_Dependency_Status.E :=
         Self.Get_Num_Css_Viewing_Sun (Value => Css_Count, Stale_Reference => Arg.Time);
      pragma Assert (Css_Count_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Run one guidance step and publish its outputs:
      declare
         Output : constant Update_Result := Update (
            Self.Alg,
            R_Hat_Sb_B          => (Value => Packed_F32x3.C.Unpack (R_Hat_Sb_B)),
            Omega_Bn_B          => (Value => Packed_F32x3.C.Unpack (Omega_Bn_B)),
            Num_Css_Viewing_Sun => Css_Count.Value
         );
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Sigma_Br (Arg.Time, Output.Sigma_Br));
         Self.Data_Product_T_Send (Self.Data_Products.Omega_Br_B (Arg.Time, Output.Omega_Br_B));
         Self.Data_Product_T_Send (Self.Data_Products.Omega_Rn_B (Arg.Time, Output.Omega_Rn_B));
         Self.Data_Product_T_Send (Self.Data_Products.Fault_Detected (Arg.Time, (Value => Output.Fault_Detected)));
      end;
   end Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -- Re-arm the sun search sequence so the next tick restarts at the first rotation.
   -- Called on GNC state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clears the runtime state machine only; the configuration is untouched.
      Re_Initialize (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Sun Search Point component
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- Set_Config takes the rotation sequence by pointer, so it needs an object to point at.
      Rotations_C : aliased constant Rotation_Properties_X4_Record.C.U_C :=
         Rotation_Properties_X4_Record.C.To_C (Self.Rotations);
   begin
      -- Rebuild the algorithm configuration from the updated parameters. The values were
      -- checked by Validate_Parameters at staging, so Set_Config will not reject them.
      -- The search phase keeps running where it was; the reset connector re-arms it.
      Set_Config (
         Self.Alg,
         Rotations             => Rotations_C'Access,
         S_Hat_Bdy_Cmd         => (Value => Packed_F32x3.C.To_C (Self.S_Hat_Bdy_Cmd)),
         Sun_Axis_Spin_Rate    => Self.Sun_Axis_Spin_Rate.Value,
         Omega_Rn_B            => (Value => Packed_F32x3.C.To_C (Self.Omega_Rn_B_Cfg)),
         Observation_Threshold => Self.Observation_Threshold.Value,
         Control_Period        => Self.Control_Period.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Rotations : in Rotation_Properties_X4_Record.U;
      S_Hat_Bdy_Cmd : in Packed_F32x3.U;
      Sun_Axis_Spin_Rate : in Packed_F32.U;
      Omega_Rn_B_Cfg : in Packed_F32x3.U;
      Observation_Threshold : in Packed_U32.U;
      Control_Period : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Validate_Config takes the rotation sequence by pointer, so it needs an object to point at.
      Rotations_C : aliased constant Rotation_Properties_X4_Record.C.U_C :=
         Rotation_Properties_X4_Record.C.To_C (Rotations);
   begin
      if Validate_Config (
            Rotations             => Rotations_C'Access,
            S_Hat_Bdy_Cmd         => (Value => Packed_F32x3.C.To_C (S_Hat_Bdy_Cmd)),
            Sun_Axis_Spin_Rate    => Sun_Axis_Spin_Rate.Value,
            Omega_Rn_B            => (Value => Packed_F32x3.C.To_C (Omega_Rn_B_Cfg)),
            Observation_Threshold => Observation_Threshold.Value,
            Control_Period        => Control_Period.Value)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float array staging accepts a
      -- non-finite value, and marshalling it in Packed_F32x3.C.To_C raises. Rejecting the set
      -- here keeps that from unwinding into the Parameters component.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Sun Search Point component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
      Ignore_Self : Instance renames Self;
      Ignore_Id : Data_Product_Types.Data_Product_Id renames Id;
      Ignore_Ret : Data_Product_Return.T renames Ret;
   begin
      -- An invalid data dependency means the assembly is wired incorrectly, which should
      -- never happen at runtime.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Sun_Search_Point.Implementation;
