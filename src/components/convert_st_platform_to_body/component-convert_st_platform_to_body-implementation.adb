--------------------------------------------------------------------------------
-- Convert_St_Platform_To_Body Component Implementation Body
--------------------------------------------------------------------------------

with St_Platform_Attitude;
with St_Platform_Angular_Velocity;
with St_Platform_Measurement;
with St_Platform_Measurement.C;
with St_Att.C;
with Packed_F32x9.C;
with Packed_F32x9_Record.C;

package body Component.Convert_St_Platform_To_Body.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the convert star tracker platform to body algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- Build the initial DCM configuration from the component's parameter default.
      Dcm_Cb_C : constant Packed_F32x9_Record.C.U_C := (Value => Packed_F32x9.C.To_C (Self.Dcm_Cb));
   begin
      pragma Assert (Validate_Config (Dcm_Cb_C));
      Self.Alg := Create (Dcm_Cb_C);
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

      Platform_Attitude_U : constant St_Platform_Attitude.U :=
         St_Platform_Attitude.Unpack (Platform_Attitude_Dep);
      Platform_Angular_Velocity_U : constant St_Platform_Angular_Velocity.U :=
         St_Platform_Angular_Velocity.Unpack (Platform_Angular_Velocity_Dep);

      -- Join the two star-tracker solutions into the single measurement the algorithm takes.
      -- The attitude solution supplies the time tag that is passed through to the output.
      Measurement_C : aliased St_Platform_Measurement.C.U_C := St_Platform_Measurement.C.To_C ((
         Time_Tag                  => Platform_Attitude_U.Time_Tag,
         Platform_Attitude         => Platform_Attitude_U.Platform_Attitude,
         Platform_Angular_Velocity => Platform_Angular_Velocity_U.Platform_Angular_Velocity
      ));
   begin
      -- Apply any pending parameter update (e.g. new Dcm_Cb):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the resulting body-frame attitude:
      Self.Data_Product_T_Send (Self.Data_Products.Star_Tracker_Body_Attitude (
         Arg.Time,
         St_Att.Pack (St_Att.C.To_Ada (Update (Self.Alg, Measurement => Measurement_C'Access)))
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
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the body-to-case DCM into the C algorithm so subsequent updates use the new platform
   -- alignment.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Dcm_Cb_C : constant Packed_F32x9_Record.C.U_C := (
         Value => Packed_F32x9.C.To_C (Self.Dcm_Cb)
      );
   begin
      -- Rebuild the algorithm configuration from the updated DCM parameter. The value was
      -- checked by Validate_Parameters at staging, so Set_Config will not reject it.
      Set_Config (Self.Alg, Dcm_Cb_C);
   end Update_Parameters_Action;

   -- Validate a staged Dcm_Cb before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate (a valid DCM is orthonormal with det +1), so
   -- the config rules live solely in the algorithm. Rejecting an invalid update here at
   -- staging keeps it from reaching the throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Dcm_Cb : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
      Dcm_Cb_C : constant Packed_F32x9_Record.C.U_C := (Value => Packed_F32x9.C.To_C (Dcm_Cb));
   begin
      if Validate_Config (Dcm_Cb_C) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
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

end Component.Convert_St_Platform_To_Body.Implementation;
