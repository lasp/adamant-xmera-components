pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Att_Guid.C;
with Mrp_Feedback_Enums;
with Mrp_Feedback_Output.C;
with Mrp_Feedback_Rw_Availability.C;
with Mrp_Feedback_Rw_Inertias.C;
with Mrp_Feedback_Rw_Spin_Axes.C;
with Packed_F32x3_Record.C;
with Packed_F32x3_X4.C;
with Packed_F32x4.C;
with Packed_F32x9_Record.C;
with Rw_Speeds_Input.C;
with Wheel_Availability_X4.C;

package Mrp_Feedback_Algorithm_C is

   --* @brief Get the kMaxNumRw constant for validation.
   --* @return The maximum number of reaction wheels handled at the C boundary (RW_EFF_CNT).
   function Get_Max_Num_Rw
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_getMaxNumRw";

   --* Control law variant. The representation clause pins the literals to the C
   --* ControlLawType_c values so that 'Enum_Val is a genuine validity gate when
   --* converting the parameter value into this type.
   type Mrp_Feedback_Control_Law_Type is
     (Normal,
      Simple_Integral)
     with Convention => C;
   for Mrp_Feedback_Control_Law_Type use
     (Normal          => 0,
      Simple_Integral => 1);

   --* Convert the component's control law parameter value into the C enumeration
   --* above. The conversion lives here, with the C type, because it is boundary
   --* marshalling: the two enumerations exist separately only because the generated
   --* Adamant enumeration cannot carry Convention => C, and so is sized for Ada rather
   --* than for the C int the shim expects. Going through 'Enum_Rep and 'Enum_Val
   --* honors both representation clauses rather than relying on literal position.
   function To_C (Value : in Mrp_Feedback_Enums.Control_Law_Type.E)
      return Mrp_Feedback_Control_Law_Type
   is (Mrp_Feedback_Control_Law_Type'Enum_Val (
         Mrp_Feedback_Enums.Control_Law_Type.E'Enum_Rep (Value)));

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side RW_EFF_CNT, checked at elaboration. Each
   -- wrapped array is tied three ways: the count, the purity of the record
   -- wrapping it, and the footprint, which is what catches a wrong element type.
   -- MrpFeedbackRwSpeeds_c: float wheelSpeeds[RW_EFF_CNT];
   pragma Assert (Unsigned_32 (Packed_F32x4.Length) = Get_Max_Num_Rw);
   pragma Assert (Packed_F32x4.C.U_C'Object_Size = Rw_Speeds_Input.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Rw_Speeds_Input.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   -- MrpFeedbackRwSpinAxes_c: float data[3 * RW_EFF_CNT]. Three components per
   -- wheel, so the length and footprint are divided by three before being tied
   -- to the count.
   pragma Assert (Unsigned_32 (Packed_F32x3_X4.Length) = Get_Max_Num_Rw);
   pragma Assert (Mrp_Feedback_Rw_Spin_Axes.C.U_C'Object_Size = Packed_F32x3_X4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Spin_Axes.C.U_C'Object_Size / Short_Float'Object_Size / 3) = Get_Max_Num_Rw);
   -- MrpFeedbackRwInertias_c: float data[RW_EFF_CNT];
   pragma Assert (Mrp_Feedback_Rw_Inertias.C.U_C'Object_Size = Packed_F32x4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Inertias.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   -- MrpFeedbackRwAvailability_c: one uint8_t per wheel slot. The C
   -- DeviceAvailability_c enum is int-sized, so the shim takes a uint8_t array
   -- instead and converts; this pins the Ada side to that one-byte-per-slot layout.
   pragma Assert (Unsigned_32 (Wheel_Availability_X4.Length) = Get_Max_Num_Rw);
   pragma Assert (Mrp_Feedback_Rw_Availability.C.U_C'Object_Size = Wheel_Availability_X4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Availability.C.U_C'Object_Size / Unsigned_8'Object_Size) = Get_Max_Num_Rw);

   --* Opaque handle for a MrpFeedbackAlgorithm instance.
   type Mrp_Feedback_Algorithm is limited private;
   type Mrp_Feedback_Algorithm_Access is access all Mrp_Feedback_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param K                    [Nm]     Proportional gain on the MRP error; must be finite and >= 0.
   --* @param P                    [Nms]    Rate error feedback gain; must be finite and >= 0.
   --* @param Ki                   [Nm]     Integral feedback gain; must be finite and >= 0 (0 disables the integral).
   --* @param Integral_Limit       [Nms]    Anti-windup clamp on the integral state; must be finite and >= 0.
   --* @param Control_Law_Type     [-]      Control law variant.
   --* @param Control_Period       [s]      Time between two algorithm updates; must be finite and > 0.
   --* @param Known_Torque_Pnt_B_B [Nm]     Known external torque in body frame components; must be finite.
   --* @param Iscpnt_B_B           [kg m^2] Spacecraft inertia about point B; must be a valid inertia matrix.
   --* @param Gs_Matrix_B          [-]      Reaction wheel spin axes, one per wheel slot; each must be finite and
   --*                                      within 1e-3 of unit length. Null omits the reaction wheel momentum
   --*                                      term, and Js_List and Wheel_Availability are then ignored.
   --* @param Js_List              [kg m^2] Spin axis inertia of each wheel slot; must be finite.
   --* @param Wheel_Availability   [-]      Availability of each wheel slot, one byte per slot.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (K                    : Short_Float;
      P                    : Short_Float;
      Ki                   : Short_Float;
      Integral_Limit       : Short_Float;
      Control_Law_Type     : Mrp_Feedback_Control_Law_Type;
      Control_Period       : Short_Float;
      Known_Torque_Pnt_B_B : access constant Packed_F32x3_Record.C.U_C;
      Iscpnt_B_B           : access constant Packed_F32x9_Record.C.U_C;
      Gs_Matrix_B          : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Js_List              : access constant Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability   : access constant Mrp_Feedback_Rw_Availability.C.U_C)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_validateConfig";

   --* @brief Construct a new MrpFeedbackAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (K                    : Short_Float;
      P                    : Short_Float;
      Ki                   : Short_Float;
      Integral_Limit       : Short_Float;
      Control_Law_Type     : Mrp_Feedback_Control_Law_Type;
      Control_Period       : Short_Float;
      Known_Torque_Pnt_B_B : access constant Packed_F32x3_Record.C.U_C;
      Iscpnt_B_B           : access constant Packed_F32x9_Record.C.U_C;
      Gs_Matrix_B          : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Js_List              : access constant Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability   : access constant Mrp_Feedback_Rw_Availability.C.U_C)
     return Mrp_Feedback_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_create";

   --* @brief Destroy a MrpFeedbackAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Mrp_Feedback_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The integral state is preserved. The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self                 : Mrp_Feedback_Algorithm_Access;
      K                    : Short_Float;
      P                    : Short_Float;
      Ki                   : Short_Float;
      Integral_Limit       : Short_Float;
      Control_Law_Type     : Mrp_Feedback_Control_Law_Type;
      Control_Period       : Short_Float;
      Known_Torque_Pnt_B_B : access constant Packed_F32x3_Record.C.U_C;
      Iscpnt_B_B           : access constant Packed_F32x9_Record.C.U_C;
      Gs_Matrix_B          : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Js_List              : access constant Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability   : access constant Mrp_Feedback_Rw_Availability.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_setConfig";

   --* @brief Zero the integral of the MRP attitude error. The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Mrp_Feedback_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_reInitialize";

   --* @brief Compute the commanded control torque and the integral feedback torque.
   --* @param Self           The algorithm instance.
   --* @param Att_Guid_Input Attitude guidance input (sigma_BR, omega_BR_B, omega_RN_B, domega_RN_B).
   --*                       MrpFeedbackInputGuidance_c has the same layout as AttGuidMsgF32Payload,
   --*                       so the guidance record crosses directly.
   --* @param Wheel_Speeds   [rad/s] Current reaction wheel speeds (MrpFeedbackRwSpeeds_c).
   --* @return [Nm] Commanded control torque and integral feedback torque in body frame components.
   function Update
     (Self           : Mrp_Feedback_Algorithm_Access;
      Att_Guid_Input : access constant Att_Guid.C.U_C;
      Wheel_Speeds   : access constant Rw_Speeds_Input.C.U_C)
     return Mrp_Feedback_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "MrpFeedbackAlgorithm_update";

private

   -- Private representation: opaque null record
   type Mrp_Feedback_Algorithm is null record;

end Mrp_Feedback_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
