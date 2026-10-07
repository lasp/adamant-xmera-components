pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Cmd_Torque_Body.C;
with Interfaces; use Interfaces;
with Interfaces.C;
with Packed_F32x3.C;

package Vector_Duty_Cycle_Algorithm_C is

   -- ABI validation: the vector crosses the FFI boundary as the commanded torque
   -- record, which must be exactly the shim's Vector3f_c, float data[3]. The shape is
   -- fixed with no C getter behind it, so the only check available is the footprint.
   pragma Assert (Cmd_Torque_Body.C.U_C'Object_Size = Packed_F32x3.C.U_C'Object_Size);

   --* Opaque handle for a VectorDutyCycleAlgorithm instance.
   type Vector_Duty_Cycle_Algorithm is limited private;
   type Vector_Duty_Cycle_Algorithm_Access is access all Vector_Duty_Cycle_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param On_Periods  [-] Control periods in which the output equals the input; must be at least 1.
   --* @param Off_Periods [-] Control periods in which the output is zero; any value whose sum with
   --*                        On_Periods still fits in 32 bits.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (On_Periods  : Unsigned_32;
      Off_Periods : Unsigned_32)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "VectorDutyCycleAlgorithm_validateConfig";

   --* @brief Construct a new VectorDutyCycleAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param On_Periods  [-] Control periods in which the output equals the input.
   --* @param Off_Periods [-] Control periods in which the output is zero.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (On_Periods  : Unsigned_32;
      Off_Periods : Unsigned_32)
     return Vector_Duty_Cycle_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "VectorDutyCycleAlgorithm_create";

   --* @brief Destroy a VectorDutyCycleAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Vector_Duty_Cycle_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "VectorDutyCycleAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The position in the cycle is preserved.
   --* @param Self        The algorithm instance.
   --* @param On_Periods  [-] Control periods in which the output equals the input.
   --* @param Off_Periods [-] Control periods in which the output is zero.
   procedure Set_Config
     (Self        : Vector_Duty_Cycle_Algorithm_Access;
      On_Periods  : Unsigned_32;
      Off_Periods : Unsigned_32)
     with Import        => True,
          Convention    => C,
          External_Name => "VectorDutyCycleAlgorithm_setConfig";

   --* @brief Restart the duty cycle at the beginning of its on window.
   --* The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Vector_Duty_Cycle_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "VectorDutyCycleAlgorithm_reInitialize";

   --* @brief Apply one control period of the duty cycle to the input vector.
   --* Advances the position in the cycle.
   --* @param Self         The algorithm instance.
   --* @param Input_Vector [Nm] The commanded torque.
   --* @return [Nm] The input vector in an on period, zero in an off period.
   function Update
     (Self         : Vector_Duty_Cycle_Algorithm_Access;
      Input_Vector : access constant Cmd_Torque_Body.C.U_C)
     return Cmd_Torque_Body.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "VectorDutyCycleAlgorithm_update";

private

   -- Private representation: opaque null record
   type Vector_Duty_Cycle_Algorithm is null record;

end Vector_Duty_Cycle_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
