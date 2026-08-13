pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings     (Off, "-gnatwx");

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
   --* @return The C-side MAX_MIMU_PKT packet-ring depth.
   function Get_Max_Mimu_Pkt
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getMaxMimuPkt";

   --* @brief Get the MAX_MIMU_SAMPLES_PER_PKT constant for Ada validation.
   --* @return The C-side MAX_MIMU_SAMPLES_PER_PKT samples-per-packet count.
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

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Gyro_Averaging_Window  [s] gyro averaging window, in [0.0, 2.0].
   --* @param Accel_Averaging_Window [s] accel averaging window, in [0.0, 2.0].
   --* @param Dcm_Bc                 CHU-to-body DCM (row-major 3x3, orthonormal, det +1).
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Gyro_Averaging_Window  : Short_Float;
      Accel_Averaging_Window : Short_Float;
      Dcm_Bc                 : Packed_F32x9_Record.C.U_C)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_validateConfig";

   --* @brief Construct a new AverageMimuDataAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Gyro_Averaging_Window  [s] gyro averaging window, in [0.0, 2.0].
   --* @param Accel_Averaging_Window [s] accel averaging window, in [0.0, 2.0].
   --* @param Dcm_Bc                 CHU-to-body DCM (row-major 3x3, orthonormal, det +1).
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Gyro_Averaging_Window  : Short_Float;
      Accel_Averaging_Window : Short_Float;
      Dcm_Bc                 : Packed_F32x9_Record.C.U_C)
     return Average_Mimu_Data_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_create";

   --* @brief Destroy an AverageMimuDataAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Average_Mimu_Data_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The accumulated sample ring is untouched.
   --* @param Self                   The algorithm instance.
   --* @param Gyro_Averaging_Window  [s] gyro averaging window, in [0.0, 2.0].
   --* @param Accel_Averaging_Window [s] accel averaging window, in [0.0, 2.0].
   --* @param Dcm_Bc                 CHU-to-body DCM (row-major 3x3, orthonormal, det +1).
   procedure Set_Config
     (Self                   : Average_Mimu_Data_Algorithm_Access;
      Gyro_Averaging_Window  : Short_Float;
      Accel_Averaging_Window : Short_Float;
      Dcm_Bc                 : Packed_F32x9_Record.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_setConfig";


   --* @brief Run the update step to compute averaged MIMU data.
   --* @param Self  The algorithm instance.
   --* @param Input Pointer to input packets data (4-packet ring; each packet holds 10 samples).
   --* @return Averaged body-frame accel and angular velocity.
   function Update
     (Self  : Average_Mimu_Data_Algorithm_Access;
      Input : access constant Mimu_Input_Packets.C.U_C)
     return Averaged_Imu_Data.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_update";

private

   -- Private representation: opaque null record
   type Average_Mimu_Data_Algorithm is null record;

end Average_Mimu_Data_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
pragma Warnings     (On, "-gnatwx");
