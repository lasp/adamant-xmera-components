--------------------------------------------------------------------------------
-- Average_Mimu_Data Component Implementation Body
--------------------------------------------------------------------------------

with Averaged_Imu_Data.C;
with Packed_F32x9.C;

package body Component.Average_Mimu_Data.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the AverageMimuData algorithm.
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
   -- Receive raw MIMU data packet and buffer for later processing.
   overriding procedure Mimu_Raw_Packet_T_Recv_Sync (Self : in out Instance; Arg : in Mimu_Raw_Packet.T) is
   begin
      Self.Update_Parameters;

      if Self.Packet_Count >= Max_Buffered_Packets then
         -- Buffer full, drop the incoming packet.
         Self.Event_T_Send_If_Connected (Self.Events.Packet_Buffer_Overflow (Self.Sys_Time_T_Get));
      else
         -- Convert raw packet to float samples and store in pre-converted buffer:
         declare
            Base_Time_Ns : constant Interfaces.Unsigned_64 :=
               Interfaces.Unsigned_64 (Arg.Timestamp.Seconds) * 1_000_000_000 +
               Interfaces.Unsigned_64 (Arg.Timestamp.Subseconds) * 1_000_000_000 / 65_536;

            Buffer : Converted_Packet_Data renames Self.Buffer (Self.Packet_Count);
         begin
            -- The algorithm derives per-sample times from the packet's
            -- first-sample time plus the device sample period, so we only
            -- carry that one timestamp:
            Buffer.Meas_Time := Base_Time_Ns;
            for Idx in Arg.Samples'Range loop
               Buffer.Gyro_P (Idx) := [
                  Short_Float (Arg.Samples (Idx).Merged_Gyro_Rates.X_Measurement) * Gyro_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Gyro_Rates.Y_Measurement) * Gyro_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Gyro_Rates.Z_Measurement) * Gyro_Scale
               ];
               Buffer.Accel_P (Idx) := [
                  Short_Float (Arg.Samples (Idx).Merged_Accelerations.X_Measurement) * Accel_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Accelerations.Y_Measurement) * Accel_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Accelerations.Z_Measurement) * Accel_Scale
               ];
            end loop;
         end;
         Self.Packet_Count := Self.Packet_Count + 1;
      end if;
   end Mimu_Raw_Packet_T_Recv_Sync;

   -- Tick that triggers the averaging algorithm over buffered samples and publishes
   -- the result. Always publishes Imu_Body_Data with a current timestamp so
   -- downstream consumers see Success on every tick; with nothing buffered every
   -- packet is left invalid and the algorithm returns its current rolling average.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;

      -- Build the InputPktsData_c (4 packets, each holding 10 samples) from the
      -- pre-converted buffer. Packets with Is_Valid = 0 are skipped by the
      -- algorithm; we mark Is_Valid = 1 only for filled packet slots
      -- [0 .. Packet_Count - 1].
      Input : aliased Input_Pkts_Data_C := (
         Packets => [others => (
            Is_Valid  => 0,
            Meas_Time => 0,
            Samples   => [others => (
               Gyro_P  => [others => 0.0],
               Accel_P => [others => 0.0]
            )]
         )]
      );
   begin
      -- Copy pre-converted samples into the algorithm input buffer and flag each
      -- filled packet as valid:
      for Pdx in 0 .. Self.Packet_Count - 1 loop
         Input.Packets (Pdx).Is_Valid := 1;
         Input.Packets (Pdx).Meas_Time := Self.Buffer (Pdx).Meas_Time;
         for Idx in 0 .. Samples_Per_Packet - 1 loop
            Input.Packets (Pdx).Samples (Idx) := (
               Gyro_P  => Self.Buffer (Pdx).Gyro_P (Idx),
               Accel_P => Self.Buffer (Pdx).Accel_P (Idx)
            );
         end loop;
      end loop;

      declare
         Output : constant Averaged_Imu_Data.C.U_C :=
            Update (Self.Alg, Input'Unchecked_Access);
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Imu_Body_Data (
            Self.Sys_Time_T_Get,
            Averaged_Imu_Data.C.Pack (Output)
         ));
      end;

      -- Reset buffer for next cycle:
      Self.Packet_Count := 0;
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
   --    Parameters for the Average Mimu Data component
   -- Apply parameter values to the C++ algorithm when parameters change.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Set the averaging window:
      Set_Averaging_Window (Self.Alg, Self.Time_Delta.Value);
      -- Set the platform-to-body DCM:
      Set_Dcm_Pltf_To_Bdy (Self.Alg, (Value => Packed_F32x9.C.To_C (Self.Dcm_Pltf_To_Bdy)));
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

end Component.Average_Mimu_Data.Implementation;
