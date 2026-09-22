--------------------------------------------------------------------------------
-- Solar_Array_Reference Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Nav_Att_Output;
with Packed_F32;
with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_Array_Angle;
with Packed_Tracking_Mode;

package body Component.Solar_Array_Reference.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Apply_Config, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Drive_Axis : aliased Packed_F32x3_Record.C.U_C;
      Surface_Normal : aliased Packed_F32x3_Record.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration.
   function To_Pointer_Config (
      Drive_Axis : in Packed_F32x3.U;
      Surface_Normal : in Packed_F32x3.U
   ) return Pointer_Config is
      (Drive_Axis => (Value => Packed_F32x3.C.To_C (Drive_Axis)),
       Surface_Normal => (Value => Packed_F32x3.C.To_C (Surface_Normal)));

   -- Push the component's current configuration, the parameters and the last
   -- commanded mode and angles, into the C++ algorithm. Every reconfiguration path
   -- goes through here so the configuration is assembled in exactly one place.
   --
   -- Nothing is validated here, which is an exception to the usual guard in front
   -- of the throwing Set_Config. The parameters were validated at staging by
   -- Validate_Parameters, against the same commanded values that are applied here.
   -- The commanded values are valid to the algorithm by type: the mode is an
   -- enumeration with exactly the algorithm's values, and the angles are
   -- Array_Angle, whose range is the algorithm's accepted range. They originate as
   -- command arguments of the commanding component, where Adamant validates them
   -- against these types before the command is accepted. A value the algorithm
   -- would reject therefore cannot reach this component, and the tick does not
   -- check for one.
   procedure Apply_Config (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Drive_Axis, Self.Surface_Normal);
   begin
      Set_Config (
         Self.Alg,
         Drive_Axis            => Cfg.Drive_Axis'Access,
         Surface_Normal        => Cfg.Surface_Normal'Access,
         Alignment_Threshold   => Self.Alignment_Threshold.Value,
         Tracking_Mode         => Self.Commanded_Mode,
         Specified_Array_Angle => Self.Commanded_Angle,
         Offset_Angle          => Self.Commanded_Offset);
   end Apply_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the solar array reference algorithm with the default parameter
   -- values, sun tracking, and zero angles. The commanded mode and angles take effect
   -- when they are first received.
   overriding procedure Init (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Drive_Axis, Self.Surface_Normal);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Drive_Axis            => Cfg.Drive_Axis'Access,
         Surface_Normal        => Cfg.Surface_Normal'Access,
         Alignment_Threshold   => Self.Alignment_Threshold.Value,
         Tracking_Mode         => Self.Commanded_Mode,
         Specified_Array_Angle => Self.Commanded_Angle,
         Offset_Angle          => Self.Commanded_Offset);
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
      -- The attitude, the reference, and the sun direction are produced earlier in the
      -- same tick, so any other status indicates that this component is not wired up
      -- correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Attitude : Nav_Att_Output.T;
      Attitude_Status : constant Data_Dependency_Status.E :=
         Self.Get_Navigation_Attitude (Value => Attitude, Stale_Reference => Arg.Time);
      pragma Assert (Attitude_Status = Success);
      Reference : Att_Ref.T;
      Reference_Status : constant Data_Dependency_Status.E :=
         Self.Get_Attitude_Reference (Value => Reference, Stale_Reference => Arg.Time);
      pragma Assert (Reference_Status = Success);
      Sun_Direction : Packed_F32x3.T;
      Sun_Direction_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sun_Direction_Body (Value => Sun_Direction, Stale_Reference => Arg.Time);
      pragma Assert (Sun_Direction_Status = Success);
      -- The tracking mode and the angles are commanded sporadically, at state
      -- transitions rather than every control cycle, so on most ticks they come back
      -- Stale. Stale is a normal state here: the algorithm keeps the configuration it
      -- was last given. Success means a new command arrived this tick.
      Mode : Packed_Tracking_Mode.T;
      Mode_Status : constant Data_Dependency_Status.E :=
         Self.Get_Tracking_Mode (Value => Mode, Stale_Reference => Arg.Time);
      pragma Assert (Mode_Status = Success or else Mode_Status = Stale);
      Specified_Angle : Packed_Array_Angle.T;
      Specified_Angle_Status : constant Data_Dependency_Status.E :=
         Self.Get_Specified_Array_Angle (Value => Specified_Angle, Stale_Reference => Arg.Time);
      pragma Assert (Specified_Angle_Status = Success or else Specified_Angle_Status = Stale);
      Offset : Packed_Array_Angle.T;
      Offset_Status : constant Data_Dependency_Status.E :=
         Self.Get_Offset_Angle (Value => Offset, Stale_Reference => Arg.Time);
      pragma Assert (Offset_Status = Success or else Offset_Status = Stale);
   begin
      -- Apply any pending parameter update:
      Self.Update_Parameters;

      -- A new command reconfigures the algorithm. The commanded values are
      -- configuration to it, so the whole configuration is pushed at once. They are
      -- not validated here: see Apply_Config.
      if Mode_Status = Success or else
         Specified_Angle_Status = Success or else
         Offset_Status = Success
      then
         Self.Commanded_Mode := Solar_Array_Reference_Enums.Tracking_Mode.C.To_C (Mode.Value);
         Self.Commanded_Angle := Specified_Angle.Value;
         Self.Commanded_Offset := Offset.Value;
         Apply_Config (Self);
      end if;

      -- Call the C algorithm and publish the reference angle. Only the attitudes are
      -- taken from the navigation and reference records, straight from the packed
      -- fields the shim needs. When the sun is nearly along the drive axis the
      -- algorithm returns the angle it retained from the previous tick.
      -- Update is qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Reference_Angle (
         Arg.Time,
         (Value => Solar_Array_Reference_Algorithm_C.Update (
            Self.Alg,
            Sigma_Bn      => (Value => Packed_F32x3.C.Unpack (Attitude.Sigma_Bn)),
            Sigma_Rn      => (Value => Packed_F32x3.C.Unpack (Reference.Sigma_Rn)),
            R_Hat_In_Sb_B => (Value => Packed_F32x3.C.Unpack (Sun_Direction))))
      ));
   end Tick_T_Recv_Sync;

   -- Zero the reference angle the algorithm retains from the previous tick, which is
   -- its fallback when the sun is aligned with the drive axis. The configuration is
   -- untouched.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
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
   --    Parameters for the Solar Array Reference component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new axes and
   -- threshold together with the last commanded mode and angles.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      Apply_Config (Self);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. The predicate is asked together with the last commanded mode and
   -- angles, so it covers the whole configuration rather than only the staged half.
   -- Rejecting an invalid update here at staging keeps it from reaching the throwing
   -- Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Drive_Axis : in Packed_F32x3.U;
      Surface_Normal : in Packed_F32x3.U;
      Alignment_Threshold : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Drive_Axis, Surface_Normal);
      if Validate_Config (
         Drive_Axis            => Cfg.Drive_Axis'Access,
         Surface_Normal        => Cfg.Surface_Normal'Access,
         Alignment_Threshold   => Alignment_Threshold.Value,
         Tracking_Mode         => Self.Commanded_Mode,
         Specified_Array_Angle => Self.Commanded_Angle,
         Offset_Angle          => Self.Commanded_Offset)
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
   --    Data dependencies for the Solar Array Reference component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Solar_Array_Reference.Implementation;
