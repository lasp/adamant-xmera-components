pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Mrp_Feedback_Enums;
with Mrp_Feedback_Rw_Availability.C;
with Mrp_Feedback_Rw_Inertias.C;
with Mrp_Feedback_Rw_Spin_Axes.C;
with Packed_F32x3_Record.C;
with Packed_F32x3_X4.C;
with Packed_F32x4.C;
with Packed_F32x9_Record.C;
with Rw_Speeds_Input.C;
with Wheel_Availability_X4.C;

package Momentum_Management_Algorithm_C is

   --* @brief Get the kMaxNumRw constant for validation.
   --* @return The maximum number of reaction wheels handled at the C boundary (RW_EFF_CNT).
   function Get_Max_Num_Rw
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_getMaxNumRw";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side RW_EFF_CNT, checked at elaboration. Each
   -- wrapped array is tied three ways: the count, the purity of the record
   -- wrapping it, and the footprint, which is what catches a wrong element type.
   -- The wheel speed, spin axis, inertia and availability structs of this shim
   -- have the same layout as the mrpFeedback ones, so the records of that
   -- component cross this boundary too.
   -- MomentumManagementWheelSpeeds_c: float wheelSpeeds[RW_EFF_CNT];
   pragma Assert (Unsigned_32 (Packed_F32x4.Length) = Get_Max_Num_Rw);
   pragma Assert (Packed_F32x4.C.U_C'Object_Size = Rw_Speeds_Input.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Rw_Speeds_Input.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   -- MomentumManagementRwSpinAxes_c: float data[3 * RW_EFF_CNT]. Three components
   -- per wheel, so the length and footprint are divided by three before being tied
   -- to the count.
   pragma Assert (Unsigned_32 (Packed_F32x3_X4.Length) = Get_Max_Num_Rw);
   pragma Assert (Mrp_Feedback_Rw_Spin_Axes.C.U_C'Object_Size = Packed_F32x3_X4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Spin_Axes.C.U_C'Object_Size / Short_Float'Object_Size / 3) = Get_Max_Num_Rw);
   -- MomentumManagementRwInertias_c: float data[RW_EFF_CNT];
   pragma Assert (Mrp_Feedback_Rw_Inertias.C.U_C'Object_Size = Packed_F32x4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Inertias.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   -- MomentumManagementRwAvailability_c: DeviceAvailability_c availability[RW_EFF_CNT]. Each element
   -- crosses as the C version of Mrp_Feedback_Enums.Wheel_Availability, the width of a C int.
   pragma Assert (Unsigned_32 (Wheel_Availability_X4.Length) = Get_Max_Num_Rw);
   pragma Assert (Mrp_Feedback_Rw_Availability.C.U_C'Object_Size = Wheel_Availability_X4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Availability.C.U_C'Object_Size / Mrp_Feedback_Enums.Wheel_Availability.C.E_C'Object_Size) = Get_Max_Num_Rw);

   --* Opaque handle for a MomentumManagementAlgorithm instance.
   type Momentum_Management_Algorithm is limited private;
   type Momentum_Management_Algorithm_Access is access all Momentum_Management_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Hs_Min               [Nms]    Minimum momentum difference for dumping; must be finite and >= 0.
   --* @param K                    [1/s]    Proportional gain on the momentum difference; must be finite and >= 0.
   --* @param Ki                   [1/s^2]  Integral gain on the accumulated momentum difference; must be finite
   --*                                      and >= 0.
   --* @param Integral_Limit       [Nms^2]  Anti-windup clamp on each integral component; must be finite and
   --*                                      >= 0, and > 0 when Ki > 0.
   --* @param Control_Period       [s]      Integration step between two updates; must be finite and >= 0, and
   --*                                      > 0 when Ki > 0 (only the integral term uses it).
   --* @param Dumpable_Projection_B [-]     Projector onto the directions the effectors can dump about; must be
   --*                                      a finite, symmetric and idempotent orthogonal projector that leaves
   --*                                      at least one direction dumpable. The identity dumps every direction.
   --* @param Hs_Desired_B         [Nms]    Wheel cluster momentum the dump drives toward; must be finite. Zero
   --*                                      dumps all dumpable momentum.
   --* @param Gs_Matrix_B          [-]      Reaction wheel spin axes, one per wheel slot; each must be finite and
   --*                                      within 1e-3 of unit length.
   --* @param Js_List              [kg m^2] Spin axis inertia of each wheel slot; must be finite.
   --* @param Wheel_Availability   [-]      Availability of each wheel slot, one entry per slot.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Hs_Min                : Short_Float;
      K                     : Short_Float;
      Ki                    : Short_Float;
      Integral_Limit        : Short_Float;
      Control_Period        : Short_Float;
      Dumpable_Projection_B : access constant Packed_F32x9_Record.C.U_C;
      Hs_Desired_B          : access constant Packed_F32x3_Record.C.U_C;
      Gs_Matrix_B           : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Js_List               : access constant Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability    : access constant Mrp_Feedback_Rw_Availability.C.U_C)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_validateConfig";

   --* @brief Construct a new MomentumManagementAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Hs_Min                : Short_Float;
      K                     : Short_Float;
      Ki                    : Short_Float;
      Integral_Limit        : Short_Float;
      Control_Period        : Short_Float;
      Dumpable_Projection_B : access constant Packed_F32x9_Record.C.U_C;
      Hs_Desired_B          : access constant Packed_F32x3_Record.C.U_C;
      Gs_Matrix_B           : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Js_List               : access constant Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability    : access constant Mrp_Feedback_Rw_Availability.C.U_C)
     return Momentum_Management_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_create";

   --* @brief Destroy a MomentumManagementAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Momentum_Management_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The integral state is preserved. The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self                  : Momentum_Management_Algorithm_Access;
      Hs_Min                : Short_Float;
      K                     : Short_Float;
      Ki                    : Short_Float;
      Integral_Limit        : Short_Float;
      Control_Period        : Short_Float;
      Dumpable_Projection_B : access constant Packed_F32x9_Record.C.U_C;
      Hs_Desired_B          : access constant Packed_F32x3_Record.C.U_C;
      Gs_Matrix_B           : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Js_List               : access constant Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability    : access constant Mrp_Feedback_Rw_Availability.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_setConfig";

   --* @brief Zero the integral of the momentum difference. The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Momentum_Management_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_reInitialize";

   --* @brief Assess the wheel cluster momentum and compute the torque that drives it to the
   --* desired momentum. Advances the integral state.
   --* @param Self         The algorithm instance.
   --* @param Wheel_Speeds [rad/s] Current reaction wheel speeds (MomentumManagementWheelSpeeds_c).
   --* @return [Nm] Requested body frame torque.
   function Update
     (Self         : Momentum_Management_Algorithm_Access;
      Wheel_Speeds : access constant Rw_Speeds_Input.C.U_C)
     return Packed_F32x3_Record.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "MomentumManagementAlgorithm_update";

private

   -- Private representation: opaque null record
   type Momentum_Management_Algorithm is null record;

end Momentum_Management_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
