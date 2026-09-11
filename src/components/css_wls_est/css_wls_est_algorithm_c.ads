pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Css_Wls_Est_Constellation.C;
with Css_Wls_Est_Inputs.C;
with Css_Wls_Est_Output.C;
with Packed_F32x3.C;
with Packed_F32x3_X32.C;
with Packed_F32x32.C;

package Css_Wls_Est_Algorithm_C is

   --* Opaque handle for a CssWlsEstAlgorithm instance.
   type Css_Wls_Est_Algorithm is limited private;
   type Css_Wls_Est_Algorithm_Access is access all Css_Wls_Est_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Constellation     CSS geometry; Num_Css in [1, max], near-unit boresights, non-negative biases.
   --* @param Use_Weights       Whether to weight the measurements in the least squares fit.
   --* @param Sensor_Use_Thresh Cosine threshold at or below which a reading is discarded; must lie in [-1, 1].
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Constellation     : access constant Css_Wls_Est_Constellation.C.U_C;
      Use_Weights       : Boolean;
      Sensor_Use_Thresh : Short_Float)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_validateConfig";

   --* @brief Construct a new CssWlsEstAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Constellation     CSS geometry to install.
   --* @param Use_Weights       Whether to weight the measurements in the least squares fit.
   --* @param Sensor_Use_Thresh Cosine threshold at or below which a reading is discarded.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Constellation     : access constant Css_Wls_Est_Constellation.C.U_C;
      Use_Weights       : Boolean;
      Sensor_Use_Thresh : Short_Float)
     return Css_Wls_Est_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_create";

   --* @brief Destroy a CssWlsEstAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Css_Wls_Est_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). Parameters
   --* only: call Re_Initialize to clear the estimator's runtime state.
   --* @param Self              The algorithm instance.
   --* @param Constellation     CSS geometry to install.
   --* @param Use_Weights       Whether to weight the measurements in the least squares fit.
   --* @param Sensor_Use_Thresh Cosine threshold at or below which a reading is discarded.
   procedure Set_Config
     (Self              : Css_Wls_Est_Algorithm_Access;
      Constellation     : access constant Css_Wls_Est_Constellation.C.U_C;
      Use_Weights       : Boolean;
      Sensor_Use_Thresh : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_setConfig";

   --* @brief Clear the estimator's runtime state, discarding the prior heading and elapsed
   --* time so that no rate is produced until two headings have been observed again.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Css_Wls_Est_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_reInitialize";

   --* @brief Estimate the sun heading and body rate from one set of CSS readings.
   --* @param Self      The algorithm instance.
   --* @param Call_Time Evaluation time in nanoseconds.
   --* @param Inputs    Pointer to the per-cycle measurement inputs.
   --* @return The estimated heading, rate, residuals and active sensor count.
   function Update
     (Self      : Css_Wls_Est_Algorithm_Access;
      Call_Time : Unsigned_64;
      Inputs    : access constant Css_Wls_Est_Inputs.C.U_C)
     return Css_Wls_Est_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_update";

   --* @brief Get the CSS_WLS_EST_MAX_NUM_CSS constant for Ada validation.
   --* @return The maximum number of coarse sun sensors handled at the C boundary.
   function Get_Max_Num_Css
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssWlsEstAlgorithm_getMaxNumCss";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side sizing constants, checked at elaboration.
   -- CssWlsEstConstellation_c: uint32_t numCss; float cssNHat_B[CSS_WLS_EST_MAX_NUM_CSS][3];
   --                           float cssBias[CSS_WLS_EST_MAX_NUM_CSS];
   pragma Assert (Unsigned_32 (Packed_F32x3_X32.Length) = Get_Max_Num_Css);
   pragma Assert (Unsigned_32 (Packed_F32x3_X32.C.U_C'Object_Size / Packed_F32x3.C.U_C'Object_Size) = Get_Max_Num_Css);
   pragma Assert (Unsigned_32 (Packed_F32x32.Length) = Get_Max_Num_Css);
   pragma Assert (Unsigned_32 (Packed_F32x32.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Css);
   pragma Assert (Css_Wls_Est_Constellation.C.U_C'Object_Size =
      Unsigned_32'Object_Size + Packed_F32x3_X32.C.U_C'Object_Size + Packed_F32x32.C.U_C'Object_Size);
   -- CssWlsEstInputs_c: float cosValues[CSS_WLS_EST_MAX_NUM_CSS];
   pragma Assert (Packed_F32x32.C.U_C'Object_Size = Css_Wls_Est_Inputs.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Css_Wls_Est_Inputs.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Css);
   -- CssWlsEstOutput_c: Vector3f_c sunHeading_B, omega_BN_B, residualStateHeading;
   --                    float postFitResiduals[CSS_WLS_EST_MAX_NUM_CSS]; uint32_t numActiveCss;
   pragma Assert (Css_Wls_Est_Output.C.U_C'Object_Size =
      3 * Packed_F32x3.C.U_C'Object_Size + Packed_F32x32.C.U_C'Object_Size + Unsigned_32'Object_Size);

private

   -- Private representation: opaque null record
   type Css_Wls_Est_Algorithm is null record;

end Css_Wls_Est_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
