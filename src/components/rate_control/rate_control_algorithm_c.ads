pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Packed_F32x3_Record.C;
with Packed_F32x9_Record.C;

package Rate_Control_Algorithm_C is

   --* Opaque handle for a RateControlAlgorithm instance.
   type Rate_Control_Algorithm is limited private;
   type Rate_Control_Algorithm_Access is access all Rate_Control_Algorithm;

   --* @brief Construct a new RateControlAlgorithm.
   function Create
     return Rate_Control_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_create";

   --* @brief Destroy a RateControlAlgorithm.
   procedure Destroy
     (Self : Rate_Control_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_destroy";

   --* @brief Compute control torque.
   --* The two reference parameters bind to the C shim's `const Vector3f_c&`
   --* arguments (a C++ reference is a pointer at the SysV-AMD64 ABI level).
   --* The return is by value: the shim hands back a Vector3f_c POD struct,
   --* which matches Adamant's `Packed_F32x3_Record.C.U_C` (`C_Pass_By_Copy`).
   --* @param Self          The algorithm instance.
   --* @param Omega_BR_B    [rad/s] Body-relative angular velocity in body frame.
   --* @param Domega_RN_B   [rad/s^2] Reference frame angular accel in body frame.
   --* @return Command torque about point B [Nm].
   function Update
     (Self        : Rate_Control_Algorithm_Access;
      Omega_BR_B  : access constant Packed_F32x3_Record.C.U_C;
      Domega_RN_B : access constant Packed_F32x3_Record.C.U_C)
     return Packed_F32x3_Record.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_update";

   --* @brief Set spacecraft inertia.
   --* The reference parameter binds to `const Matrix3f_c&` on the C++ side.
   --* The C shim's `Matrix3f_c` lays out 9 floats as a `[3][3]` array, which
   --* is byte-identical to `Packed_F32x9_Record.C.U_C` (9 contiguous floats,
   --* row-major). The algorithm enforces symmetry, so any layout convention
   --* mismatch is moot for valid inertia tensors.
   --* @param Self                The algorithm instance.
   --* @param Spacecraft_Inertia  [kg m^2] 3x3 inertia tensor (row-major).
   procedure Set_Spacecraft_Inertia
     (Self                : Rate_Control_Algorithm_Access;
      Spacecraft_Inertia  : access constant Packed_F32x9_Record.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_setSpacecraftInertia";

   --* @brief Set the derivative gain P.
   --* @param Self  The algorithm instance.
   --* @param P     [N*m*s] Rate error feedback gain.
   procedure Set_Derivative_Gain_P
     (Self : Rate_Control_Algorithm_Access;
      P    : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_setDerivativeGainP";

   --* @brief Get the derivative gain P.
   --* @param Self  The algorithm instance.
   --* @return [N*m*s] The current derivative gain.
   function Get_Derivative_Gain_P
     (Self : Rate_Control_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_getDerivativeGainP";

   --* @brief Set the known external torque about point B.
   --* @param Self                  The algorithm instance.
   --* @param Known_Torque_Pnt_B_B  [N*m] Known external torque in body frame.
   procedure Set_Known_Torque_Pnt_B_B
     (Self                 : Rate_Control_Algorithm_Access;
      Known_Torque_Pnt_B_B : Packed_F32x3_Record.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_setKnownTorquePntB_B";

   --* @brief Get the known external torque about point B.
   --* @param Self  The algorithm instance.
   --* @return [N*m] The known external torque in body frame.
   function Get_Known_Torque_Pnt_B_B
     (Self : Rate_Control_Algorithm_Access)
     return Packed_F32x3_Record.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "RateControlAlgorithm_getKnownTorquePntB_B";

private

   -- Private representation: opaque null record
   type Rate_Control_Algorithm is null record;

end Rate_Control_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
