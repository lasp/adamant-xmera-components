pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Att_Ref.C;
with Packed_F32x3_Record.C;

package Mrp_Rotation_Algorithm_C is

   --* Opaque handle for a MrpRotationAlgorithm instance.
   type Mrp_Rotation_Algorithm is limited private;
   type Mrp_Rotation_Algorithm_Access is access all Mrp_Rotation_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Initial_Sigma_Rr0 [-]     MRP of the rotating frame R relative to R0 that the rotation starts
   --*                                  from; must be finite.
   --* @param Omega_Rr0_R       [rad/s] Constant angular velocity of R relative to R0 in R components; must
   --*                                  be finite.
   --* @param Control_Period    [s]     Forward Euler integration step used every update; must be finite
   --*                                  and > 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Initial_Sigma_Rr0 : access constant Packed_F32x3_Record.C.U_C;
      Omega_Rr0_R       : access constant Packed_F32x3_Record.C.U_C;
      Control_Period    : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_validateConfig";

   --* @brief Construct a new MrpRotationAlgorithm from a configuration. The rotation starts
   --* from Initial_Sigma_Rr0.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Initial_Sigma_Rr0 : access constant Packed_F32x3_Record.C.U_C;
      Omega_Rr0_R       : access constant Packed_F32x3_Record.C.U_C;
      Control_Period    : Short_Float)
     return Mrp_Rotation_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_create";

   --* @brief Destroy a MrpRotationAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Mrp_Rotation_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The current
   --* rotation state is kept; Re_Initialize restarts it from the new initial attitude.
   --* The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self              : Mrp_Rotation_Algorithm_Access;
      Initial_Sigma_Rr0 : access constant Packed_F32x3_Record.C.U_C;
      Omega_Rr0_R       : access constant Packed_F32x3_Record.C.U_C;
      Control_Period    : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_setConfig";

   --* @brief Restart the rotation from the configured initial attitude. The configuration is
   --* left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Mrp_Rotation_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_reInitialize";

   --* @brief Advance the rotation one control period and compose it with the input reference frame.
   --* @param Self    The algorithm instance.
   --* @param Att_Ref_Input Input reference frame R0: attitude, rate, and acceleration relative to inertial.
   --*                      MrpRotationAttRefInputs_c has the same layout as AttRefMsgF32Payload, so the
   --*                      reference record crosses directly.
   --* @return Output reference frame R: attitude, rate, and acceleration relative to inertial.
   --*         MrpRotationOutput_c has the same layout as AttRefMsgF32Payload, so the result is the
   --*         reference record.
   function Update
     (Self          : Mrp_Rotation_Algorithm_Access;
      Att_Ref_Input : access constant Att_Ref.C.U_C)
     return Att_Ref.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_update";

private

   -- Private representation: opaque null record
   type Mrp_Rotation_Algorithm is null record;

end Mrp_Rotation_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
