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
   --* @param Sigma_Rcr0     [-]     Fixed body correction, the corrected frame Rc relative to the input
   --*                               reference R0; must be finite.
   --* @param Sigma_Rprc     [-]     Pointing offset, the frame Rp relative to Rc in body axes; must be
   --*                               finite.
   --* @param Spin_Axis_Rp   [-]     Spin axis of R relative to Rp in Rp axes; must be finite and
   --*                               within 1e-3 of unit length. It is normalized when configured.
   --* @param Spin_Rate      [rad/s] Signed spin rate of R relative to Rp about the spin axis; must be
   --*                               finite.
   --* @param Control_Period [s]     Forward Euler integration step used every update; must be finite
   --*                               and > 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Sigma_Rcr0     : access constant Packed_F32x3_Record.C.U_C;
      Sigma_Rprc     : access constant Packed_F32x3_Record.C.U_C;
      Spin_Axis_Rp   : access constant Packed_F32x3_Record.C.U_C;
      Spin_Rate      : Short_Float;
      Control_Period : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_validateConfig";

   --* @brief Construct a new MrpRotationAlgorithm from a configuration. The integrated
   --* rotation starts at identity.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Sigma_Rcr0     : access constant Packed_F32x3_Record.C.U_C;
      Sigma_Rprc     : access constant Packed_F32x3_Record.C.U_C;
      Spin_Axis_Rp   : access constant Packed_F32x3_Record.C.U_C;
      Spin_Rate      : Short_Float;
      Control_Period : Short_Float)
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

   --* @brief Apply a new configuration (validated; throws on invalid input). The new body
   --* correction and pointing offset apply at the next update; the integrated rotation is
   --* kept. The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self           : Mrp_Rotation_Algorithm_Access;
      Sigma_Rcr0     : access constant Packed_F32x3_Record.C.U_C;
      Sigma_Rprc     : access constant Packed_F32x3_Record.C.U_C;
      Spin_Axis_Rp   : access constant Packed_F32x3_Record.C.U_C;
      Spin_Rate      : Short_Float;
      Control_Period : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_setConfig";

   --* @brief Restart the integrated rotation (sigma_RRp) at identity. The configuration is
   --* left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Mrp_Rotation_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpRotationAlgorithm_reInitialize";

   --* @brief Advance the rotation one control period and apply the body correction, the pointing
   --* offset, and the rotation to the input reference frame.
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
