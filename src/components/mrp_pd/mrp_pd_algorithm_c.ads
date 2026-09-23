pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C;
with Packed_F32x3_Record.C;
with Packed_F32x9_Record.C;

package Mrp_Pd_Algorithm_C is

   --* Opaque handle for a MrpPDAlgorithm instance.
   type Mrp_Pd_Algorithm is limited private;
   type Mrp_Pd_Algorithm_Access is access all Mrp_Pd_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param K [Nm] Proportional gain on the MRP attitude error; must be >= 0.
   --* @param P [Nms] Rate error feedback gain; must be >= 0.
   --* @param Known_Torque_Pnt_B_B [Nm] Known external torque in body frame components; must be finite.
   --* @param Iscpnt_B_B [kg m^2] Spacecraft inertia about point B; must be a valid inertia matrix.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (K                    : Short_Float;
      P                    : Short_Float;
      Known_Torque_Pnt_B_B : Packed_F32x3_Record.C.U_C;
      Iscpnt_B_B           : Packed_F32x9_Record.C.U_C)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "MrpPDAlgorithm_validateConfig";

   --* @brief Construct a new MrpPDAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param K [Nm] Proportional gain on the MRP attitude error.
   --* @param P [Nms] Rate error feedback gain.
   --* @param Known_Torque_Pnt_B_B [Nm] Known external torque in body frame components.
   --* @param Iscpnt_B_B [kg m^2] Spacecraft inertia about point B.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (K                    : Short_Float;
      P                    : Short_Float;
      Known_Torque_Pnt_B_B : Packed_F32x3_Record.C.U_C;
      Iscpnt_B_B           : Packed_F32x9_Record.C.U_C)
     return Mrp_Pd_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "MrpPDAlgorithm_create";

   --* @brief Destroy a MrpPDAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Mrp_Pd_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpPDAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self The algorithm instance.
   --* @param K [Nm] Proportional gain on the MRP attitude error.
   --* @param P [Nms] Rate error feedback gain.
   --* @param Known_Torque_Pnt_B_B [Nm] Known external torque in body frame components.
   --* @param Iscpnt_B_B [kg m^2] Spacecraft inertia about point B.
   procedure Set_Config
     (Self                 : Mrp_Pd_Algorithm_Access;
      K                    : Short_Float;
      P                    : Short_Float;
      Known_Torque_Pnt_B_B : Packed_F32x3_Record.C.U_C;
      Iscpnt_B_B           : Packed_F32x9_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpPDAlgorithm_setConfig";

   --* @brief Compute the commanded control torque for the current guidance errors.
   --* @param Self The algorithm instance.
   --* @param Sigma_Br [-] MRP attitude tracking error.
   --* @param Omega_Br_B [rad/s] Angular rate tracking error in body frame components.
   --* @param Domega_Rn_B [rad/s^2] Reference angular acceleration in body frame components.
   --* @return [Nm] Commanded control torque in body frame components.
   function Update
     (Self        : Mrp_Pd_Algorithm_Access;
      Sigma_Br    : Packed_F32x3_Record.C.U_C;
      Omega_Br_B  : Packed_F32x3_Record.C.U_C;
      Domega_Rn_B : Packed_F32x3_Record.C.U_C)
     return Packed_F32x3_Record.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "MrpPDAlgorithm_update";

private

   -- Private representation: opaque null record
   type Mrp_Pd_Algorithm is null record;

end Mrp_Pd_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
