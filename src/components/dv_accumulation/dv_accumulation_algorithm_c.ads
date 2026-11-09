pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Packed_F32x3_Record.C;

package Dv_Accumulation_Algorithm_C is

   --* Opaque handle for a DvAccumulationAlgorithm instance.
   type Dv_Accumulation_Algorithm is limited private;
   type Dv_Accumulation_Algorithm_Access is access all Dv_Accumulation_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Control_Period [s] Control period, the integration step; finite and > 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Control_Period : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "DvAccumulationAlgorithm_validateConfig";

   --* @brief Construct a new DvAccumulationAlgorithm from a configuration. Validate the
   --* value with Validate_Config before calling; throws on invalid input.
   --* @param Control_Period [s] Control period, the integration step; finite and > 0.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Control_Period : Short_Float)
     return Dv_Accumulation_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "DvAccumulationAlgorithm_create";

   --* @brief Apply a new configuration (validated; throws on invalid input). The
   --* accumulator is kept; Re_Initialize starts it over.
   --* @param Self           The algorithm instance.
   --* @param Control_Period [s] Control period, the integration step; finite and > 0.
   procedure Set_Config
     (Self           : Dv_Accumulation_Algorithm_Access;
      Control_Period : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "DvAccumulationAlgorithm_setConfig";

   --* @brief Destroy a DvAccumulationAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Dv_Accumulation_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "DvAccumulationAlgorithm_destroy";

   --* @brief Zero the accumulator and start a new accumulation window: the next
   --* sample is not integrated.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Dv_Accumulation_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "DvAccumulationAlgorithm_reInitialize";

   --* @brief Subtract the bias from one sample of the body frame acceleration that
   --* gravity does not cause, integrate the remainder over the control period, and add
   --* it to the accumulator. The first call after construction or Re_Initialize only
   --* starts the window.
   --* @param Self                   The algorithm instance.
   --* @param R_Ddot_No_Gravity_Bn_B [m/s^2] Body frame acceleration that gravity does not cause.
   --* @param Accel_Bias_B           [m/s^2] Offset the measured acceleration contains, subtracted
   --*                               from the sample. Not validated: a non-finite bias gives a
   --*                               non-finite delta-V.
   --* @return [m/s] The accumulated body frame delta-V.
   function Update
     (Self                   : Dv_Accumulation_Algorithm_Access;
      R_Ddot_No_Gravity_Bn_B : Packed_F32x3_Record.C.U_C;
      Accel_Bias_B           : Packed_F32x3_Record.C.U_C)
     return Packed_F32x3_Record.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "DvAccumulationAlgorithm_update";

private

   -- Private representation: opaque null record
   type Dv_Accumulation_Algorithm is null record;

end Dv_Accumulation_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
