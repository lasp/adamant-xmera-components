--------------------------------------------------------------------------------
-- Average_Mimu_Data Component Implementation Body
--------------------------------------------------------------------------------

with Mimu_Input_Packet.C;
with Averaged_Imu_Data.C;
with Packed_F32x9.C;
with Interfaces;

package body Component.Average_Mimu_Data.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the AverageMimuData algorithm.
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
   -- Receive raw MIMU data packet and stage it directly into the algorithm
   -- input for the next tick.
   overriding procedure Mimu_Raw_Packet_T_Recv_Sync (Self : in out Instance; Arg : in Mimu_Raw_Packet.T) is
   begin
      Self.Update_Parameters;

      if Self.Packet_Count >= Max_Buffered_Packets then
         -- Buffer full, drop the incoming packet.
         Self.Event_T_Send_If_Connected (Self.Events.Packet_Buffer_Overflow (Self.Sys_Time_T_Get));
      else
         -- Convert raw counts to float samples directly into the next free
         -- packet slot of the algorithm input:
         declare
            Base_Time_Ns : constant Interfaces.Unsigned_64 :=
               Interfaces.Unsigned_64 (Arg.Timestamp.Seconds) * 1_000_000_000 +
               Interfaces.Unsigned_64 (Arg.Timestamp.Subseconds) * 1_000_000_000 / 65_536;

            Pkt : Mimu_Input_Packet.C.U_C renames Self.Input.Packets (Self.Packet_Count);
         begin
            Pkt.Is_Valid := 1;
            -- The algorithm derives per-sample times from the packet's
            -- first-sample time plus the device sample period, so we only
            -- carry that one timestamp:
            Pkt.Meas_Time := Base_Time_Ns;
            for Idx in Arg.Samples'Range loop
               Pkt.Samples (Idx).Gyro_P := [
                  Short_Float (Arg.Samples (Idx).Merged_Gyro_Rates.X_Measurement) * Gyro_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Gyro_Rates.Y_Measurement) * Gyro_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Gyro_Rates.Z_Measurement) * Gyro_Scale
               ];
               Pkt.Samples (Idx).Accel_P := [
                  Short_Float (Arg.Samples (Idx).Merged_Accelerations.X_Measurement) * Accel_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Accelerations.Y_Measurement) * Accel_Scale,
                  Short_Float (Arg.Samples (Idx).Merged_Accelerations.Z_Measurement) * Accel_Scale
               ];
            end loop;
         end;
         Self.Packet_Count := Self.Packet_Count + 1;
      end if;
   end Mimu_Raw_Packet_T_Recv_Sync;

   -- Tick that runs the averaging algorithm over the staged packets and
   -- publishes the result. Publishes Imu_Body_Data on every tick so
   -- downstream consumers see Success each cycle; with nothing staged every
   -- packet is invalid and the algorithm returns its current rolling
   -- average.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
   begin
      declare
         Output : constant Averaged_Imu_Data.C.U_C :=
            Update (Self.Alg, Self.Input'Unchecked_Access);
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Imu_Body_Data (
            Arg.Time,
            Averaged_Imu_Data.C.Pack (Output)
         ));
      end;

      -- Invalidate the staged packets for the next cycle. Sample data behind
      -- an invalid flag is skipped by the algorithm, so it is not re-zeroed.
      for Pdx in 0 .. Self.Packet_Count - 1 loop
         Self.Input.Packets (Pdx).Is_Valid := 0;
      end loop;
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
      -- Set the gyro and accel averaging windows (validated to [0.0, 2.0] s):
      Set_Gyro_Averaging_Window (Self.Alg, Long_Float (Self.Gyro_Time_Delta.Value));
      Set_Accel_Averaging_Window (Self.Alg, Long_Float (Self.Accel_Time_Delta.Value));
      -- Set the platform-to-body DCM:
      Set_Dcm_Pltf_To_Bdy (Self.Alg, (Value => Packed_F32x9.C.To_C (Self.Dcm_Pltf_To_Bdy)));
   end Update_Parameters_Action;

end Component.Average_Mimu_Data.Implementation;
