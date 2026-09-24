pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C;
with Axis_To_Gimbal_Angles_Output.C;
with Packed_F32x3_Record.C;

package Axis_To_Gimbal_Angles_Algorithm_C is

   --* Opaque handle for an AxisToGimbalAnglesAlgorithm instance.
   type Axis_To_Gimbal_Angles_Algorithm is limited private;
   type Axis_To_Gimbal_Angles_Algorithm_Access is access all Axis_To_Gimbal_Angles_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Sigma_Mb  [-]   MRP of the mount frame M relative to the body frame B; must be finite.
   --* @param Theta_Max [rad] Largest deflection of the thrust axis from the neutral axis; must lie in (0, pi/2).
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Sigma_Mb  : access constant Packed_F32x3_Record.C.U_C;
      Theta_Max : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "AxisToGimbalAnglesAlgorithm_validateConfig";

   --* @brief Construct a new AxisToGimbalAnglesAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Sigma_Mb  [-]   MRP of the mount frame M relative to the body frame B.
   --* @param Theta_Max [rad] Largest deflection of the thrust axis from the neutral axis.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Sigma_Mb  : access constant Packed_F32x3_Record.C.U_C;
      Theta_Max : Short_Float)
     return Axis_To_Gimbal_Angles_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "AxisToGimbalAnglesAlgorithm_create";

   --* @brief Destroy an AxisToGimbalAnglesAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Axis_To_Gimbal_Angles_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "AxisToGimbalAnglesAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self      The algorithm instance.
   --* @param Sigma_Mb  [-]   MRP of the mount frame M relative to the body frame B.
   --* @param Theta_Max [rad] Largest deflection of the thrust axis from the neutral axis.
   procedure Set_Config
     (Self      : Axis_To_Gimbal_Angles_Algorithm_Access;
      Sigma_Mb  : access constant Packed_F32x3_Record.C.U_C;
      Theta_Max : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "AxisToGimbalAnglesAlgorithm_setConfig";

   --* @brief Determine the gimbal angles that align the gimbal thrust axis with the commanded direction.
   --* @param Self         The algorithm instance.
   --* @param Thrust_Hat_B [-] Commanded thrust direction, body frame components.
   --* @return The gimbal angles and the thrust direction they achieve.
   function Update
     (Self         : Axis_To_Gimbal_Angles_Algorithm_Access;
      Thrust_Hat_B : access constant Packed_F32x3_Record.C.U_C)
     return Axis_To_Gimbal_Angles_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "AxisToGimbalAnglesAlgorithm_update";

private

   -- Private representation: opaque null record
   type Axis_To_Gimbal_Angles_Algorithm is null record;

end Axis_To_Gimbal_Angles_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
