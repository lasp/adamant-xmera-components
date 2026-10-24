pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Sunline_Filter_Css_Data.C;
with Sunline_Filter_Css_Matrix.C;
with Sunline_Filter_Css_Vector.C;
with Sunline_Filter_Output.C;
with Sunline_Filter_Rate_Data.C;
with Sunline_Filter_State_Matrix.C;
with Sunline_Filter_State_Vector.C;

package Sunline_Filter_Algorithm_C is

   --* Opaque handle for a SunlineFilterAlgorithm instance.
   type Sunline_Filter_Algorithm is limited private;
   type Sunline_Filter_Algorithm_Access is access all Sunline_Filter_Algorithm;

   --* @brief Get the SUNLINE_FILTER_MAX_CSS constant for Ada validation.
   --* @return The maximum number of coarse sun sensors.
   function Get_Max_Css return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_getMaxCss";

   --* @brief Get the SUNLINE_FILTER_NUM_STATES constant for Ada validation.
   --* @return The filter state dimension.
   function Get_Num_States return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_getNumStates";

   -- ABI validation: the arrays crossing the FFI boundary are sized by the C-side
   -- SUNLINE_FILTER_NUM_STATES and SUNLINE_FILTER_MAX_CSS, checked at elaboration. The
   -- count and the footprint of each wrapped array are tied to the getters, so a change
   -- to a C constant fails here rather than as silent memory corruption in the shim.
   pragma Assert (Sunline_Filter_State_Vector.C.U_C'Size = Sunline_Filter_State_Vector.T'Size);
   pragma Assert (Sunline_Filter_State_Vector.T'Size = Get_Num_States * 64);
   pragma Assert (Sunline_Filter_State_Matrix.C.U_C'Size = Sunline_Filter_State_Matrix.T'Size);
   pragma Assert (Sunline_Filter_State_Matrix.T'Size = Get_Num_States * Get_Num_States * 64);
   pragma Assert (Sunline_Filter_Css_Vector.C.U_C'Size = Sunline_Filter_Css_Vector.T'Size);
   pragma Assert (Sunline_Filter_Css_Vector.T'Size = Get_Max_Css * 64);
   pragma Assert (Sunline_Filter_Css_Matrix.C.U_C'Size = Sunline_Filter_Css_Matrix.T'Size);
   pragma Assert (Sunline_Filter_Css_Matrix.T'Size = Get_Max_Css * 3 * 64);

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Alpha                      [-]     Sigma point spread; in (0, 1].
   --* @param Beta                       [-]     Prior knowledge tunable; in [0, 2].
   --* @param Process_Noise              [-]     N x N process noise; positive semi-definite.
   --* @param Initial_State              [-]     N element initial state seed; finite.
   --* @param Initial_Covariance         [-]     N x N initial covariance; positive semi-definite.
   --* @param Bias_Lower_Bound           [-]     Lower clamp on the CSS bias state; > 0 and < the upper bound.
   --* @param Bias_Upper_Bound           [-]     Upper clamp on the CSS bias state; > the lower bound.
   --* @param Css_N_Hat                  [-]     Per-CSS boresight unit vectors in body frame.
   --* @param Css_Scale_Factor           [-]     Per-CSS calibration scale factor; each >= 0.
   --* @param Number_Of_Css              [-]     Number of active CSS; in [1, SUNLINE_FILTER_MAX_CSS].
   --* @param Sensor_Threshold           [-]     Minimum cosine value that counts a sensor as active; >= 0.
   --* @param Css_Measurement_Noise_Std  [-]     CSS measurement noise std; >= 0.
   --* @param Gyro_Measurement_Noise_Std [rad/s] Gyro measurement noise std; >= 0.
   --* @return True when the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Alpha                      : Long_Float;
      Beta                       : Long_Float;
      Process_Noise              : access constant Sunline_Filter_State_Matrix.C.U_C;
      Initial_State              : access constant Sunline_Filter_State_Vector.C.U_C;
      Initial_Covariance         : access constant Sunline_Filter_State_Matrix.C.U_C;
      Bias_Lower_Bound           : Long_Float;
      Bias_Upper_Bound           : Long_Float;
      Css_N_Hat                  : access constant Sunline_Filter_Css_Matrix.C.U_C;
      Css_Scale_Factor           : access constant Sunline_Filter_Css_Vector.C.U_C;
      Number_Of_Css              : Unsigned_32;
      Sensor_Threshold           : Long_Float;
      Css_Measurement_Noise_Std  : Long_Float;
      Gyro_Measurement_Noise_Std : Long_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_validateConfig";

   --* @brief Construct a filter from a validated configuration and seed its state and
   --* covariance from it. Validate the values with Validate_Config before calling; throws
   --* on invalid input. The parameters are as for Validate_Config.
   --* @return The new filter instance, which must be released with Destroy.
   function Create
     (Alpha                      : Long_Float;
      Beta                       : Long_Float;
      Process_Noise              : access constant Sunline_Filter_State_Matrix.C.U_C;
      Initial_State              : access constant Sunline_Filter_State_Vector.C.U_C;
      Initial_Covariance         : access constant Sunline_Filter_State_Matrix.C.U_C;
      Bias_Lower_Bound           : Long_Float;
      Bias_Upper_Bound           : Long_Float;
      Css_N_Hat                  : access constant Sunline_Filter_Css_Matrix.C.U_C;
      Css_Scale_Factor           : access constant Sunline_Filter_Css_Vector.C.U_C;
      Number_Of_Css              : Unsigned_32;
      Sensor_Threshold           : Long_Float;
      Css_Measurement_Noise_Std  : Long_Float;
      Gyro_Measurement_Noise_Std : Long_Float)
     return Sunline_Filter_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_create";

   --* @brief Destroy a filter instance.
   --* @param Self The filter instance to destroy.
   procedure Destroy
     (Self : Sunline_Filter_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_destroy";

   --* @brief Replace the configuration and re-derive the filter parameters. The current
   --* estimate is kept. Validate the values with Validate_Config before calling; throws on
   --* invalid input. The parameters are as for Validate_Config.
   --* @param Self The filter instance.
   procedure Set_Config
     (Self                       : Sunline_Filter_Algorithm_Access;
      Alpha                      : Long_Float;
      Beta                       : Long_Float;
      Process_Noise              : access constant Sunline_Filter_State_Matrix.C.U_C;
      Initial_State              : access constant Sunline_Filter_State_Vector.C.U_C;
      Initial_Covariance         : access constant Sunline_Filter_State_Matrix.C.U_C;
      Bias_Lower_Bound           : Long_Float;
      Bias_Upper_Bound           : Long_Float;
      Css_N_Hat                  : access constant Sunline_Filter_Css_Matrix.C.U_C;
      Css_Scale_Factor           : access constant Sunline_Filter_Css_Vector.C.U_C;
      Number_Of_Css              : Unsigned_32;
      Sensor_Threshold           : Long_Float;
      Css_Measurement_Noise_Std  : Long_Float;
      Gyro_Measurement_Noise_Std : Long_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_setConfig";

   --* @brief Advance the filter to the current time, folding in the coarse sun sensor and
   --* rate readings whose time tag is greater than zero. A reading whose time tag does not
   --* advance past the last one consumed is ignored.
   --* @param Self            The filter instance.
   --* @param Current_Seconds [s] Time to advance the filter to.
   --* @param Css_Data        Coarse sun sensor reading.
   --* @param Rate_Data       Gyro rate reading.
   --* @return The filter snapshot after the update: state, covariance, and the residuals of
   --* each measurement kind.
   function Update
     (Self            : Sunline_Filter_Algorithm_Access;
      Current_Seconds : Long_Float;
      Css_Data        : access constant Sunline_Filter_Css_Data.C.U_C;
      Rate_Data       : access constant Sunline_Filter_Rate_Data.C.U_C)
     return Sunline_Filter_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_update";

   --* @brief Clear the pending measurements and the residual snapshots. The filter state
   --* and covariance are kept.
   --* @param Self The filter instance.
   procedure Re_Initialize_Except_Persistent_States
     (Self : Sunline_Filter_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_reInitializeExceptPersistentStates";

   --* @brief Re_Initialize_Except_Persistent_States, and also re-seed the filter state and
   --* covariance from the configuration.
   --* @param Self The filter instance.
   procedure Re_Initialize
     (Self : Sunline_Filter_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunlineFilterAlgorithm_reInitialize";

private

   -- Private representation: opaque null record
   type Sunline_Filter_Algorithm is null record;

end Sunline_Filter_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
