pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Gimbal_Angles_To_Motor_Angles_Output.C;
with Interfaces; use Interfaces;
with Interfaces.C;
with Packed_F32x9;
with Packed_F32x9x9.C;
with Spline_Coefficients.C;

package Gimbal_Angles_To_Motor_Angles_Algorithm_C is

   --* @brief Get the NUM_SPLINE_INTERVALS constant for validation.
   --* @return The number of uniform spline intervals per axis.
   function Get_Num_Spline_Intervals
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_getNumSplineIntervals";

   --* @brief Get the NUM_SPLINE_COEFFS constant for validation.
   --* @return The number of spline control coefficients of one motor surface.
   function Get_Num_Spline_Coeffs
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_getNumSplineCoeffs";

   -- ABI validation: the Ada coefficient table crossing the FFI boundary must
   -- match the C-side SplineCoefficients_c, float data[NUM_SPLINE_COEFFS],
   -- checked at elaboration. The table is tied three ways: the count, the purity
   -- of the record wrapping it, and the footprint, which is what catches a wrong
   -- element type.
   pragma Assert (Unsigned_32 (Packed_F32x9x9.Length * Packed_F32x9.Length) = Get_Num_Spline_Coeffs);
   pragma Assert (Spline_Coefficients.C.U_C'Object_Size = Packed_F32x9x9.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Spline_Coefficients.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Num_Spline_Coeffs);
   -- The table is square, and a cubic spline has three more coefficients per
   -- axis than intervals.
   pragma Assert (Packed_F32x9x9.Length = Packed_F32x9.Length);
   pragma Assert (Unsigned_32 (Packed_F32x9.Length) = Get_Num_Spline_Intervals + 3);

   --* Opaque handle for a GimbalAnglesToMotorAnglesAlgorithm instance.
   type Gimbal_Angles_To_Motor_Angles_Algorithm is limited private;
   type Gimbal_Angles_To_Motor_Angles_Algorithm_Access is access all Gimbal_Angles_To_Motor_Angles_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Steps_Per_Revolution [steps] Number of motor steps per 2*pi rad; must be in [1, 100000].
   --* @param Half_Diagonal_Tip    [rad]   Half of the rhombus diagonal along the gimbal tip axis; must be in (0, pi/2].
   --* @param Half_Diagonal_Tilt   [rad]   Half of the rhombus diagonal along the gimbal tilt axis; must be in (0, pi/2].
   --* @param Theta_Max            [rad]   Maximum requested thrust cone angle; must be greater than zero and not
   --* greater than the radius of the largest circle in the rhombus.
   --* @param Motor_1_Coefficients [steps] Motor 1 spline control coefficients; every entry must be in [-100000, 100000].
   --* @param Motor_2_Coefficients [steps] Motor 2 spline control coefficients; every entry must be in [-100000, 100000].
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Steps_Per_Revolution : Unsigned_32;
      Half_Diagonal_Tip    : Short_Float;
      Half_Diagonal_Tilt   : Short_Float;
      Theta_Max            : Short_Float;
      Motor_1_Coefficients : access constant Spline_Coefficients.C.U_C;
      Motor_2_Coefficients : access constant Spline_Coefficients.C.U_C)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_validateConfig";

   --* @brief Construct a new GimbalAnglesToMotorAnglesAlgorithm from a configuration. Before the
   --* first valid request, the motor angle output is the motor angles at zero gimbal angles.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Steps_Per_Revolution [steps] Number of motor steps per 2*pi rad.
   --* @param Half_Diagonal_Tip    [rad]   Half of the rhombus diagonal along the gimbal tip axis.
   --* @param Half_Diagonal_Tilt   [rad]   Half of the rhombus diagonal along the gimbal tilt axis.
   --* @param Theta_Max            [rad]   Maximum requested thrust cone angle.
   --* @param Motor_1_Coefficients [steps] Motor 1 spline control coefficients.
   --* @param Motor_2_Coefficients [steps] Motor 2 spline control coefficients.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Steps_Per_Revolution : Unsigned_32;
      Half_Diagonal_Tip    : Short_Float;
      Half_Diagonal_Tilt   : Short_Float;
      Theta_Max            : Short_Float;
      Motor_1_Coefficients : access constant Spline_Coefficients.C.U_C;
      Motor_2_Coefficients : access constant Spline_Coefficients.C.U_C)
     return Gimbal_Angles_To_Motor_Angles_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_create";

   --* @brief Destroy a GimbalAnglesToMotorAnglesAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Gimbal_Angles_To_Motor_Angles_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The cached previous
   --* valid output is preserved. If there is none, the motor angles of the new configuration at
   --* zero gimbal angles are used at once.
   --* @param Self                 The algorithm instance.
   --* @param Steps_Per_Revolution [steps] Number of motor steps per 2*pi rad.
   --* @param Half_Diagonal_Tip    [rad]   Half of the rhombus diagonal along the gimbal tip axis.
   --* @param Half_Diagonal_Tilt   [rad]   Half of the rhombus diagonal along the gimbal tilt axis.
   --* @param Theta_Max            [rad]   Maximum requested thrust cone angle.
   --* @param Motor_1_Coefficients [steps] Motor 1 spline control coefficients.
   --* @param Motor_2_Coefficients [steps] Motor 2 spline control coefficients.
   procedure Set_Config
     (Self                 : Gimbal_Angles_To_Motor_Angles_Algorithm_Access;
      Steps_Per_Revolution : Unsigned_32;
      Half_Diagonal_Tip    : Short_Float;
      Half_Diagonal_Tilt   : Short_Float;
      Theta_Max            : Short_Float;
      Motor_1_Coefficients : access constant Spline_Coefficients.C.U_C;
      Motor_2_Coefficients : access constant Spline_Coefficients.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_setConfig";

   --* @brief Clear the cached previous valid output, so the motor angles of the current
   --* configuration at zero gimbal angles are used until the next valid request.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Gimbal_Angles_To_Motor_Angles_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_reInitialize";

   --* @brief Determine the motor angles for the commanded gimbal tip and tilt angles.
   --* @param Self           The algorithm instance.
   --* @param Gimbal_Angle_1 [rad] Commanded gimbal tip angle.
   --* @param Gimbal_Angle_2 [rad] Commanded gimbal tilt angle.
   --* @return The motor angles. Requests that are not finite or are outside the rhombus
   --* return the previous valid motor angles.
   function Update
     (Self           : Gimbal_Angles_To_Motor_Angles_Algorithm_Access;
      Gimbal_Angle_1 : Short_Float;
      Gimbal_Angle_2 : Short_Float)
     return Gimbal_Angles_To_Motor_Angles_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "GimbalAnglesToMotorAnglesAlgorithm_update";

private

   -- Private representation: opaque null record
   type Gimbal_Angles_To_Motor_Angles_Algorithm is null record;

end Gimbal_Angles_To_Motor_Angles_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
