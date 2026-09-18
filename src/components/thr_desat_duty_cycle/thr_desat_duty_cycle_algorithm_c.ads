pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Packed_F32x8.C;
with Thr_Force_Cmd.C;

package Thr_Desat_Duty_Cycle_Algorithm_C is

   --* @brief Get the maximum thruster count constant for validation.
   --* @return The maximum thruster count (MAX_EFF_CNT).
   function Get_Max_Thruster_Count
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_getMaxThrusterCount";

   -- ABI validation: the constant-dimensioned Ada array crossing the FFI
   -- boundary must match the C-side MAX_EFF_CNT, checked at elaboration.
   -- ThrDesatDutyCycleForceCmd_c: float thrForce[MAX_EFF_CNT];
   pragma Assert (Unsigned_32 (Packed_F32x8.Length) = Get_Max_Thruster_Count);
   pragma Assert (Packed_F32x8.C.U_C'Object_Size = Thr_Force_Cmd.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thr_Force_Cmd.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Thruster_Count);

   --* Opaque handle for a ThrDesatDutyCycleAlgorithm instance.
   type Thr_Desat_Duty_Cycle_Algorithm is limited private;
   type Thr_Desat_Duty_Cycle_Algorithm_Access is access all Thr_Desat_Duty_Cycle_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Firing_Periods   [-] Control periods the gate passes the force command through; must be at least 1.
   --* @param Settling_Periods [-] Control periods the gate holds off; any value whose sum with Firing_Periods
   --*                             still fits in 32 bits.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Firing_Periods   : Unsigned_32;
      Settling_Periods : Unsigned_32)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_validateConfig";

   --* @brief Construct a new ThrDesatDutyCycleAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Firing_Periods   [-] Control periods the gate passes the force command through.
   --* @param Settling_Periods [-] Control periods the gate holds off.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Firing_Periods   : Unsigned_32;
      Settling_Periods : Unsigned_32)
     return Thr_Desat_Duty_Cycle_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_create";

   --* @brief Destroy a ThrDesatDutyCycleAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Thr_Desat_Duty_Cycle_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The cadence counter is preserved.
   --* @param Self             The algorithm instance.
   --* @param Firing_Periods   [-] Control periods the gate passes the force command through.
   --* @param Settling_Periods [-] Control periods the gate holds off.
   procedure Set_Config
     (Self             : Thr_Desat_Duty_Cycle_Algorithm_Access;
      Firing_Periods   : Unsigned_32;
      Settling_Periods : Unsigned_32)
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_setConfig";

   --* @brief Restart the duty cycle at the beginning of its firing window.
   --* The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Thr_Desat_Duty_Cycle_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_reInitialize";

   --* @brief Gate the commanded thruster force through one control period of the duty cycle.
   --* Advances the cadence counter.
   --* @param Self      The algorithm instance.
   --* @param Force_Cmd [N] The commanded per-thruster forces.
   --* @return [N] The commanded force while firing, zero while settling.
   function Update
     (Self      : Thr_Desat_Duty_Cycle_Algorithm_Access;
      Force_Cmd : access constant Thr_Force_Cmd.C.U_C)
     return Thr_Force_Cmd.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "ThrDesatDutyCycleAlgorithm_update";

private

   -- Private representation: opaque null record
   type Thr_Desat_Duty_Cycle_Algorithm is null record;

end Thr_Desat_Duty_Cycle_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
