pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Packed_F32x3_Record.C;
with Packed_F32x9_Record.C;

package Convert_St_Platform_To_Body_Algorithm_C is

   --* Opaque handle for a ConvertStPlatformToBodyAlgorithm instance.
   type Convert_St_Platform_To_Body_Algorithm is limited private;
   type Convert_St_Platform_To_Body_Algorithm_Access is access all Convert_St_Platform_To_Body_Algorithm;

   --* POD config type matching ConvertStPlatformToBodyConfig_c in C
   --* (Matrix3f_c dcm_CB = 9 row-major floats).
   type Convert_St_Platform_To_Body_Config_C is record
      Dcm_Cb : aliased Packed_F32x9_Record.C.U_C; --* [-] body-to-case mounting DCM (orthonormal, det +1).
   end record
      with Convention => C_Pass_By_Copy;

   --* Fixed C array of four floats used for the star-tracker quaternion inputs.
   type St_Quaternion_C is array (0 .. 3) of aliased Short_Float
      with Convention => C;

   --* POD input type matching PlatformAttitude_c in C (float q_CN[4]). The
   --* algorithm consumes only the quaternion, so the Time_Tag carried by the
   --* Ada St_Platform_Attitude data dependency is intentionally not part of
   --* this POD and is re-attached to the output on the Ada side.
   type Platform_Attitude_C is record
      Q_CN : aliased St_Quaternion_C; --* [-] inertial-to-case quaternion (scalar-first).
   end record
      with Convention => C_Pass_By_Copy;

   --* POD input type matching PlatformAngularVelocity_c in C (float dq_CN[4]).
   type Platform_Angular_Velocity_C is record
      Dq_CN : aliased St_Quaternion_C; --* [-] case-frame delta quaternion (scalar-last).
   end record
      with Convention => C_Pass_By_Copy;

   --* POD output type matching StAttitudeOutput_c in C
   --* (float sigma_BN[3]; float omega_BN_B[3]). Carries no time tag.
   type St_Attitude_Output_C is record
      Sigma_BN   : aliased Packed_F32x3_Record.C.U_C; --* [-] MRP from inertial to body frame.
      Omega_BN_B : aliased Packed_F32x3_Record.C.U_C; --* [rad/s] body-frame angular velocity w.r.t. inertial.
   end record
      with Convention => C_Pass_By_Copy;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Config The configuration to check.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Config : access constant Convert_St_Platform_To_Body_Config_C)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_validateConfig";

   --* @brief Construct a new ConvertStPlatformToBodyAlgorithm from a configuration.
   --* @param Config The configuration to apply (validated; throws on invalid input).
   --* Validate config values with Validate_Config before calling so an invalid config
   --* never reaches this.
   function Create
     (Config : access constant Convert_St_Platform_To_Body_Config_C)
     return Convert_St_Platform_To_Body_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_create";

   --* @brief Destroy a ConvertStPlatformToBodyAlgorithm.
   procedure Destroy
     (Self : Convert_St_Platform_To_Body_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param Config The configuration to apply.
   procedure Set_Config
     (Self   : Convert_St_Platform_To_Body_Algorithm_Access;
      Config : access constant Convert_St_Platform_To_Body_Config_C)
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
      Platform_Attitude          : access constant Platform_Attitude_C;
      Platform_Angular_Velocity  : access constant Platform_Angular_Velocity_C)
     return St_Attitude_Output_C
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
