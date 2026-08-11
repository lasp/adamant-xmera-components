--------------------------------------------------------------------------------
-- Average_Mimu_Data Component Implementation Body
--------------------------------------------------------------------------------

with Mimu_Input_Packet.C;
with Mimu_Sample_X10.C;
with Averaged_Imu_Data.C;
with Packed_F32x9.C;
with Packed_F32x9_Record.C;

package body Component.Average_Mimu_Data.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the AverageMimuData algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- Build the initial configuration from the component's parameter defaults.
      Gyro_Window  : constant Long_Float := Long_Float (Self.Gyro_Time_Delta.Value);
      Accel_Window : constant Long_Float := Long_Float (Self.Accel_Time_Delta.Value);
      Dcm_Bc_C     : constant Packed_F32x9_Record.C.U_C :=
         (Value => Packed_F32x9.C.To_C (Self.Dcm_Pltf_To_Bdy));
   begin
      pragma Assert (Validate_Config (
         Gyro_Averaging_Window  => Gyro_Window,
         Accel_Averaging_Window => Accel_Window,
         Dcm_Bc                 => Dcm_Bc_C));
      Self.Alg := Create (
         Gyro_Averaging_Window  => Gyro_Window,
         Accel_Averaging_Window => Accel_Window,
         Dcm_Bc                 => Dcm_Bc_C);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Receive an engineering-unit MIMU data packet and stage it directly into
   -- the algorithm input for the next tick.
   overriding procedure Mimu_Eng_Packet_T_Recv_Sync (Self : in out Instance; Arg : in Mimu_Eng_Packet.T) is
   begin
      Self.Update_Parameters;

      if Self.Packet_Count >= Max_Buffered_Packets then
         -- Buffer full, drop the incoming packet.
         Self.Event_T_Send_If_Connected (Self.Events.Packet_Buffer_Overflow (Self.Sys_Time_T_Get));
      else
         -- Stage the packet into the next free packet slot of the algorithm
         -- input. The algorithm derives per-sample times from the packet's
         -- first-sample time plus the device sample period, so the packet
         -- carries only that one timestamp:
         declare
            Pkt : Mimu_Input_Packet.C.U_C renames Self.Input.Packets (Self.Packet_Count);
         begin
            Pkt.Is_Valid := 1;
            Pkt.Meas_Time := Arg.Meas_Time;
            Pkt.Samples := Mimu_Sample_X10.C.To_C (Mimu_Sample_X10.Unpack (Arg.Samples));
         end;
         Self.Packet_Count := Self.Packet_Count + 1;
      end if;
   end Mimu_Eng_Packet_T_Recv_Sync;

   -- Tick that runs the averaging algorithm over the staged packets and
   -- publishes the result. Publishes Imu_Body_Data on every tick so
   -- downstream consumers see Success each cycle; with nothing staged every
   -- packet is invalid and the algorithm returns its current rolling
   -- average.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
   begin
      declare
         Output : constant Averaged_Imu_Data.C.U_C :=
            Update (Self.Alg, Self.Input'Access);
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
      -- Rebuild the algorithm configuration from the updated parameters. The values were
      -- checked by Validate_Parameters at staging, so Set_Config will not reject them.
      Set_Config (
         Self.Alg,
         Gyro_Averaging_Window  => Long_Float (Self.Gyro_Time_Delta.Value),
         Accel_Averaging_Window => Long_Float (Self.Accel_Time_Delta.Value),
         Dcm_Bc                 => (Value => Packed_F32x9.C.To_C (Self.Dcm_Pltf_To_Bdy)));
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Gyro_Time_Delta : in Packed_F32.U;
      Accel_Time_Delta : in Packed_F32.U;
      Dcm_Pltf_To_Bdy : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
   begin
      if Validate_Config (
            Gyro_Averaging_Window  => Long_Float (Gyro_Time_Delta.Value),
            Accel_Averaging_Window => Long_Float (Accel_Time_Delta.Value),
            Dcm_Bc                 => (Value => Packed_F32x9.C.To_C (Dcm_Pltf_To_Bdy)))
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

end Component.Average_Mimu_Data.Implementation;
