--------------------------------------------------------------------------------
-- Sun_Avoidance Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Att_Ref.C;
with Cartesian_State;
with Nav_Att_Output;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_F64x3.C;
with Packed_F64x3_Record.C;

package body Component.Sun_Avoidance.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sun avoidance algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
      -- The sensitive axis crosses by pointer, so it needs an object to point at.
      Sensitive_Hat_C : aliased constant Packed_F32x3_Record.C.U_C :=
         (Value => Packed_F32x3.C.To_C (Self.Sensitive_Hat_B));
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Sensitive_Hat_B => Sensitive_Hat_C'Access,
         Slew_Rate       => Self.Slew_Rate.Value);
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
      -- All four inputs are published fresh earlier in the same tick by the attitude
      -- filter, the upstream guidance, and the ephemeris components, so any other
      -- status indicates that this component is not wired up correctly in the
      -- algorithm execution order. That should never happen, so we assert.
      Attitude : Nav_Att_Output.T;
      Attitude_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Attitude, Stale_Reference => Arg.Time);
      pragma Assert (Attitude_Status = Success);
      Reference : Att_Ref.T;
      Reference_Status : constant Data_Dependency_Status.E :=
         Self.Get_Input_Attitude_Reference (Value => Reference, Stale_Reference => Arg.Time);
      pragma Assert (Reference_Status = Success);
      Spacecraft : Cartesian_State.T;
      Spacecraft_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_State (Value => Spacecraft, Stale_Reference => Arg.Time);
      pragma Assert (Spacecraft_Status = Success);
      Sun : Cartesian_State.T;
      Sun_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sun_State (Value => Sun, Stale_Reference => Arg.Time);
      pragma Assert (Sun_Status = Success);

      -- Convert to the C vectors the algorithm consumes: the attitude MRP, the whole
      -- input reference, and the spacecraft and Sun positions, each converted straight
      -- from its packed record. All cross by pointer, so they need objects to point at.
      Sigma_Bn_C : aliased constant Packed_F32x3_Record.C.U_C :=
         (Value => Packed_F32x3.C.Unpack (Attitude.Sigma_Bn));
      Reference_C : aliased constant Att_Ref.C.U_C := Att_Ref.C.Unpack (Reference);
      Spacecraft_R_C : aliased constant Packed_F64x3_Record.C.U_C :=
         (Value => Packed_F64x3.C.Unpack (Spacecraft.Position));
      Sun_R_C : aliased constant Packed_F64x3_Record.C.U_C :=
         (Value => Packed_F64x3.C.Unpack (Sun.Position));

      -- The algorithm measures the elapsed slew from the call time in nanoseconds. The
      -- tick time carries 16-bit binary subseconds.
      Call_Time_Ns : constant Unsigned_64 :=
         Unsigned_64 (Arg.Time.Seconds) * 1_000_000_000 +
         (Unsigned_64 (Arg.Time.Subseconds) * 1_000_000_000) / 65_536;
   begin
      -- Apply any pending parameter update (e.g. a new sensitive axis or slew rate):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the adjusted reference. Update is qualified
      -- because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Attitude_Reference (
         Arg.Time,
         Att_Ref.C.Pack (Sun_Avoidance_Algorithm_C.Update (
            Self.Alg,
            Sigma_Bn  => Sigma_Bn_C'Access,
            Ref       => Reference_C'Access,
            R_Bn_N    => Spacecraft_R_C'Access,
            R_Sn_N    => Sun_R_C'Access,
            Call_Time => Call_Time_Ns))
      ));
   end Tick_T_Recv_Sync;

   -- Discard the planned slew so the next tick plans a new one from the current
   -- geometry. Must be called on any transition into the guidance mode that uses this
   -- component.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clears the planned slew only; the configuration is untouched.
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
   --    Parameters for the Sun Avoidance component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm. The planned slew is kept.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- The sensitive axis crosses by pointer, so it needs an object to point at.
      Sensitive_Hat_C : aliased constant Packed_F32x3_Record.C.U_C :=
         (Value => Packed_F32x3.C.To_C (Self.Sensitive_Hat_B));
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Sensitive_Hat_B => Sensitive_Hat_C'Access,
         Slew_Rate       => Self.Slew_Rate.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sensitive_Hat_B : in Packed_F32x3.U;
      Slew_Rate : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- The sensitive axis crosses by pointer, so it needs an object to point at. It is
      -- filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Sensitive_Hat_C : aliased Packed_F32x3_Record.C.U_C;
   begin
      Sensitive_Hat_C := (Value => Packed_F32x3.C.To_C (Sensitive_Hat_B));
      if Validate_Config (
         Sensitive_Hat_B => Sensitive_Hat_C'Access,
         Slew_Rate       => Slew_Rate.Value)
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
   --    Data dependencies for the Sun Avoidance component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Sun_Avoidance.Implementation;
