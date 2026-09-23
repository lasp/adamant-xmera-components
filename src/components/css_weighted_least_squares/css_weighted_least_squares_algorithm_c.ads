pragma Ada_2012;
pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Css_Availability_Array.C;
with Css_Availability_X8.C;
with Css_Boresight_Array.C;
with Css_Reading_Array.C;
with Css_Weighted_Least_Squares_Output.C;
with Packed_F32x3.C;
with Packed_F32x8.C;
with Packed_F32x24.C;

package Css_Weighted_Least_Squares_Algorithm_C is

   --* @brief Get the MAX_NUM_CSS_SENSORS constant for validation.
   --* @return The maximum number of coarse sun sensors handled at the C boundary.
   function Get_Max_Num_Css
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_getMaxNumCss";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side MAX_NUM_CSS_SENSORS, checked at elaboration.
   -- CssBoresightArray_c: float data[MAX_NUM_CSS_SENSORS * 3];
   pragma Assert (Unsigned_32 (Packed_F32x24.Length / 3) = Get_Max_Num_Css);
   pragma Assert (Css_Boresight_Array.C.U_C'Object_Size = Packed_F32x24.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Css_Boresight_Array.C.U_C'Object_Size / Short_Float'Object_Size / 3) = Get_Max_Num_Css);
   -- CssAvailabilityArray_c: uint8_t availability[MAX_NUM_CSS_SENSORS]; one byte per
   -- slot, which the E8 enumeration array matches without conversion.
   pragma Assert (Unsigned_32 (Css_Availability_X8.Length) = Get_Max_Num_Css);
   pragma Assert (Css_Availability_Array.C.U_C'Object_Size = Css_Availability_X8.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Css_Availability_Array.C.U_C'Object_Size / Unsigned_8'Object_Size) = Get_Max_Num_Css);
   -- CssReadingArray_c: float cosValues[MAX_NUM_CSS_SENSORS];
   pragma Assert (Unsigned_32 (Packed_F32x8.Length) = Get_Max_Num_Css);
   pragma Assert (Css_Reading_Array.C.U_C'Object_Size = Packed_F32x8.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Css_Reading_Array.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Css);
   -- CssWeightedLeastSquaresOutput_c: two Vector3f_c, float postFitResiduals[MAX_NUM_CSS_SENSORS],
   -- uint32_t numCssViewingSun.
   pragma Assert (Css_Weighted_Least_Squares_Output.C.U_C'Object_Size =
      2 * Packed_F32x3.C.U_C'Object_Size + Packed_F32x8.C.U_C'Object_Size + Unsigned_32'Object_Size);

   --* Opaque handle for a CssWeightedLeastSquaresAlgorithm instance.
   type Css_Weighted_Least_Squares_Algorithm is limited private;
   type Css_Weighted_Least_Squares_Algorithm_Access is access all Css_Weighted_Least_Squares_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Css_N_Hat_B                [-] Sensor boresights in body frame components, three per sensor in
   --*                                       row major order; an available sensor needs a unit vector to within 1e-3.
   --* @param Css_Availability           [-] Availability of each sensor slot, one byte per slot: 0 available,
   --*                                       1 unavailable. An unavailable sensor takes no part in the fit and its
   --*                                       boresight is never read.
   --* @param Use_Measurements_As_Weights [-] Whether to weight the measurements in the least squares fit.
   --* @param Sensor_Use_Thresh          [-] Cosine threshold at or below which a reading is discarded; must lie in [0, 1].
   --* @param Control_Period             [s] Time between two update calls; must be finite and > 0.
   --* @return True when the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Css_N_Hat_B                 : access constant Css_Boresight_Array.C.U_C;
      Css_Availability            : access constant Css_Availability_Array.C.U_C;
      Use_Measurements_As_Weights : Interfaces.C.C_bool;
      Sensor_Use_Thresh           : Short_Float;
      Control_Period              : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_validateConfig";

   --* @brief Construct a new CssWeightedLeastSquaresAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Css_N_Hat_B                 : access constant Css_Boresight_Array.C.U_C;
      Css_Availability            : access constant Css_Availability_Array.C.U_C;
      Use_Measurements_As_Weights : Interfaces.C.C_bool;
      Sensor_Use_Thresh           : Short_Float;
      Control_Period              : Short_Float)
     return Css_Weighted_Least_Squares_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_create";

   --* @brief Destroy a CssWeightedLeastSquaresAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Css_Weighted_Least_Squares_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The estimator's
   --* runtime state is kept; call Re_Initialize to clear it. The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self                        : Css_Weighted_Least_Squares_Algorithm_Access;
      Css_N_Hat_B                 : access constant Css_Boresight_Array.C.U_C;
      Css_Availability            : access constant Css_Availability_Array.C.U_C;
      Use_Measurements_As_Weights : Interfaces.C.C_bool;
      Sensor_Use_Thresh           : Short_Float;
      Control_Period              : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_setConfig";

   --* @brief Clear the estimator's runtime state, discarding the prior heading so that no rate is
   --* produced until two headings have been observed again. The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Css_Weighted_Least_Squares_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_reInitialize";

   --* @brief Estimate the sun heading and body rate from one set of coarse sun sensor readings.
   --* @param Self       The algorithm instance.
   --* @param Cos_Values [-] Cosine reading of each sensor, indexed by sensor. A reading at or below the
   --*                   use threshold is dropped.
   --* @return The estimated heading and rate, the post-fit residuals indexed by observation, and the
   --*         count of sensors viewing the sun.
   function Update
     (Self       : Css_Weighted_Least_Squares_Algorithm_Access;
      Cos_Values : access constant Css_Reading_Array.C.U_C)
     return Css_Weighted_Least_Squares_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "CssWeightedLeastSquaresAlgorithm_update";

private
   -- Private representation: opaque null record
   type Css_Weighted_Least_Squares_Algorithm is null record;
end Css_Weighted_Least_Squares_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
