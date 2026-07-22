--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Interfaces.C;

package body Component.Body_Rate_Miscompare.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the body rate miscompare algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;

      -- Apply the Ada parameter defaults to the algorithm: the framework
      -- invokes Update_Parameters_Action only after a ground parameter
      -- update, and the C++ constructor defaults do not match the Ada
      -- defaults.
      Self.Update_Parameters_Action;
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

         Output : constant Body_Rate_Miscompare_Output_C := Update (
            Self.Alg,
            Imu_Omega => Imu_Omega,
            St_Omega  => St_Omega
         );
      begin
         -- Send out body rate data product (omega_BN_B only):
         Self.Data_Product_T_Send (Self.Data_Products.Body_Rate (
            Arg.Time,
            Packed_F32x3.C.Pack (Output.Omega_Bn_B.Value)
         ));
         -- Send out body rate fault data product:
         Self.Data_Product_T_Send (Self.Data_Products.Rate_Fault_Status (
            Arg.Time,
            (Fault_Detected => Interfaces.C."/=" (Output.Body_Rate_Fault_Detected, 0))
         ));
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
      -- re-accumulate from zero after a state change.
      Reset (Self.Alg);
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
      -- Push the override into the C algorithm:
      Set_Use_Imu_Rates (Self.Alg, Arg.Value);
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
      -- Set algorithm tunables when parameters update:
      Set_Body_Rate_Threshold (Self.Alg, Self.Body_Rate_Threshold.Value);
      Set_Fault_Persistence_Limit (Self.Alg, Self.Fault_Persistence_Limit.Value);
   end Update_Parameters_Action;

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
