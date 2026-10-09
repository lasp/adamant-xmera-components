pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Inertial_Filter_Output.C;
with Inertial_Filter_Rate_Data.C;
with Inertial_Filter_St_Att_Data.C;
with Inertial_Filter_State_Matrix.C;
with Inertial_Filter_State_Vector.C;

package Inertial_Filter_Algorithm_C is

   --* Opaque handle for an InertialFilterAlgorithm instance.
   type Inertial_Filter_Algorithm is limited private;
   type Inertial_Filter_Algorithm_Access is access all Inertial_Filter_Algorithm;

   --* @brief Get the state vector dimension for Ada elaboration time validation.
   --* @return INERTIAL_FILTER_NUM_STATES.
   function Get_Num_States return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_getNumStates";

   -- ABI validation: the state vector and matrix crossing the FFI boundary are sized
   -- by the C-side INERTIAL_FILTER_NUM_STATES, checked at elaboration. The count and the
   -- footprint of each wrapped array are tied to the getter, so a change to the C constant
   -- fails here rather than as silent memory corruption in the shim.
   pragma Assert (Inertial_Filter_State_Vector.C.U_C'Size = Inertial_Filter_State_Vector.T'Size);
   pragma Assert (Inertial_Filter_State_Vector.T'Size = Get_Num_States * 64);
   pragma Assert (Inertial_Filter_State_Matrix.C.U_C'Size = Inertial_Filter_State_Matrix.T'Size);
   pragma Assert (Inertial_Filter_State_Matrix.T'Size = Get_Num_States * Get_Num_States * 64);

   --* @brief Report whether a configuration would be accepted by Create.
   --* @param Alpha                      [-]     Sigma point spread; in (0, 1].
   --* @param Beta                       [-]     Prior knowledge tunable; in [0, 2].
   --* @param Process_Noise              [-]     N x N process noise; positive semi-definite.
   --* @param Initial_State              [-]     N element initial state seed; finite.
   --* @param Initial_Covariance         [-]     N x N initial covariance; positive semi-definite.
   --* @param St_Measurement_Noise_Std   [-]     Star tracker attitude measurement noise std; >= 0.
   --* @param Rate_Measurement_Noise_Std [rad/s] Rate measurement noise std; >= 0.
   --* @return True when the configuration is valid. Never throws, so it can guard the
   --* throwing Create from an invalid configuration.
   function Validate_Config
     (Alpha                      : Long_Float;
      Beta                       : Long_Float;
      Process_Noise              : access constant Inertial_Filter_State_Matrix.C.U_C;
      Initial_State              : access constant Inertial_Filter_State_Vector.C.U_C;
      Initial_Covariance         : access constant Inertial_Filter_State_Matrix.C.U_C;
      St_Measurement_Noise_Std   : Long_Float;
      Rate_Measurement_Noise_Std : Long_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_validateConfig";

   --* @brief Construct a filter from a validated configuration and seed its state and
   --* covariance from it. Validate the values with Validate_Config before calling; throws
   --* on invalid input. The parameters are as for Validate_Config.
   --* @return The new filter instance, which must be released with Destroy.
   function Create
     (Alpha                      : Long_Float;
      Beta                       : Long_Float;
      Process_Noise              : access constant Inertial_Filter_State_Matrix.C.U_C;
      Initial_State              : access constant Inertial_Filter_State_Vector.C.U_C;
      Initial_Covariance         : access constant Inertial_Filter_State_Matrix.C.U_C;
      St_Measurement_Noise_Std   : Long_Float;
      Rate_Measurement_Noise_Std : Long_Float)
     return Inertial_Filter_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_create";

   --* @brief Replace the configuration and re-derive the filter parameters. The current
   --* estimate is kept. Validate the values with Validate_Config before calling; throws on
   --* invalid input. The parameters are as for Validate_Config.
   --* @param Self The filter instance.
   procedure Set_Config
     (Self                       : Inertial_Filter_Algorithm_Access;
      Alpha                      : Long_Float;
      Beta                       : Long_Float;
      Process_Noise              : access constant Inertial_Filter_State_Matrix.C.U_C;
      Initial_State              : access constant Inertial_Filter_State_Vector.C.U_C;
      Initial_Covariance         : access constant Inertial_Filter_State_Matrix.C.U_C;
      St_Measurement_Noise_Std   : Long_Float;
      Rate_Measurement_Noise_Std : Long_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_setConfig";

   --* @brief Destroy a filter instance.
   --* @param Self The filter instance to destroy.
   procedure Destroy
     (Self : Inertial_Filter_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_destroy";

   --* @brief Clear the pending measurements and the residual snapshots. The filter state
   --* and covariance are kept.
   --* @param Self The filter instance.
   procedure Re_Initialize_Except_Persistent_States
     (Self : Inertial_Filter_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_reInitializeExceptPersistentStates";

   --* @brief Re_Initialize_Except_Persistent_States, and also re-seed the filter state and
   --* covariance from the configuration.
   --* @param Self The filter instance.
   procedure Re_Initialize
     (Self : Inertial_Filter_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_reInitialize";

   --* @brief Advance the filter to the current time, folding in the star tracker attitude
   --* and rate readings whose time tag is greater than zero.
   --* @param Self            The filter instance.
   --* @param Current_Seconds [s] Time to advance the filter to.
   --* @param St_Att          Star tracker attitude reading.
   --* @param Rate            Rate reading.
   --* @return The filter snapshot after the update: state, covariance, and the residuals of
   --* each measurement kind.
   function Update
     (Self            : Inertial_Filter_Algorithm_Access;
      Current_Seconds : Long_Float;
      St_Att          : access constant Inertial_Filter_St_Att_Data.C.U_C;
      Rate            : access constant Inertial_Filter_Rate_Data.C.U_C)
     return Inertial_Filter_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "InertialFilterAlgorithm_update";

private

   -- Private representation: opaque null record
   type Inertial_Filter_Algorithm is null record;

end Inertial_Filter_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
