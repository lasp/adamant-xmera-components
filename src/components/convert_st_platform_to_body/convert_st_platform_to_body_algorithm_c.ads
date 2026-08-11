pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with St_Platform_Attitude.C;
with St_Platform_Angular_Velocity.C;
with St_Att.C;
with Packed_F32x9_Record.C;

package Convert_St_Platform_To_Body_Algorithm_C is

   --* Opaque handle for a ConvertStPlatformToBodyAlgorithm instance.
   type Convert_St_Platform_To_Body_Algorithm is limited private;
   type Convert_St_Platform_To_Body_Algorithm_Access is access all Convert_St_Platform_To_Body_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Dcm_Cb 3x3 row-major DCM from body to case frame (orthonormal, det +1).
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Dcm_Cb : Packed_F32x9_Record.C.U_C)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_validateConfig";

   --* @brief Construct a new ConvertStPlatformToBodyAlgorithm from a configuration.
   --* Validate the DCM with Validate_Config before calling; throws on invalid input.
   --* @param Dcm_Cb 3x3 row-major DCM from body to case frame (orthonormal, det +1).
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Dcm_Cb : Packed_F32x9_Record.C.U_C)
     return Convert_St_Platform_To_Body_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_create";

   --* @brief Destroy a ConvertStPlatformToBodyAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Convert_St_Platform_To_Body_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param Dcm_Cb 3x3 row-major DCM from body to case frame.
   procedure Set_Config
     (Self   : Convert_St_Platform_To_Body_Algorithm_Access;
      Dcm_Cb : Packed_F32x9_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_setConfig";

   --* @brief Convert star tracker case-frame attitude and rate to body frame.
   --* @param Self                       The algorithm instance.
   --* @param Platform_Attitude          Inertial-to-case attitude quaternion input.
   --* @param Platform_Angular_Velocity  Case-frame delta quaternion rate input.
   --* @return Star tracker attitude output in body frame.
   function Update
     (Self                       : Convert_St_Platform_To_Body_Algorithm_Access;
      Platform_Attitude          : access constant St_Platform_Attitude.C.U_C;
      Platform_Angular_Velocity  : access constant St_Platform_Angular_Velocity.C.U_C)
     return St_Att.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_update";

private

   -- Private representation: opaque null record
   type Convert_St_Platform_To_Body_Algorithm is null record;

end Convert_St_Platform_To_Body_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
