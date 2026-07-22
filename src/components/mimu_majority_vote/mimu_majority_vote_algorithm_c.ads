pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces;                use Interfaces;
with Mimu_Majority_Vote_Output.C;
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

   -- ABI validation: the constant-dimensioned Ada array crossing the FFI
   -- boundary must match the C-side MIMU_COUNT_C, checked at elaboration.
   -- Vector3fArray3_c: Vector3f_c vec[MIMU_COUNT_C];
   pragma Assert (Unsigned_32 (Packed_F32x3_X3.Length) = Get_Mimu_Count);
   pragma Assert (Unsigned_32 (Packed_F32x3_X3.C.U_C'Object_Size / Packed_F32x3.C.U_C'Object_Size) = Get_Mimu_Count);

   --* Opaque handle for a MimuMajorityVoteAlgorithm instance.
   type Mimu_Majority_Vote_Algorithm is limited private;
   type Mimu_Majority_Vote_Algorithm_Access is access all Mimu_Majority_Vote_Algorithm;

   --* @brief Construct a new MimuMajorityVoteAlgorithm.
   function Create
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

   --* @brief Reset fault persistence counters to zero.
   procedure Reset
     (Self : Mimu_Majority_Vote_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_reset";

   --* @brief Run the majority vote update step.
   --* @param Self           The algorithm instance.
   --* @param Imu_Inputs     Array of IMU angular velocity 3-vectors.
   --* @return The computed majority vote output.
   function Update
     (Self           : Mimu_Majority_Vote_Algorithm_Access;
      Imu_Inputs     : Packed_F32x3_X3.C.U_C)
     return Mimu_Majority_Vote_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_update";

   --* @brief Set the omega threshold for fault detection.
   --* @param Self  The algorithm instance.
   --* @param Value The new omega threshold value (must be positive).
   procedure Set_Omega_Threshold
     (Self  : Mimu_Majority_Vote_Algorithm_Access;
      Value : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_setOmegaThreshold";

   --* @brief Get the current omega threshold.
   --* @param Self The algorithm instance.
   --* @return The current omega threshold.
   function Get_Omega_Threshold
     (Self : Mimu_Majority_Vote_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_getOmegaThreshold";

   --* @brief Set the fault persistence limit.
   --* @param Self  The algorithm instance.
   --* @param Value The new fault persistence limit.
   procedure Set_Fault_Persistence_Limit
     (Self  : Mimu_Majority_Vote_Algorithm_Access;
      Value : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_setFaultPersistenceLimit";

   --* @brief Get the current fault persistence limit.
   --* @param Self The algorithm instance.
   --* @return The current fault persistence limit.
   function Get_Fault_Persistence_Limit
     (Self : Mimu_Majority_Vote_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "MimuMajorityVoteAlgorithm_getFaultPersistenceLimit";

private

   -- Private representation: opaque null record
   type Mimu_Majority_Vote_Algorithm is null record;

end Mimu_Majority_Vote_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
