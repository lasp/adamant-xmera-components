--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Body_Rate_Miscompare.Implementation is

   -- Push the component's current configuration -- the applied parameters plus the
   -- Use_Imu_Rates override held as instance state -- into the C++ algorithm. Every
   -- reconfiguration path goes through here.
   procedure Apply_Config (Self : in out Instance) is
   begin
      Set_Config (
         Self.Alg,
         Body_Rate_Threshold     => Self.Body_Rate_Threshold.Value,
         Fault_Persistence_Limit => Self.Fault_Persistence_Limit.Value,
         Use_Imu_Rates           => Self.Use_Imu_Rates);
   end Apply_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the body rate miscompare algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      pragma Assert (Validate_Config (
         Body_Rate_Threshold     => Self.Body_Rate_Threshold.Value,
         Fault_Persistence_Limit => Self.Fault_Persistence_Limit.Value,
         Use_Imu_Rates           => Self.Use_Imu_Rates));
      Self.Alg := Create (
         Body_Rate_Threshold     => Self.Body_Rate_Threshold.Value,
         Fault_Persistence_Limit => Self.Fault_Persistence_Limit.Value,
         Use_Imu_Rates           => Self.Use_Imu_Rates);
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
      Imu_Body : Mimu_Majority_Vote_Output.T;
      Imu_Body_Status : constant Data_Dependency_Status.E :=
         Self.Get_Imu_Body (Value => Imu_Body, Stale_Reference => Arg.Time);
      pragma Assert (Imu_Body_Status = Success);
      St_Body : St_Att.T;
      St_Body_Status : constant Data_Dependency_Status.E :=
         Self.Get_Star_Tracker_Attitude (Value => St_Body, Stale_Reference => Arg.Time);
      pragma Assert (St_Body_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call algorithm with angular velocity vectors:
      declare
         Imu_Omega : constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Imu_Body.Avg_Ang_Vel_Body));
         St_Omega : constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (St_Body.Omega_Bn_B));

         Output : constant Update_Result := Update (
            Self.Alg,
            Imu_Omega => Imu_Omega,
            St_Omega  => St_Omega
         );
      begin
         -- Send out body rate data product (omega_BN_B only):
         Self.Data_Product_T_Send (Self.Data_Products.Body_Rate (Arg.Time, Output.Omega_Bn_B));
         -- Send out body rate fault data product:
         Self.Data_Product_T_Send (Self.Data_Products.Rate_Fault_Status (Arg.Time, (Fault_Detected => Output.Fault_Detected)));

         -- Report transitions of the fault flag. The flag is set whenever IMU
         -- rates are selected, whether by an organic miscompare latch or by the
         -- commanded Use_Imu_Rates override.
         if Output.Fault_Detected and then not Self.Prev_Fault_Latched then
            -- Record when the fault latched so the ground can recover the
            -- transition time from a single sample.
            Self.Data_Product_T_Send (Self.Data_Products.Fault_Latch_Time (Arg.Time, Arg.Time));
            Self.Event_T_Send_If_Connected (Self.Events.Body_Rate_Fault_Latched (Arg.Time));
         elsif not Output.Fault_Detected and then Self.Prev_Fault_Latched then
            Self.Event_T_Send_If_Connected (Self.Events.Body_Rate_Fault_Cleared (Arg.Time));
         end if;
         Self.Prev_Fault_Latched := Output.Fault_Detected;
      end;
   end Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -- Reset the algorithm's fault persistence state. Called on GNC state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clear the algorithm's fault persistence counter so rate disagreement must
      -- re-accumulate from zero after a state change. A latched fault is preserved.
      Re_Initialize_Except_Persistent_States (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

   -- This is the command receive connector.
   overriding procedure Command_T_Recv_Sync (Self : in out Instance; Arg : in Command.T) is
      -- Execute the command:
      Stat : constant Command_Response_Status.E := Self.Execute_Command (Arg);
   begin
      -- Send the return status:
      Self.Command_Response_T_Send_If_Connected ((Source_Id => Arg.Header.Source_Id, Registration_Id => Self.Command_Reg_Id, Command_Id => Arg.Header.Id, Status => Stat));
   end Command_T_Recv_Sync;

   -----------------------------------------------
   -- Command handler primitives:
   -----------------------------------------------
   -- Force the algorithm to always output IMU rates (Value => True) or resume normal
   -- miscompare logic (Value => False). Drives the algorithm's setUseImuRates, which
   -- also clears a latched fault when set False.
   overriding function Use_Imu_Rates (Self : in out Instance; Arg : in Packed_Boolean.T) return Command_Execution_Status.E is
      use Command_Execution_Status;
   begin
      -- Record the override as the Ada-side source of truth, then push it into the C
      -- algorithm via a config swap. Threshold and persistence come from the already-
      -- applied parameters, so the config is always valid here.
      Self.Use_Imu_Rates := Arg.Value;
      Apply_Config (Self);
      -- Re-seed the latched fault state from the new Use_Imu_Rates: forces IMU rates
      -- when True, and clears a latched fault when set False.
      Re_Initialize (Self.Alg);
      -- Report the new setting:
      Self.Event_T_Send_If_Connected (Self.Events.Use_Imu_Rates_Set (Self.Sys_Time_T_Get, Arg));
      return Success;
   end Use_Imu_Rates;

   -- Invalid command handler. This procedure is called when a command's arguments are found to be invalid:
   overriding procedure Invalid_Command (Self : in out Instance; Cmd : in Command.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
   begin
      -- A malformed command can arrive from the ground, so report it rather than assert:
      Self.Event_T_Send_If_Connected (Self.Events.Invalid_Command_Received (
         Self.Sys_Time_T_Get,
         (Id => Cmd.Header.Id, Errant_Field_Number => Errant_Field_Number, Errant_Field => Errant_Field)
      ));
   end Invalid_Command;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Rebuild the algorithm configuration from the updated parameters. The values were
      -- checked by Validate_Parameters at staging, so Set_Config will not reject them.
      Apply_Config (Self);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary. Use_Imu_Rates does not affect validity.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Body_Rate_Threshold : in Packed_F32.U;
      Fault_Persistence_Limit : in Packed_U32.U
   ) return Parameter_Validation_Status.E is
   begin
      if Validate_Config (
            Body_Rate_Threshold     => Body_Rate_Threshold.Value,
            Fault_Persistence_Limit => Fault_Persistence_Limit.Value,
            Use_Imu_Rates           => Self.Use_Imu_Rates)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Body Rate Miscompare component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Body_Rate_Miscompare.Implementation;
