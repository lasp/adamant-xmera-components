pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with St_Platform_Measurement.C;
with St_Att.C;
with Packed_F32x3_Record.C;

package St_Platform_Attitude_Algorithm_C is

   --* Opaque handle for a StPlatformAttitudeAlgorithm instance.
   type St_Platform_Attitude_Algorithm is limited private;
   type St_Platform_Attitude_Algorithm_Access is access all St_Platform_Attitude_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Sigma_Pb MRP of the platform frame relative to the body frame; must be finite.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Sigma_Pb : Packed_F32x3_Record.C.U_C)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "StPlatformAttitudeAlgorithm_validateConfig";

   --* @brief Construct a new StPlatformAttitudeAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Sigma_Pb MRP of the platform frame relative to the body frame; must be finite.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Sigma_Pb : Packed_F32x3_Record.C.U_C)
     return St_Platform_Attitude_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "StPlatformAttitudeAlgorithm_create";

   --* @brief Destroy a StPlatformAttitudeAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : St_Platform_Attitude_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "StPlatformAttitudeAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self     The algorithm instance.
   --* @param Sigma_Pb MRP of the platform frame relative to the body frame; must be finite.
   procedure Set_Config
     (Self     : St_Platform_Attitude_Algorithm_Access;
      Sigma_Pb : Packed_F32x3_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "StPlatformAttitudeAlgorithm_setConfig";

   --* @brief Convert star tracker platform-frame attitude and rate to body frame.
   --* @param Self        The algorithm instance.
   --* @param Measurement Time-tagged inertial-to-platform attitude quaternion and
   --* platform-frame angular velocity quaternion, both scalar-last.
   --* @return Star tracker attitude output in body frame.
   function Update
     (Self        : St_Platform_Attitude_Algorithm_Access;
      Measurement : access constant St_Platform_Measurement.C.U_C)
     return St_Att.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "StPlatformAttitudeAlgorithm_update";

private

   -- Private representation: opaque null record
   type St_Platform_Attitude_Algorithm is null record;

end St_Platform_Attitude_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
