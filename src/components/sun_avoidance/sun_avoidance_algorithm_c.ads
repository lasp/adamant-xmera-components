pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Att_Ref.C;
with Packed_F32x3_Record.C;
with Packed_F64x3_Record.C;

package Sun_Avoidance_Algorithm_C is

   --* Opaque handle for a SunAvoidanceAlgorithm instance.
   type Sun_Avoidance_Algorithm is limited private;
   type Sun_Avoidance_Algorithm_Access is access all Sun_Avoidance_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Sensitive_Hat_B [-]     Body vector to keep off the Sun; must be finite and within 1e-3 of unit length.
   --* @param Slew_Rate       [rad/s] Rate at which the maneuver slews toward the input reference; must be finite
   --*                                and greater than zero.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Sensitive_Hat_B : access constant Packed_F32x3_Record.C.U_C;
      Slew_Rate       : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "SunAvoidanceAlgorithm_validateConfig";

   --* @brief Construct a new SunAvoidanceAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Sensitive_Hat_B [-]     Body vector to keep off the Sun (stored normalized).
   --* @param Slew_Rate       [rad/s] Rate at which the maneuver slews toward the input reference.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Sensitive_Hat_B : access constant Packed_F32x3_Record.C.U_C;
      Slew_Rate       : Short_Float)
     return Sun_Avoidance_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "SunAvoidanceAlgorithm_create";

   --* @brief Destroy a SunAvoidanceAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Sun_Avoidance_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunAvoidanceAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The planned maneuver is preserved.
   --* @param Self            The algorithm instance.
   --* @param Sensitive_Hat_B [-]     Body vector to keep off the Sun (stored normalized).
   --* @param Slew_Rate       [rad/s] Rate at which the maneuver slews toward the input reference.
   procedure Set_Config
     (Self            : Sun_Avoidance_Algorithm_Access;
      Sensitive_Hat_B : access constant Packed_F32x3_Record.C.U_C;
      Slew_Rate       : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "SunAvoidanceAlgorithm_setConfig";

   --* @brief Discard the planned maneuver so the next Update plans a new one from the
   --* current geometry. The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Sun_Avoidance_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunAvoidanceAlgorithm_reInitialize";

   --* @brief Compute the Sun avoidance maneuver adjusted reference frame.
   --* The C shim's input and output reference structs have the same layout as
   --* AttRefMsgF32Payload (sigma_RN, omega_RN_N, domega_RN_N), so both cross as Att_Ref.
   --* @param Self      The algorithm instance.
   --* @param Sigma_Bn  [-]  Measured MRP attitude of the body relative to inertial.
   --* @param Ref       The input attitude reference.
   --* @param R_Bn_N    [m]  Spacecraft inertial position.
   --* @param R_Sn_N    [m]  Sun inertial position. All zero means no Sun information.
   --* @param Call_Time [ns] The time of this call, from which the elapsed slew is measured.
   --* @return The maneuver adjusted attitude reference.
   function Update
     (Self      : Sun_Avoidance_Algorithm_Access;
      Sigma_Bn  : access constant Packed_F32x3_Record.C.U_C;
      Ref       : access constant Att_Ref.C.U_C;
      R_Bn_N    : access constant Packed_F64x3_Record.C.U_C;
      R_Sn_N    : access constant Packed_F64x3_Record.C.U_C;
      Call_Time : Unsigned_64)
     return Att_Ref.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "SunAvoidanceAlgorithm_update";

private

   -- Private representation: opaque null record
   type Sun_Avoidance_Algorithm is null record;

end Sun_Avoidance_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
