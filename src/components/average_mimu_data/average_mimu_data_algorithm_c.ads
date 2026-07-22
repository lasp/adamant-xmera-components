pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Mimu_Sample.C;
with Mimu_Sample_X10.C;
with Mimu_Input_Packet.C;
with Mimu_Input_Packet_X4.C;
with Mimu_Input_Packets.C;
with Packed_F32x9_Record.C;
with Averaged_Imu_Data.C;

package Average_Mimu_Data_Algorithm_C is

   --* Opaque handle for an AverageMimuDataAlgorithm instance.
   type Average_Mimu_Data_Algorithm is limited private;
   type Average_Mimu_Data_Algorithm_Access is access all Average_Mimu_Data_Algorithm;

   --* @brief Get the MAX_MIMU_PKT constant for Ada validation.
   function Get_Max_Mimu_Pkt
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getMaxMimuPkt";

   --* @brief Get the MAX_MIMU_SAMPLES_PER_PKT constant for Ada validation.
   function Get_Max_Mimu_Samples_Per_Pkt
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getMaxMimuSamplesPerPkt";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side constants, checked at elaboration.
   -- InputPktsData_c: InputPacket_c packets[MAX_MIMU_PKT_C];
   pragma Assert (Unsigned_32 (Mimu_Input_Packet_X4.Length) = Get_Max_Mimu_Pkt);
   pragma Assert (Mimu_Input_Packet_X4.C.U_C'Object_Size = Mimu_Input_Packets.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mimu_Input_Packets.C.U_C'Object_Size / Mimu_Input_Packet.C.U_C'Object_Size) = Get_Max_Mimu_Pkt);
   -- InputPacket_c: Sample_c samples[MAX_MIMU_SAMPLES_PER_PKT_C];
   pragma Assert (Unsigned_32 (Mimu_Sample_X10.Length) = Get_Max_Mimu_Samples_Per_Pkt);
   pragma Assert (Unsigned_32 (Mimu_Sample_X10.C.U_C'Object_Size / Mimu_Sample.C.U_C'Object_Size) = Get_Max_Mimu_Samples_Per_Pkt);

   --* @brief Construct a new AverageMimuDataAlgorithm.
   function Create
     return Average_Mimu_Data_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_create";

   --* @brief Destroy an AverageMimuDataAlgorithm.
   procedure Destroy
     (Self : Average_Mimu_Data_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_destroy";

   --* @brief Run the update step to compute averaged MIMU data.
   --* @param Self  The algorithm instance.
   --* @param Input Pointer to input packets data (4-packet ring; each packet holds 10 samples).
   --* @return Averaged body-frame accel and angular velocity.
   function Update
     (Self  : Average_Mimu_Data_Algorithm_Access;
      Input : Mimu_Input_Packets.C.U_C_Access)
     return Averaged_Imu_Data.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_update";

   --* @brief Set the gyro averaging window duration.
   --* @param Self   The algorithm instance.
   --* @param Window Gyro averaging window in seconds (valid range [0.0, 2.0]).
   procedure Set_Gyro_Averaging_Window
     (Self   : Average_Mimu_Data_Algorithm_Access;
      Window : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_setGyroAveragingWindow";

   --* @brief Get the current gyro averaging window duration.
   --* @param Self The algorithm instance.
   --* @return The current gyro averaging window in seconds.
   function Get_Gyro_Averaging_Window
     (Self : Average_Mimu_Data_Algorithm_Access)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getGyroAveragingWindow";

   --* @brief Set the accel averaging window duration.
   --* @param Self   The algorithm instance.
   --* @param Window Accel averaging window in seconds (valid range [0.0, 2.0]).
   procedure Set_Accel_Averaging_Window
     (Self   : Average_Mimu_Data_Algorithm_Access;
      Window : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_setAccelAveragingWindow";

   --* @brief Get the current accel averaging window duration.
   --* @param Self The algorithm instance.
   --* @return The current accel averaging window in seconds.
   function Get_Accel_Averaging_Window
     (Self : Average_Mimu_Data_Algorithm_Access)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getAccelAveragingWindow";

   --* @brief Set the DCM from platform frame to body frame.
   --* @param Self   The algorithm instance.
   --* @param Dcm_Bp 3x3 rotation matrix in row-major POD format.
   procedure Set_Dcm_Pltf_To_Bdy
     (Self   : Average_Mimu_Data_Algorithm_Access;
      Dcm_Bp : Packed_F32x9_Record.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_setDcmPltfToBdy";

   --* @brief Get the current DCM from platform frame to body frame.
   --* @param Self The algorithm instance.
   --* @return 3x3 rotation matrix in row-major POD format.
   function Get_Dcm_Pltf_To_Bdy
     (Self : Average_Mimu_Data_Algorithm_Access)
     return Packed_F32x9_Record.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getDcmPltfToBdy";

private

   -- Private representation: opaque null record
   type Average_Mimu_Data_Algorithm is null record;

end Average_Mimu_Data_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
