--------------------------------------------------------------------------------
-- Mimu_Majority_Vote Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3_X3_Record.C;
with Packed_F32x3.C;
with Mimu_Majority_Vote_Output.C;

package body Component.Mimu_Majority_Vote.Implementation is

   -- Compile-time check that the algorithm uses exactly 3 IMUs.
   pragma Compile_Time_Error (MIMU_COUNT /= 3,
      "This wrapper requires exactly 3 active IMUs");

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the MIMU majority vote algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
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

      -- Grab data dependencies for the 3 active IMU body data inputs:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      Imu_1_T : Averaged_Imu_Data.T;
      Imu_1_Status : constant Data_Dependency_Status.E :=
         Self.Get_Imu_1_Body (Value => Imu_1_T, Stale_Reference => Arg.Time);
      pragma Assert (Imu_1_Status = Success);
      Imu_2_T : Averaged_Imu_Data.T;
      Imu_2_Status : constant Data_Dependency_Status.E :=
         Self.Get_Imu_2_Body (Value => Imu_2_T, Stale_Reference => Arg.Time);
      pragma Assert (Imu_2_Status = Success);
      Imu_3_T : Averaged_Imu_Data.T;
      Imu_3_Status : constant Data_Dependency_Status.E :=
         Self.Get_Imu_3_Body (Value => Imu_3_T, Stale_Reference => Arg.Time);
      pragma Assert (Imu_3_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      declare
         -- Extract angular velocity from each IMU and build C input record:
         Imu_Inputs : constant Packed_F32x3_X3_Record.C.U_C := (Vec => [
            (Value => Packed_F32x3.C.Unpack (Imu_1_T.Ang_Vel_Body)),
            (Value => Packed_F32x3.C.Unpack (Imu_2_T.Ang_Vel_Body)),
            (Value => Packed_F32x3.C.Unpack (Imu_3_T.Ang_Vel_Body))
         ]);

         -- Call the C algorithm:
         Result : constant Mimu_Majority_Vote_Output.C.U_C := Update (
            Self.Alg,
            Imu_Inputs     => Imu_Inputs
         );
         Packed_Result : constant Mimu_Majority_Vote_Output.T :=
            Mimu_Majority_Vote_Output.Pack (Mimu_Majority_Vote_Output.C.To_Ada (Result));
      begin
         -- Publish full result with fault status:
         Self.Data_Product_T_Send (Self.Data_Products.Majority_Vote_Result (
            Arg.Time,
            Packed_Result
         ));

         -- Publish fault-excluded averaged angular velocity:
         Self.Data_Product_T_Send (Self.Data_Products.Voted_Ang_Vel_Body (
            Arg.Time,
            (Value => Packed_Result.Avg_Ang_Vel_Body)
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
   -- Description:
   --    Parameters for the MIMU Majority Vote component
   -- This procedure is called when the parameters of a component have been updated.
   -- Apply the omega threshold parameter to the C algorithm.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      Set_Omega_Threshold (Self.Alg, Self.Omega_Threshold.Value);
   end Update_Parameters_Action;

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
   -- Description:
   --    Data dependencies for the MIMU Majority Vote component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Mimu_Majority_Vote.Implementation;
