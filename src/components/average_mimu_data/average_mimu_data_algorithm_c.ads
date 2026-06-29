pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Packed_F32x3.C;
with Packed_F32x9_Record.C;
with Averaged_Imu_Data.C;

package Average_Mimu_Data_Algorithm_C is

   --* Opaque handle for an AverageMimuDataAlgorithm instance.
   type Average_Mimu_Data_Algorithm is limited private;
   type Average_Mimu_Data_Algorithm_Access is access all Average_Mimu_Data_Algorithm;

   -- Must match #defines in averageMimuDataAlgorithm_c.h
   Max_Mimu_Pkt : constant := 4;
   Max_Mimu_Samples_Per_Pkt : constant := 10;

   --* POD equivalent of one MIMU sample (Sample_c in C).
   --* Layout: Vector3f_c gyro_P; Vector3f_c accel_P;
   --* The sample carries no timestamp; per-sample times are derived inside the
   --* algorithm from the enclosing packet's Meas_Time and the device sample period.
   type Sample_C is record
      Gyro_P  : aliased Packed_F32x3.C.U_C;
      Accel_P : aliased Packed_F32x3.C.U_C;
   end record
      with Convention => C_Pass_By_Copy;

   --* Per-packet sample array (10 samples).
   type Sample_Array_C is array (0 .. Max_Mimu_Samples_Per_Pkt - 1) of aliased Sample_C
      with Convention => C;

   --* POD equivalent of one MIMU packet (InputPacket_c in C).
   --* Layout: bool isValid; uint64 measTime; Sample_c samples[MAX_MIMU_SAMPLES_PER_PKT_C];
   --* `Is_Valid` gates the whole packet; `Meas_Time` is the first sample's time.
   --* C99 bool is one byte (matches C.unsigned_char); GNAT inserts the pad
   --* before the 8-aligned Meas_Time to match the C ABI.
   type Input_Packet_C is record
      Is_Valid  : aliased C.unsigned_char;
      Meas_Time : aliased Unsigned_64;
      Samples   : aliased Sample_Array_C;
   end record
      with Convention => C_Pass_By_Copy;

   --* Outer array of packets (4 packets).
   type Packets_Array_C is array (0 .. Max_Mimu_Pkt - 1) of aliased Input_Packet_C
      with Convention => C;

   --* POD input matching C InputPktsData_c.
   --* Layout: InputPacket_c packets[MAX_MIMU_PKT_C];
   type Input_Pkts_Data_C is record
      Packets : Packets_Array_C;
   end record
      with Convention => C_Pass_By_Copy;
   type Input_Pkts_Data_C_Access is access all Input_Pkts_Data_C;

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

   -- Runtime validation: ensure Ada constants match C definitions
   pragma Assert (Unsigned_32 (Max_Mimu_Pkt) = Get_Max_Mimu_Pkt);
   pragma Assert (Unsigned_32 (Max_Mimu_Samples_Per_Pkt) = Get_Max_Mimu_Samples_Per_Pkt);

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
      Input : Input_Pkts_Data_C_Access)
     return Averaged_Imu_Data.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_update";

   --* @brief Set the gyro averaging window duration.
   --* @param Self   The algorithm instance.
   --* @param Window Gyro averaging window in seconds (valid range [0.0, 2.0]).
   procedure Set_Gyro_Averaging_Window
     (Self   : Average_Mimu_Data_Algorithm_Access;
      Window : Interfaces.C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_setGyroAveragingWindow";

   --* @brief Get the current gyro averaging window duration.
   --* @param Self The algorithm instance.
   --* @return The current gyro averaging window in seconds.
   function Get_Gyro_Averaging_Window
     (Self : Average_Mimu_Data_Algorithm_Access)
     return Interfaces.C.double
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_getGyroAveragingWindow";

   --* @brief Set the accel averaging window duration.
   --* @param Self   The algorithm instance.
   --* @param Window Accel averaging window in seconds (valid range [0.0, 2.0]).
   procedure Set_Accel_Averaging_Window
     (Self   : Average_Mimu_Data_Algorithm_Access;
      Window : Interfaces.C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "AverageMimuDataAlgorithm_setAccelAveragingWindow";

   --* @brief Get the current accel averaging window duration.
   --* @param Self The algorithm instance.
   --* @return The current accel averaging window in seconds.
   function Get_Accel_Averaging_Window
     (Self : Average_Mimu_Data_Algorithm_Access)
     return Interfaces.C.double
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
