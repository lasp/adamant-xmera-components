--------------------------------------------------------------------------------
-- Convert_St_Platform_To_Body Component Implementation Body
--------------------------------------------------------------------------------

with St_Platform_Attitude;
with St_Platform_Angular_Velocity;
with St_Platform_Measurement;
with St_Platform_Measurement.C;
with St_Att.C;
with Packed_F32x3.C;

package body Component.Convert_St_Platform_To_Body.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the convert star tracker platform to body algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      Self.Alg := Create (Sigma_Cb => (Value => Packed_F32x3.C.To_C (Self.Sigma_Cb)));
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
      -- assert. The attitude solution's timestamp is the time of the measurement,
      -- which the output is stamped with.
      Platform_Attitude_Dep : St_Platform_Attitude.T;
      Platform_Attitude_Time : Sys_Time.T;
      Platform_Attitude_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Platform_Attitude (Value => Platform_Attitude_Dep, Timestamp => Platform_Attitude_Time, Stale_Reference => Arg.Time);
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
      -- Apply any pending parameter update (e.g. new Sigma_Cb):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the resulting body-frame attitude, stamped
      -- with the time of the solution it converts:
      Self.Data_Product_T_Send (Self.Data_Products.Star_Tracker_Body_Attitude (
         Platform_Attitude_Time,
         St_Att.C.Pack (Update (Self.Alg, Measurement => Measurement_C'Access))
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
   -- push the case mounting attitude into the C algorithm so subsequent updates use the new
   -- platform alignment.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Rebuild the algorithm configuration from the updated mounting attitude. The value was
      -- checked by Validate_Parameters at staging, so Set_Config will not reject it.
      Set_Config (Self.Alg, Sigma_Cb => (Value => Packed_F32x3.C.To_C (Self.Sigma_Cb)));
   end Update_Parameters_Action;

   -- Validate a staged Sigma_Cb before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate (a valid mounting attitude is finite), so
   -- the config rules live solely in the algorithm. Rejecting an invalid update here at
   -- staging keeps it from reaching the throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sigma_Cb : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
   begin
      if Validate_Config (Sigma_Cb => (Value => Packed_F32x3.C.To_C (Sigma_Cb))) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float array staging accepts a
      -- non-finite value, and marshalling it in Packed_F32x3.C.To_C raises. Rejecting the set
      -- here keeps that from unwinding into the Parameters component.
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
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Convert_St_Platform_To_Body.Implementation;
