pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Mrp_Feedback_Rw_Availability.C;
with Mrp_Feedback_Rw_Spin_Axes.C;
with Packed_F32x3_Record.C;
with Packed_F32x3_X4.C;
with Packed_F32x4.C;
with Rw_Motor_Torque_Control_Axes.C;
with Rw_Motor_Torque_Output.C;
with Rw_Speeds_Input.C;
with Wheel_Availability_X4.C;

package Rw_Motor_Torque_Algorithm_C is

   --* @brief Get the kMaxNumRw constant for validation.
   --* @return The maximum number of reaction wheels handled at the C boundary (RW_EFF_CNT).
   function Get_Max_Num_Rw
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "RwMotorTorqueAlgorithm_getMaxNumRw";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side RW_EFF_CNT, checked at elaboration. Each
   -- wrapped array is tied three ways: the count, the purity of the record
   -- wrapping it, and the footprint, which is what catches a wrong element type.
   -- The spin axis and availability structs of this shim have the same layout as
   -- the mrpFeedback ones, so the records of that component cross this boundary too.
   -- RwSpeeds_c: float wheelSpeeds[RW_EFF_CNT];
   pragma Assert (Unsigned_32 (Packed_F32x4.Length) = Get_Max_Num_Rw);
   pragma Assert (Packed_F32x4.C.U_C'Object_Size = Rw_Speeds_Input.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Rw_Speeds_Input.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   -- RwMotorTorqueOutput_c: float motorTorque[RW_EFF_CNT];
   pragma Assert (Rw_Motor_Torque_Output.C.U_C'Object_Size = Packed_F32x4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Rw_Motor_Torque_Output.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   -- RwMotorTorqueRwSpinAxes_c: float data[3 * RW_EFF_CNT]. Three components per
   -- wheel, so the length and footprint are divided by three before being tied
   -- to the count.
   pragma Assert (Unsigned_32 (Packed_F32x3_X4.Length) = Get_Max_Num_Rw);
   pragma Assert (Mrp_Feedback_Rw_Spin_Axes.C.U_C'Object_Size = Packed_F32x3_X4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Spin_Axes.C.U_C'Object_Size / Short_Float'Object_Size / 3) = Get_Max_Num_Rw);
   -- RwMotorTorqueRwAvailability_c: one uint8_t per wheel slot. The C
   -- DeviceAvailability_c enum is int-sized, so the shim takes a uint8_t array
   -- instead and converts; this pins the Ada side to that one-byte-per-slot layout.
   pragma Assert (Unsigned_32 (Wheel_Availability_X4.Length) = Get_Max_Num_Rw);
   pragma Assert (Mrp_Feedback_Rw_Availability.C.U_C'Object_Size = Wheel_Availability_X4.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Mrp_Feedback_Rw_Availability.C.U_C'Object_Size / Unsigned_8'Object_Size) = Get_Max_Num_Rw);

   --* Opaque handle for a RwMotorTorqueAlgorithm instance.
   type Rw_Motor_Torque_Algorithm is limited private;
   type Rw_Motor_Torque_Algorithm_Access is access all Rw_Motor_Torque_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Desired_Control_Axes_B [-] Body axes to control; at least one must be selected, and every
   --*                                   selected axis must be reachable by the available wheels with a
   --*                                   well conditioned mapping.
   --* @param Gs_Matrix_B            [-] Reaction wheel spin axes, one per wheel slot; each must be finite
   --*                                   and within 1e-3 of unit length.
   --* @param Wheel_Availability     [-] Availability of each wheel slot, one byte per slot.
   --* @param Omega_Gain             [-] Null space feedback gain on the wheel speed error; must be finite
   --*                                   and >= 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Desired_Control_Axes_B : access constant Rw_Motor_Torque_Control_Axes.C.U_C;
      Gs_Matrix_B            : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Wheel_Availability     : access constant Mrp_Feedback_Rw_Availability.C.U_C;
      Omega_Gain             : Short_Float)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "RwMotorTorqueAlgorithm_validateConfig";

   --* @brief Construct a new RwMotorTorqueAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Desired_Control_Axes_B : access constant Rw_Motor_Torque_Control_Axes.C.U_C;
      Gs_Matrix_B            : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Wheel_Availability     : access constant Mrp_Feedback_Rw_Availability.C.U_C;
      Omega_Gain             : Short_Float)
     return Rw_Motor_Torque_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "RwMotorTorqueAlgorithm_create";

   --* @brief Destroy a RwMotorTorqueAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Rw_Motor_Torque_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "RwMotorTorqueAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input) and recompute
   --* the mapping. The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self                   : Rw_Motor_Torque_Algorithm_Access;
      Desired_Control_Axes_B : access constant Rw_Motor_Torque_Control_Axes.C.U_C;
      Gs_Matrix_B            : access constant Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Wheel_Availability     : access constant Mrp_Feedback_Rw_Availability.C.U_C;
      Omega_Gain             : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "RwMotorTorqueAlgorithm_setConfig";

   --* @brief Compute the per-wheel motor torques for a commanded body torque.
   --* @param Self              The algorithm instance.
   --* @param Lr_B              [Nm]    Commanded control torque on the spacecraft in body frame components.
   --* @param Rw_Speeds         [rad/s] Current reaction wheel speeds (RwSpeeds_c).
   --* @param Rw_Desired_Speeds [rad/s] Desired reaction wheel speeds (RwSpeeds_c).
   --* @return [Nm] Commanded motor torque of each wheel.
   function Update
     (Self              : Rw_Motor_Torque_Algorithm_Access;
      Lr_B              : Packed_F32x3_Record.C.U_C;
      Rw_Speeds         : access constant Rw_Speeds_Input.C.U_C;
      Rw_Desired_Speeds : access constant Rw_Speeds_Input.C.U_C)
     return Rw_Motor_Torque_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "RwMotorTorqueAlgorithm_update";

private

   -- Private representation: opaque null record
   type Rw_Motor_Torque_Algorithm is null record;

end Rw_Motor_Torque_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
