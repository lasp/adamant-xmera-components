--------------------------------------------------------------------------------
-- Convert_St_Platform_To_Body Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x9.C;
with St_Platform_Attitude;
with St_Platform_Angular_Velocity;
with St_Att;

package body Component.Convert_St_Platform_To_Body.Implementation is

   -- Build the C config POD from the component's Dcm_Cb parameter. The mounting
   -- DCM is the algorithm's only configuration input.
   function Make_Config (Self : Instance) return Convert_St_Platform_To_Body_Config_C is
     (Dcm_Cb => (Value => Packed_F32x9.C.To_C (Self.Dcm_Cb)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the convert star tracker platform to body algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- Build the initial configuration from the component's parameter default.
      -- The default Dcm_Cb is the identity matrix, a valid DCM, so Create will
      -- not reject it.
      Config : aliased Convert_St_Platform_To_Body_Config_C := Make_Config (Self);
   begin
      -- Allocate the C++ algorithm on the heap with the initial configuration.
      Self.Alg := Create (Config'Access);
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

      -- We assume both star-tracker data dependencies are available at startup, so
      -- a fetch returns Success or Stale. Star-tracker solutions update slowly
      -- relative to the tick rate, so stale values are acceptable: we process the
      -- last received solution regardless of staleness (the value is populated on
      -- Stale). Not_Available (no value was ever made available) and Error
      -- (ID/length mismatch) indicate an assembly/configuration defect, so we
      -- assert.
      Platform_Attitude_Dep : St_Platform_Attitude.T;
      Platform_Attitude_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Platform_Attitude (Value => Platform_Attitude_Dep, Stale_Reference => Arg.Time);
      Platform_Angular_Velocity_Dep : St_Platform_Angular_Velocity.T;
      Platform_Angular_Velocity_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Platform_Angular_Velocity (Value => Platform_Angular_Velocity_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Platform_Attitude_Status = Success or else Platform_Attitude_Status = Stale);
      pragma Assert (Platform_Angular_Velocity_Status = Success or else Platform_Angular_Velocity_Status = Stale);

      -- Unpack the data dependencies to native values. The algorithm consumes
      -- only the quaternions; the Time_Tag is not part of the C input PODs and
      -- is re-attached to the output below.
      Attitude_U : constant St_Platform_Attitude.U :=
         St_Platform_Attitude.Unpack (Platform_Attitude_Dep);
      Rate_U : constant St_Platform_Angular_Velocity.U :=
         St_Platform_Angular_Velocity.Unpack (Platform_Angular_Velocity_Dep);

      -- Marshal quaternion-only C input PODs matching the shim types.
      Attitude_C : aliased Platform_Attitude_C :=
        (Q_CN => [
            Attitude_U.Platform_Attitude (0),
            Attitude_U.Platform_Attitude (1),
            Attitude_U.Platform_Attitude (2),
            Attitude_U.Platform_Attitude (3)]);
      Rate_C : aliased Platform_Angular_Velocity_C :=
        (Dq_CN => [
            Rate_U.Platform_Angular_Velocity (0),
            Rate_U.Platform_Angular_Velocity (1),
            Rate_U.Platform_Angular_Velocity (2),
            Rate_U.Platform_Angular_Velocity (3)]);
   begin
      -- Apply any pending parameter update (e.g. new Dcm_Cb) before running:
      Self.Update_Parameters;

      -- Call the C algorithm and publish the resulting body-frame attitude. The
      -- shim output POD carries no time tag, so re-attach the input attitude's
      -- Time_Tag to the published data product.
      declare
         Output : constant St_Attitude_Output_C := Update (
            Self.Alg,
            Platform_Attitude          => Attitude_C'Unchecked_Access,
            Platform_Angular_Velocity  => Rate_C'Unchecked_Access
         );
         Result_U : constant St_Att.U := (
            Time_Tag      => Attitude_U.Time_Tag,
            Mrp_Bdy_Inrtl => Packed_F32x3.C.To_Ada (Output.Sigma_BN.Value),
            Omega_Bn_B    => Packed_F32x3.C.To_Ada (Output.Omega_BN_B.Value)
         );
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Star_Tracker_Body_Attitude (
            Arg.Time,
            St_Att.Pack (Result_U)
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
   -- rebuild the configuration from the updated body-to-case DCM and push it into the C algorithm so
   -- subsequent updates use the new platform alignment. The value was checked by Validate_Parameters
   -- at staging, so Set_Config will not reject it.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Config : aliased Convert_St_Platform_To_Body_Config_C := Make_Config (Self);
   begin
      Set_Config (Self.Alg, Config'Access);
   end Update_Parameters_Action;

   -- Validate a staged Dcm_Cb before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate (which enforces a valid DCM:
   -- orthonormal, det +1), so the validity rules live solely in the algorithm.
   -- Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Dcm_Cb : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
      Config : aliased Convert_St_Platform_To_Body_Config_C :=
        (Dcm_Cb => (Value => Packed_F32x9.C.To_C (Dcm_Cb)));
   begin
      if Validate_Config (Config'Access) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -- Invalid Parameter handler. This procedure is called when a parameter's type is found to be invalid:
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
   begin
      -- Throw event:
      Self.Event_T_Send_If_Connected (Self.Events.Invalid_Parameter_Received (
         Self.Sys_Time_T_Get,
         (Id => Par.Header.Id, Errant_Field_Number => Errant_Field_Number, Errant_Field => Errant_Field)
      ));
   end Invalid_Parameter;

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

end Component.Convert_St_Platform_To_Body.Implementation;
