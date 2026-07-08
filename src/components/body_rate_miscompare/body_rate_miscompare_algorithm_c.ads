pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Packed_F32x3_Record.C;

package Body_Rate_Miscompare_Algorithm_C is

   --* Opaque handle for a BodyRateMiscompareAlgorithm instance.
   type Body_Rate_Miscompare_Algorithm is limited private;
   type Body_Rate_Miscompare_Algorithm_Access is access all Body_Rate_Miscompare_Algorithm;

   --* POD config type matching BodyRateMiscompareConfig_c in C.
   --* Layout: float bodyRateThreshold; uint32_t faultPersistenceLimit; bool useImuRates;
   type Body_Rate_Miscompare_Config_C is record
      Body_Rate_Threshold     : aliased Short_Float;       --* [rad/s] disagreement threshold.
      Fault_Persistence_Limit : aliased Unsigned_32;       --* consecutive disagreements to trigger.
      Use_Imu_Rates           : aliased C.unsigned_char;   --* force IMU rates when non-zero (C bool, 0/1).
   end record
      with Convention => C_Pass_By_Copy;

   --* POD output type matching BodyRateMiscompareOutput_c in C.
   --* Layout: float omega_BN_B[3]; bool bodyRateFaultDetected;
   type Body_Rate_Miscompare_Output_C is record
      Omega_Bn_B : aliased Packed_F32x3_Record.C.U_C;
      Body_Rate_Fault_Detected : aliased C.unsigned_char;
   end record
      with Convention => C_Pass_By_Copy;

   --* @brief Construct a new BodyRateMiscompareAlgorithm from a configuration.
   --* @param Config The configuration to apply (validated; throws on invalid input).
   --* Validate config values before calling so an invalid config never reaches this.
   function Create
     (Config : access constant Body_Rate_Miscompare_Config_C)
     return Body_Rate_Miscompare_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_create";

   --* @brief Destroy a BodyRateMiscompareAlgorithm.
   procedure Destroy
     (Self : Body_Rate_Miscompare_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param Config The configuration to apply.
   --* Swaps the configured values; the latched fault state is left untouched.
   procedure Set_Config
     (Self   : Body_Rate_Miscompare_Algorithm_Access;
      Config : access constant Body_Rate_Miscompare_Config_C)
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
   --* @return BodyRateMiscompareOutput_c  The computed output.
   function Update
     (Self      : Body_Rate_Miscompare_Algorithm_Access;
      Imu_Omega : Packed_F32x3_Record.C.U_C;
      St_Omega  : Packed_F32x3_Record.C.U_C)
     return Body_Rate_Miscompare_Output_C
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_update";

private

   -- Private representation: opaque null record
   type Body_Rate_Miscompare_Algorithm is null record;

end Body_Rate_Miscompare_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
