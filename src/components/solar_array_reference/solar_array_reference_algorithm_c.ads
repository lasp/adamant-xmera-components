pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Packed_F32x3_Record.C;
with Solar_Array_Reference_Enums;

package Solar_Array_Reference_Algorithm_C is

   --* Opaque handle for a SolarArrayReferenceAlgorithm instance.
   type Solar_Array_Reference_Algorithm is limited private;
   type Solar_Array_Reference_Algorithm_Access is access all Solar_Array_Reference_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Drive_Axis            [-]   Solar array drive axis in body frame; finite, near unit, orthogonal
   --*                                    to the surface normal.
   --* @param Surface_Normal        [-]   Solar array surface normal at zero rotation; finite, near unit,
   --*                                    orthogonal to the drive axis.
   --* @param Alignment_Threshold   [rad] Alignment threshold between the sun direction and the drive axis;
   --*                                    in [1e-3, pi/2].
   --* @param Tracking_Mode         [-]   Array tracking mode.
   --* @param Specified_Array_Angle [rad] Reference array angle used in the specified angle mode; in [-pi, pi].
   --* @param Offset_Angle          [rad] Offset added to the sun tracking reference angle; in [-pi, pi].
   --*                                    Not applied in the specified angle mode.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Drive_Axis            : access constant Packed_F32x3_Record.C.U_C;
      Surface_Normal        : access constant Packed_F32x3_Record.C.U_C;
      Alignment_Threshold   : Short_Float;
      Tracking_Mode         : Solar_Array_Reference_Enums.Tracking_Mode.C.E_C;
      Specified_Array_Angle : Short_Float;
      Offset_Angle          : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "SolarArrayReferenceAlgorithm_validateConfig";

   --* @brief Construct a new SolarArrayReferenceAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Drive_Axis            : access constant Packed_F32x3_Record.C.U_C;
      Surface_Normal        : access constant Packed_F32x3_Record.C.U_C;
      Alignment_Threshold   : Short_Float;
      Tracking_Mode         : Solar_Array_Reference_Enums.Tracking_Mode.C.E_C;
      Specified_Array_Angle : Short_Float;
      Offset_Angle          : Short_Float)
     return Solar_Array_Reference_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "SolarArrayReferenceAlgorithm_create";

   --* @brief Destroy a SolarArrayReferenceAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Solar_Array_Reference_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SolarArrayReferenceAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The reference
   --* angle retained from the previous Update is kept; Re_Initialize zeroes it. The
   --* parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self                  : Solar_Array_Reference_Algorithm_Access;
      Drive_Axis            : access constant Packed_F32x3_Record.C.U_C;
      Surface_Normal        : access constant Packed_F32x3_Record.C.U_C;
      Alignment_Threshold   : Short_Float;
      Tracking_Mode         : Solar_Array_Reference_Enums.Tracking_Mode.C.E_C;
      Specified_Array_Angle : Short_Float;
      Offset_Angle          : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "SolarArrayReferenceAlgorithm_setConfig";

   --* @brief Zero the reference angle retained from the previous Update. The configuration
   --* is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Solar_Array_Reference_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SolarArrayReferenceAlgorithm_reInitialize";

   --* @brief Compute the reference array angle. The algorithm retains the result, and
   --* returns it again when the sun direction is within the alignment threshold of the
   --* drive axis and no rotation angle is preferred.
   --* @param Self          The algorithm instance.
   --* @param Sigma_Bn      [-]   Body attitude MRP relative to inertial.
   --* @param Sigma_Rn      [-]   Reference attitude MRP relative to inertial.
   --* @param R_Hat_In_Sb_B [-]   Sun direction in body frame components.
   --* @return [rad] Reference array angle wrapped to [-pi, pi].
   function Update
     (Self          : Solar_Array_Reference_Algorithm_Access;
      Sigma_Bn      : Packed_F32x3_Record.C.U_C;
      Sigma_Rn      : Packed_F32x3_Record.C.U_C;
      R_Hat_In_Sb_B : Packed_F32x3_Record.C.U_C)
     return Short_Float
     with Import        => True,
          Convention    => C,
          External_Name => "SolarArrayReferenceAlgorithm_update";

private

   -- Private representation: opaque null record
   type Solar_Array_Reference_Algorithm is null record;

end Solar_Array_Reference_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
