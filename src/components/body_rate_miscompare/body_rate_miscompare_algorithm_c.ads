pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Body_Rate_Miscompare_Output.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package Body_Rate_Miscompare_Algorithm_C is

   --* Result of one miscompare update, presenting the selected body rate as a
   --* packed record and the fault flag as a native Boolean. The raw C output
   --* struct stays behind Update_C.
   type Update_Result is record
      Omega_Bn_B : Packed_F32x3.T;
      Fault_Detected : Boolean;
   end record;

   --* Opaque handle for a BodyRateMiscompareAlgorithm instance.
   type Body_Rate_Miscompare_Algorithm is limited private;
   type Body_Rate_Miscompare_Algorithm_Access is access all Body_Rate_Miscompare_Algorithm;

   --* @brief Construct a new BodyRateMiscompareAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Body_Rate_Threshold     Rate threshold to trigger a body rate miscompare fault.
   --* @param Fault_Persistence_Limit Consecutive update calls above threshold to trigger the fault.
   --* @param Use_Imu_Rates           Force the IMU rate output even when the rates agree.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Body_Rate_Threshold     : Short_Float;
      Fault_Persistence_Limit : Unsigned_32;
      Use_Imu_Rates           : Boolean)
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
      Use_Imu_Rates           : Boolean)
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
   --* @return Update_Result  The selected body rate and fault flag.
   function Update
     (Self      : Body_Rate_Miscompare_Algorithm_Access;
      Imu_Omega : Packed_F32x3_Record.C.U_C;
      St_Omega  : Packed_F32x3_Record.C.U_C)
     return Update_Result;

private

   -- Private representation: opaque null record
   type Body_Rate_Miscompare_Algorithm is null record;

   -- Raw C entry point. The public Update wraps this so callers receive
   -- native Ada types while the C ABI keeps its output struct.
   --* @param Self      The algorithm instance.
   --* @param Imu_Omega IMU body rate vector (Vector3f_c).
   --* @param St_Omega  Star tracker body rate vector (Vector3f_c).
   --* @return The raw C output struct.
   function Update_C
     (Self      : Body_Rate_Miscompare_Algorithm_Access;
      Imu_Omega : Packed_F32x3_Record.C.U_C;
      St_Omega  : Packed_F32x3_Record.C.U_C)
     return Body_Rate_Miscompare_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "BodyRateMiscompareAlgorithm_update";

   -- Convert the raw update output to the idiomatic result.
   --* @param Output The raw C output struct.
   --* @return The selected body rate and fault flag as native Ada types.
   function To_Result (Output : Body_Rate_Miscompare_Output.C.U_C) return Update_Result
   is ((Omega_Bn_B => Packed_F32x3.C.Pack (Output.Omega_Bn_B),
        Fault_Detected => Output.Body_Rate_Fault_Detected /= 0));

   function Update
     (Self      : Body_Rate_Miscompare_Algorithm_Access;
      Imu_Omega : Packed_F32x3_Record.C.U_C;
      St_Omega  : Packed_F32x3_Record.C.U_C)
     return Update_Result
   is (To_Result (Update_C (Self, Imu_Omega, St_Omega)));

end Body_Rate_Miscompare_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
