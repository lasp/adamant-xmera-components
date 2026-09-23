pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Body_Rate_Miscompare_Output.C;
with Packed_F32x3_Record.C;

package Body_Rate_Miscompare_Algorithm_C is

   --* Opaque handle for a BodyRateMiscompareAlgorithm instance.
   type Body_Rate_Miscompare_Algorithm is limited private;
   type Body_Rate_Miscompare_Algorithm_Access is access all Body_Rate_Miscompare_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Body_Rate_Threshold     Rate threshold to trigger a body rate miscompare fault.
   --* @param Fault_Persistence_Limit Consecutive update calls above threshold to trigger the fault.
   --* @param Use_Imu_Rates           Force the IMU rate output even when the rates agree.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Body_Rate_Threshold     : Short_Float;
      Fault_Persistence_Limit : Unsigned_32;
      Use_Imu_Rates           : Interfaces.C.C_bool)
     return Interfaces.C.C_bool
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_validateConfig";

   --* @brief Construct a new BodyRateMiscompareAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Body_Rate_Threshold     Rate threshold to trigger a body rate miscompare fault.
   --* @param Fault_Persistence_Limit Consecutive update calls above threshold to trigger the fault.
   --* @param Use_Imu_Rates           Force the IMU rate output even when the rates agree.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Body_Rate_Threshold     : Short_Float;
      Fault_Persistence_Limit : Unsigned_32;
      Use_Imu_Rates           : Interfaces.C.C_bool)
     return Body_Rate_Miscompare_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_create";

   --* @brief Destroy a BodyRateMiscompareAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Body_Rate_Miscompare_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* Swaps the configured values; the latched fault state is left untouched, so a
   --* caller needing the new Use_Imu_Rates to take effect on it must follow with
   --* Re_Initialize.
   --* @param Self                    The algorithm instance.
   --* @param Body_Rate_Threshold     Rate threshold to trigger a body rate miscompare fault.
   --* @param Fault_Persistence_Limit Consecutive update calls above threshold to trigger the fault.
   --* @param Use_Imu_Rates           Force the IMU rate output even when the rates agree.
   procedure Set_Config
     (Self                    : Body_Rate_Miscompare_Algorithm_Access;
      Body_Rate_Threshold     : Short_Float;
      Fault_Persistence_Limit : Unsigned_32;
      Use_Imu_Rates           : Interfaces.C.C_bool)
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_setConfig";

   --* @brief Full reset: clear the persistence counter and re-arm the latched
   --* fault from the configured Use_Imu_Rates.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Body_Rate_Miscompare_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_reInitialize";

   --* @brief Clear the persistence counter only; a latched fault is preserved.
   --* @param Self The algorithm instance.
   procedure Re_Initialize_Except_Persistent_States
     (Self : Body_Rate_Miscompare_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_reInitializeExceptPersistentStates";

   --* @brief Run the update step.
   --* @param Self      The algorithm instance.
   --* @param Imu_Omega IMU body rate vector (Vector3f_c).
   --* @param St_Omega  Star tracker body rate vector (Vector3f_c).
   --* @return The output struct with the selected body rate and fault flag.
   function Update
     (Self      : Body_Rate_Miscompare_Algorithm_Access;
      Imu_Omega : Packed_F32x3_Record.C.U_C;
      St_Omega  : Packed_F32x3_Record.C.U_C)
     return Body_Rate_Miscompare_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_update";

private

   -- Private representation: opaque null record
   type Body_Rate_Miscompare_Algorithm is null record;

end Body_Rate_Miscompare_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
