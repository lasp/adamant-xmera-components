--------------------------------------------------------------------------------
-- Solar_Array_Reference Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Nav_Att_Output;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Solar_Array_Reference_Enums;

package body Component.Solar_Array_Reference.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
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

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the solar array reference algorithm with the default parameter
   -- values.
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
         Tracking_Mode         => Solar_Array_Reference_Enums.Tracking_Mode.C.To_C (Self.Mode.Value),
         Specified_Array_Angle => Self.Specified_Array_Angle.Value,
         Offset_Angle          => Self.Offset_Angle.Value);
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
      use Solar_Array_Reference_Enums;
      use type Solar_Array_Reference_Enums.Tracking_Mode.E;
      -- The attitudes and the sun direction the algorithm is called with. They are
      -- only fetched in the sun tracking mode. In the specified angle mode the
      -- algorithm reads none of them, so they are left at zero.
      Sigma_Bn : Packed_F32x3.T := [0.0, 0.0, 0.0];
      Sigma_Rn : Packed_F32x3.T := [0.0, 0.0, 0.0];
      Sun_Direction : Packed_F32x3.T := [0.0, 0.0, 0.0];
   begin
      -- Apply any pending parameter update, so a new tracking mode and angles take
      -- effect on the tick after their update:
      Self.Update_Parameters;

      -- In the sun tracking mode, grab the attitude, the reference, and the sun
      -- direction. They are produced earlier in the same tick, so any status other
      -- than Success indicates that this component is not wired up correctly in the
      -- algorithm execution order. That should never happen, so we assert. Only the
      -- attitudes are taken from the navigation and reference records, straight from
      -- the packed fields the shim needs.
      if Self.Mode.Value = Tracking_Mode.Auto_Track then
         declare
            Attitude : Nav_Att_Output.T;
            Attitude_Status : constant Data_Dependency_Status.E :=
               Self.Get_Navigation_Attitude (Value => Attitude, Stale_Reference => Arg.Time);
            pragma Assert (Attitude_Status = Success);
            Reference : Att_Ref.T;
            Reference_Status : constant Data_Dependency_Status.E :=
               Self.Get_Attitude_Reference (Value => Reference, Stale_Reference => Arg.Time);
            pragma Assert (Reference_Status = Success);
            Sun_Direction_Status : constant Data_Dependency_Status.E :=
               Self.Get_Sun_Direction_Body (Value => Sun_Direction, Stale_Reference => Arg.Time);
            pragma Assert (Sun_Direction_Status = Success);
         begin
            Sigma_Bn := Attitude.Sigma_Bn;
            Sigma_Rn := Reference.Sigma_Rn;
         end;
      end if;

      -- Call the C algorithm and publish the reference angle. When the sun is nearly
      -- along the drive axis the algorithm returns the angle it retained from the
      -- previous tick. Update is qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Reference_Angle (
         Arg.Time,
         (Value => Solar_Array_Reference_Algorithm_C.Update (
            Self.Alg,
            Sigma_Bn      => (Value => Packed_F32x3.C.Unpack (Sigma_Bn)),
            Sigma_Rn      => (Value => Packed_F32x3.C.Unpack (Sigma_Rn)),
            R_Hat_In_Sb_B => (Value => Packed_F32x3.C.Unpack (Sun_Direction))))
      ));
   end Tick_T_Recv_Sync;

   -- Zero the reference angle the algorithm retains from the previous tick, which is
   -- its fallback when the sun is aligned with the drive axis. The configuration is
   -- untouched.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update first, so the reset starts from the
      -- configuration the component runs with next:
      Self.Update_Parameters;
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
   --    Parameters for the Solar Array Reference component. The algorithm validates
   --    them all together, so a mode, angle, or axis it rejects never reaches it.

   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new values.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Drive_Axis, Self.Surface_Normal);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Drive_Axis            => Cfg.Drive_Axis'Access,
         Surface_Normal        => Cfg.Surface_Normal'Access,
         Alignment_Threshold   => Self.Alignment_Threshold.Value,
         Tracking_Mode         => Solar_Array_Reference_Enums.Tracking_Mode.C.To_C (Self.Mode.Value),
         Specified_Array_Angle => Self.Specified_Array_Angle.Value,
         Offset_Angle          => Self.Offset_Angle.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. The set holds the staged values together with the active values of
   -- the parameters the requesting table did not stage, so the mode and angles are
   -- validated against the array axes and vice versa. Rejecting an invalid set here
   -- at staging keeps it from reaching the throwing Set_Config across the FFI
   -- boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Drive_Axis : in Packed_F32x3.U;
      Surface_Normal : in Packed_F32x3.U;
      Alignment_Threshold : in Packed_F32.U;
      Mode : in Packed_Tracking_Mode.U;
      Specified_Array_Angle : in Packed_Array_Angle.U;
      Offset_Angle : in Packed_Array_Angle.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Drive_Axis, Surface_Normal);
      if Validate_Config (
         Drive_Axis            => Cfg.Drive_Axis'Access,
         Surface_Normal        => Cfg.Surface_Normal'Access,
         Alignment_Threshold   => Alignment_Threshold.Value,
         Tracking_Mode         => Solar_Array_Reference_Enums.Tracking_Mode.C.To_C (Mode.Value),
         Specified_Array_Angle => Specified_Array_Angle.Value,
         Offset_Angle          => Offset_Angle.Value)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the set here keeps
      -- that from unwinding into the caller.
      -- TODO: The generated validation of the staged bytes should reject a non-finite
      -- value, but GNAT Pro 25.2 evaluates 'Valid on an element of a packed float array
      -- with a non native Scalar_Storage_Order on the unswapped bytes, so at staging a
      -- NaN or infinity passes. FSF GCC fixed this in 60f5887173a4. Once the compiler
      -- fix arrives this handler is unreachable and can go, along with the injection in
      -- the parameter rejection test.
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
