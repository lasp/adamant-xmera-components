pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about the C "char"-style mapping.
pragma Warnings     (Off, "-gnatwx");

with Basic_Types;
with Interfaces;                use Interfaces;
with Mimu_Majority_Vote_Output.C;
with Mimu_Vote_Result.C;
with Packed_Bool_X3;
with Packed_F32x3.C;
with Packed_F32x3_X3.C;

package Mimu_Majority_Vote_Algorithm_C is

   --* @brief Get the MIMU count constant for validation.
   --* @return The IMU count (MIMU_COUNT_C).
   function Get_Mimu_Count
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_getMimuCount";

   --* @brief Get the size in bytes of one MimuVoteResult_c for ABI validation.
   --* @return sizeof (MimuVoteResult_c).
   function Get_Vote_Result_Size
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_getVoteResultSize";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side MIMU_COUNT_C, checked at elaboration.
   -- Vector3fArray3_c: Vector3f_c vec[MIMU_COUNT_C];
   pragma Assert (Unsigned_32 (Packed_F32x3_X3.Length) = Get_Mimu_Count);
   pragma Assert (Unsigned_32 (Packed_F32x3_X3.C.U_C'Object_Size / Packed_F32x3.C.U_C'Object_Size) = Get_Mimu_Count);
   -- MimuVoteResult_c: float imuDifferenceMag[MIMU_COUNT_C]; bool imuValid[MIMU_COUNT_C];
   pragma Assert (Unsigned_32 (Packed_F32x3.Length) = Get_Mimu_Count);
   pragma Assert (Unsigned_32 (Packed_Bool_X3.Length) = Get_Mimu_Count);

   -- MimuVoteResult_c is the first POD on this boundary with interior padding: a
   -- one-byte bool sits between two 4-byte-aligned members, so the C compiler pads
   -- after it. Field-by-field agreement is therefore not enough - check the whole
   -- struct size, since a padding disagreement would silently shift every field of
   -- the accel vote that follows the gyro vote in Mimu_Majority_Vote_Output.
   pragma Assert (Unsigned_32 (Mimu_Vote_Result.C.U_C'Object_Size / Basic_Types.Byte'Object_Size) = Get_Vote_Result_Size);
   pragma Assert (Mimu_Majority_Vote_Output.C.U_C'Object_Size = 2 * Mimu_Vote_Result.C.U_C'Object_Size);

   --* Opaque handle for a MimuMajorityVoteAlgorithm instance.
   type Mimu_Majority_Vote_Algorithm is limited private;
   type Mimu_Majority_Vote_Algorithm_Access is access all Mimu_Majority_Vote_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Omega_Threshold              [rad/s] gyro threshold; must be finite and > 0.
   --* @param Gyro_Fault_Persistence_Limit consecutive gyro faults to trigger; must be > 0.
   --* @param Accel_Threshold              [m/s^2] accel threshold; must be finite and > 0.
   --* @param Accel_Fault_Persistence_Limit consecutive accel faults to trigger; must be > 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Omega_Threshold               : Short_Float;
      Gyro_Fault_Persistence_Limit  : Unsigned_32;
      Accel_Threshold               : Short_Float;
      Accel_Fault_Persistence_Limit : Unsigned_32)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_validateConfig";

   --* @brief Construct a new MimuMajorityVoteAlgorithm from the supplied configuration.
   --* @param Omega_Threshold              [rad/s] gyro threshold; must be finite and > 0.
   --* @param Gyro_Fault_Persistence_Limit consecutive gyro faults to trigger; must be > 0.
   --* @param Accel_Threshold              [m/s^2] accel threshold; must be finite and > 0.
   --* @param Accel_Fault_Persistence_Limit consecutive accel faults to trigger; must be > 0.
   --* Validate the values with Validate_Config first; invalid input throws.
   function Create
     (Omega_Threshold               : Short_Float;
      Gyro_Fault_Persistence_Limit  : Unsigned_32;
      Accel_Threshold               : Short_Float;
      Accel_Fault_Persistence_Limit : Unsigned_32)
     return Mimu_Majority_Vote_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_create";

   --* @brief Destroy a MimuMajorityVoteAlgorithm.
   procedure Destroy
     (Self : Mimu_Majority_Vote_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_destroy";

   --* @brief Apply a new configuration (parameters only; call Re_Initialize to reset
   --* the persistence counters). Validate with Validate_Config first; invalid input throws.
   --* @param Self                         The algorithm instance.
   --* @param Omega_Threshold              [rad/s] gyro threshold; must be finite and > 0.
   --* @param Gyro_Fault_Persistence_Limit consecutive gyro faults to trigger; must be > 0.
   --* @param Accel_Threshold              [m/s^2] accel threshold; must be finite and > 0.
   --* @param Accel_Fault_Persistence_Limit consecutive accel faults to trigger; must be > 0.
   procedure Set_Config
     (Self                          : Mimu_Majority_Vote_Algorithm_Access;
      Omega_Threshold               : Short_Float;
      Gyro_Fault_Persistence_Limit  : Unsigned_32;
      Accel_Threshold               : Short_Float;
      Accel_Fault_Persistence_Limit : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_setConfig";

   --* @brief Reset gyro and accel fault persistence counters to zero.
   procedure Re_Initialize
     (Self : Mimu_Majority_Vote_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_reInitialize";

   --* @brief Run the majority vote update step.
   --* @param Self       The algorithm instance.
   --* @param Imu_Omegas Array of IMU angular velocity 3-vectors (by reference).
   --* @param Imu_Accels Array of IMU apparent acceleration 3-vectors (by reference).
   --* @return The computed majority vote output (gyro + accel).
   function Update
     (Self       : Mimu_Majority_Vote_Algorithm_Access;
      Imu_Omegas : access constant Packed_F32x3_X3.C.U_C;
      Imu_Accels : access constant Packed_F32x3_X3.C.U_C)
     return Mimu_Majority_Vote_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_update";

private

   -- Private representation: opaque null record
   type Mimu_Majority_Vote_Algorithm is null record;

end Mimu_Majority_Vote_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
pragma Warnings     (On, "-gnatwx");
