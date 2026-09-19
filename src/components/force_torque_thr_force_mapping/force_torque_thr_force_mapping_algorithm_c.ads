pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings     (Off, "-gnatwx");

with Desired_Control_Axes.C;
with Interfaces;       use Interfaces;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_F32x8.C;
with Packed_F32x24.C;
with Thr_Force_Cmd.C;
with Thruster_Availability_Array.C;
with Thruster_Availability_X8.C;
with Thruster_Geometry_Array.C;

package Force_Torque_Thr_Force_Mapping_Algorithm_C is

   --* @brief Get the maximum thruster count constant for validation.
   --* @return The maximum thruster count (MAX_EFF_CNT).
   function Get_Max_Thruster_Count
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "ForceTorqueThrForceMappingAlgorithm_getMaxThrusterCount";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side MAX_EFF_CNT, checked at elaboration. Each
   -- wrapped array is tied three ways: the count, the purity of the record
   -- wrapping it, and the footprint, which is what catches a wrong element type.
   -- ThrusterGeometryArray_c: float data[MAX_EFF_CNT * 3]. The geometry carries
   -- three components per thruster, so the length and footprint are divided by
   -- three before being tied to the count.
   pragma Assert (Unsigned_32 (Packed_F32x24.Length / 3) = Get_Max_Thruster_Count);
   pragma Assert (Thruster_Geometry_Array.C.U_C'Object_Size = Packed_F32x24.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thruster_Geometry_Array.C.U_C'Object_Size / Short_Float'Object_Size / 3) =
      Get_Max_Thruster_Count);
   -- Vector3f_c: float data[3]. Fixed shape with no C getter behind it, so the
   -- only check available is that the wrapper is exactly the array.
   pragma Assert (Packed_F32x3_Record.C.U_C'Object_Size = Packed_F32x3.C.U_C'Object_Size);
   -- ThrForceArray_c: float thrForce[MAX_EFF_CNT].
   pragma Assert (Unsigned_32 (Packed_F32x8.Length) = Get_Max_Thruster_Count);
   pragma Assert (Thr_Force_Cmd.C.U_C'Object_Size = Packed_F32x8.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thr_Force_Cmd.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Thruster_Count);
   -- ThrusterAvailabilityArray_c: one uint8_t per thruster slot. The C
   -- DeviceAvailability_c enum is int-sized, so the shim takes a uint8_t array
   -- instead and converts; this pins the Ada side to that one-byte-per-slot layout.
   pragma Assert (Unsigned_32 (Thruster_Availability_X8.Length) = Get_Max_Thruster_Count);
   pragma Assert (Thruster_Availability_Array.C.U_C'Object_Size = Thruster_Availability_X8.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thruster_Availability_Array.C.U_C'Object_Size / Unsigned_8'Object_Size) =
      Get_Max_Thruster_Count);

   --* Opaque handle for a ForceTorqueThrForceMappingAlgorithm instance.
   type Force_Torque_Thr_Force_Mapping_Algorithm is limited private;
   type Force_Torque_Thr_Force_Mapping_Algorithm_Access is access all Force_Torque_Thr_Force_Mapping_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Num_Thrusters         Number of configured thrusters, in [1, MAX_EFF_CNT]. Only the
   --* first Num_Thrusters entries of the geometry take part in the mapping.
   --* @param R_Thruster_B          Thruster locations in the body frame, three components per
   --* thruster in row major order.
   --* @param T_Hat_Thruster_B      Thrust directions in the body frame, three components per
   --* thruster in row major order; each must be a unit vector to within 1e-3.
   --* @param Center_Of_Mass_B      Center of mass in the body frame; must be finite.
   --* @param Desired_Control_Axes_B Per-axis controllability assertions.
   --* @param Thruster_Availability  Per-thruster availability; an unavailable thruster is
   --* left out of the mapping. A minimum of one must be available.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Num_Thrusters          : Unsigned_32;
      R_Thruster_B           : access constant Thruster_Geometry_Array.C.U_C;
      T_Hat_Thruster_B       : access constant Thruster_Geometry_Array.C.U_C;
      Center_Of_Mass_B       : access constant Packed_F32x3_Record.C.U_C;
      Desired_Control_Axes_B : access constant Desired_Control_Axes.C.U_C;
      Thruster_Availability  : access constant Thruster_Availability_Array.C.U_C)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "ForceTorqueThrForceMappingAlgorithm_validateConfig";

   --* @brief Construct a new ForceTorqueThrForceMappingAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Num_Thrusters         Number of configured thrusters, in [1, MAX_EFF_CNT]. Only the
   --* first Num_Thrusters entries of the geometry take part in the mapping.
   --* @param R_Thruster_B          Thruster locations to install.
   --* @param T_Hat_Thruster_B      Thrust directions to install.
   --* @param Center_Of_Mass_B      Center of mass to install.
   --* @param Desired_Control_Axes_B Per-axis controllability assertions.
   --* @param Thruster_Availability  Per-thruster availability; an unavailable thruster is
   --* left out of the mapping. A minimum of one must be available.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Num_Thrusters          : Unsigned_32;
      R_Thruster_B           : access constant Thruster_Geometry_Array.C.U_C;
      T_Hat_Thruster_B       : access constant Thruster_Geometry_Array.C.U_C;
      Center_Of_Mass_B       : access constant Packed_F32x3_Record.C.U_C;
      Desired_Control_Axes_B : access constant Desired_Control_Axes.C.U_C;
      Thruster_Availability  : access constant Thruster_Availability_Array.C.U_C)
     return Force_Torque_Thr_Force_Mapping_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "ForceTorqueThrForceMappingAlgorithm_create";

   --* @brief Destroy a ForceTorqueThrForceMappingAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Force_Torque_Thr_Force_Mapping_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ForceTorqueThrForceMappingAlgorithm_destroy";

   --* @brief Apply a new configuration and recompute the thruster mapping matrix.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Self                  The algorithm instance.
   --* @param Num_Thrusters         Number of configured thrusters, in [1, MAX_EFF_CNT]. Only the
   --* first Num_Thrusters entries of the geometry take part in the mapping.
   --* @param R_Thruster_B          Thruster locations to install.
   --* @param T_Hat_Thruster_B      Thrust directions to install.
   --* @param Center_Of_Mass_B      Center of mass to install.
   --* @param Desired_Control_Axes_B Per-axis controllability assertions.
   --* @param Thruster_Availability  Per-thruster availability; an unavailable thruster is
   --* left out of the mapping. A minimum of one must be available.
   procedure Set_Config
     (Self                   : Force_Torque_Thr_Force_Mapping_Algorithm_Access;
      Num_Thrusters          : Unsigned_32;
      R_Thruster_B           : access constant Thruster_Geometry_Array.C.U_C;
      T_Hat_Thruster_B       : access constant Thruster_Geometry_Array.C.U_C;
      Center_Of_Mass_B       : access constant Packed_F32x3_Record.C.U_C;
      Desired_Control_Axes_B : access constant Desired_Control_Axes.C.U_C;
      Thruster_Availability  : access constant Thruster_Availability_Array.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "ForceTorqueThrForceMappingAlgorithm_setConfig";

   --* @brief Map the requested body torque and force onto per-thruster forces.
   --* Every entry of the result is non-negative; an unavailable thruster receives zero.
   --* @param Self        The algorithm instance.
   --* @param Cmd_Torque_B Requested control torque in the body frame.
   --* @param Cmd_Force_B  Requested control force in the body frame.
   --* @return The per-thruster force commands.
   function Update
     (Self         : Force_Torque_Thr_Force_Mapping_Algorithm_Access;
      Cmd_Torque_B : access constant Packed_F32x3_Record.C.U_C;
      Cmd_Force_B  : access constant Packed_F32x3_Record.C.U_C)
     return Thr_Force_Cmd.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "ForceTorqueThrForceMappingAlgorithm_update";

private

   -- Private representation: opaque null record
   type Force_Torque_Thr_Force_Mapping_Algorithm is null record;

end Force_Torque_Thr_Force_Mapping_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
pragma Warnings     (On, "-gnatwx");
