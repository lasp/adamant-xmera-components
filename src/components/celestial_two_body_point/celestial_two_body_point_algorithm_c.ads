pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C;
with Att_Ref.C;
with Packed_F64x3_Record.C;

package Celestial_Two_Body_Point_Algorithm_C is

   --* Opaque handle for a CelestialTwoBodyPointAlgorithm instance.
   type Celestial_Two_Body_Point_Algorithm is limited private;
   type Celestial_Two_Body_Point_Algorithm_Access is access all Celestial_Two_Body_Point_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Alignment_Threshold [rad] Primary and secondary body alignment threshold; must be in [1e-6, pi/2].
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Alignment_Threshold : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "CelestialTwoBodyPointAlgorithm_validateConfig";

   --* @brief Construct a new CelestialTwoBodyPointAlgorithm from a configuration.
   --* Validate the value with Validate_Config before calling; throws on invalid input.
   --* @param Alignment_Threshold [rad] Primary and secondary body alignment threshold.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Alignment_Threshold : Short_Float)
     return Celestial_Two_Body_Point_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "CelestialTwoBodyPointAlgorithm_create";

   --* @brief Destroy a CelestialTwoBodyPointAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Celestial_Two_Body_Point_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "CelestialTwoBodyPointAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self                The algorithm instance.
   --* @param Alignment_Threshold [rad] Primary and secondary body alignment threshold.
   procedure Set_Config
     (Self                : Celestial_Two_Body_Point_Algorithm_Access;
      Alignment_Threshold : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "CelestialTwoBodyPointAlgorithm_setConfig";

   --* @brief Compute the two body celestial pointing attitude reference.
   --* @param Self   The algorithm instance.
   --* @param R_Pn_N [m]   Primary celestial body inertial position.
   --* @param V_Pn_N [m/s] Primary celestial body inertial velocity.
   --* @param R_Sn_N [m]   Secondary celestial body inertial position.
   --* @param V_Sn_N [m/s] Secondary celestial body inertial velocity.
   --* @param R_Bn_N [m]   Spacecraft inertial position.
   --* @param V_Bn_N [m/s] Spacecraft inertial velocity.
   --* @return Reference attitude, angular velocity, and angular acceleration. All zero when
   --* the geometry is degenerate.
   function Update
     (Self   : Celestial_Two_Body_Point_Algorithm_Access;
      R_Pn_N : Packed_F64x3_Record.C.U_C;
      V_Pn_N : Packed_F64x3_Record.C.U_C;
      R_Sn_N : Packed_F64x3_Record.C.U_C;
      V_Sn_N : Packed_F64x3_Record.C.U_C;
      R_Bn_N : Packed_F64x3_Record.C.U_C;
      V_Bn_N : Packed_F64x3_Record.C.U_C)
     return Att_Ref.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "CelestialTwoBodyPointAlgorithm_update";

private

   -- Private representation: opaque null record
   type Celestial_Two_Body_Point_Algorithm is null record;

end Celestial_Two_Body_Point_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
