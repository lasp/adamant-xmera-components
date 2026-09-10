pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings     (Off, "-gnatwx");

with Interfaces;       use Interfaces;
with Packed_F32x36.C;
with Thr_Firing_Remainder_Enums;
with Thr_Firing_Schmitt_Force_Cmd.C;
with Thr_Firing_Schmitt_On_Time_Cmd.C;

package Thr_Firing_Schmitt_Algorithm_C is

   --* @brief Get the maximum thruster count constant for validation.
   --* @return The maximum thruster count (THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT).
   function Get_Max_Thruster_Count
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_getMaxThrusterCount";

   --* Thrust pulsing regime selection. The representation clause pins the
   --* literals to the C ThrFiringSchmittPulsingRegime values so that
   --* 'Enum_Val is a genuine validity gate when converting a raw parameter
   --* value into this type.
   type Thr_Firing_Schmitt_Pulsing_Regime is
     (On_Pulsing,
      Off_Pulsing)
     with Convention => C;
   for Thr_Firing_Schmitt_Pulsing_Regime use
     (On_Pulsing  => 0,
      Off_Pulsing => 1);

   --* Convert the component's pulsing-regime parameter value into the C
   --* enumeration above. The conversion lives here, with the C type, because it is
   --* boundary marshalling: the two enumerations exist separately only because the
   --* generated Adamant enumeration cannot carry Convention => C, and so is sized
   --* for Ada rather than for the C int the shim expects.
   --*
   --* The Adamant enumeration is shared with the thr_firing_remainder component:
   --* both shims declare the same two-valued regime with the same representation,
   --* so a second identical enumeration would only duplicate it.
   --*
   --* Going through 'Enum_Rep and 'Enum_Val honors both representation clauses
   --* rather than relying on literal position. A parameter value whose byte matches
   --* no defined representation is rejected earlier, when the parameter is staged
   --* (the generated validation tests 'Valid on the field), so 'Enum_Val cannot see
   --* an undefined value here and callers need no exception handler.
   function To_C (Value : in Thr_Firing_Remainder_Enums.Pulsing_Regime.E)
      return Thr_Firing_Schmitt_Pulsing_Regime
   is (Thr_Firing_Schmitt_Pulsing_Regime'Enum_Val (
         Thr_Firing_Remainder_Enums.Pulsing_Regime.E'Enum_Rep (Value)));

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT,
   -- checked at elaboration.
   pragma Assert (Unsigned_32 (Packed_F32x36.Length) = Get_Max_Thruster_Count);
   pragma Assert (Packed_F32x36.C.U_C'Object_Size = Thr_Firing_Schmitt_Force_Cmd.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thr_Firing_Schmitt_Force_Cmd.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Thruster_Count);
   pragma Assert (Packed_F32x36.C.U_C'Object_Size = Thr_Firing_Schmitt_On_Time_Cmd.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thr_Firing_Schmitt_On_Time_Cmd.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Thruster_Count);

   --* Opaque handle for a ThrFiringSchmittAlgorithm instance.
   type Thr_Firing_Schmitt_Algorithm is limited private;
   type Thr_Firing_Schmitt_Algorithm_Access is access all Thr_Firing_Schmitt_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Num_Thrusters             Number of thrusters on the vehicle; must not exceed the maximum.
   --* @param Max_Thrust                Per-thruster maximum thrust; each active entry finite and >= 0.
   --* @param Level_On                  ON duty cycle fraction threshold; finite and in (0, 1].
   --* @param Level_Off                 OFF duty cycle fraction threshold; finite, in [0, 1), and <= Level_On.
   --* @param Thr_Min_Fire_Time         Minimum commandable thruster fire time; finite and > 0.
   --* @param Control_Period            Control period the force command applies over; finite and > 0.
   --* @param On_Time_Saturation_Factor Control-period multiplier when on-time saturates; finite and >= 1.
   --* @param Pulsing_Regime            On-pulsing or off-pulsing.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Num_Thrusters             : Unsigned_32;
      Max_Thrust                : access constant Packed_F32x36.C.U_C;
      Level_On                  : Short_Float;
      Level_Off                 : Short_Float;
      Thr_Min_Fire_Time         : Short_Float;
      Control_Period            : Short_Float;
      On_Time_Saturation_Factor : Short_Float;
      Pulsing_Regime            : Thr_Firing_Schmitt_Pulsing_Regime)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_validateConfig";

   --* @brief Construct a new ThrFiringSchmittAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Num_Thrusters             Number of thrusters on the vehicle; must not exceed the maximum.
   --* @param Max_Thrust                Per-thruster maximum thrust; each active entry finite and >= 0.
   --* @param Level_On                  ON duty cycle fraction threshold; finite and in (0, 1].
   --* @param Level_Off                 OFF duty cycle fraction threshold; finite, in [0, 1), and <= Level_On.
   --* @param Thr_Min_Fire_Time         Minimum commandable thruster fire time; finite and > 0.
   --* @param Control_Period            Control period the force command applies over; finite and > 0.
   --* @param On_Time_Saturation_Factor Control-period multiplier when on-time saturates; finite and >= 1.
   --* @param Pulsing_Regime            On-pulsing or off-pulsing.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Num_Thrusters             : Unsigned_32;
      Max_Thrust                : access constant Packed_F32x36.C.U_C;
      Level_On                  : Short_Float;
      Level_Off                 : Short_Float;
      Thr_Min_Fire_Time         : Short_Float;
      Control_Period            : Short_Float;
      On_Time_Saturation_Factor : Short_Float;
      Pulsing_Regime            : Thr_Firing_Schmitt_Pulsing_Regime)
     return Thr_Firing_Schmitt_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_create";

   --* @brief Destroy a ThrFiringSchmittAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The per-thruster Schmitt-trigger ON/OFF history is preserved.
   --* @param Self                      The algorithm instance.
   --* @param Num_Thrusters             Number of thrusters on the vehicle; must not exceed the maximum.
   --* @param Max_Thrust                Per-thruster maximum thrust; each active entry finite and >= 0.
   --* @param Level_On                  ON duty cycle fraction threshold; finite and in (0, 1].
   --* @param Level_Off                 OFF duty cycle fraction threshold; finite, in [0, 1), and <= Level_On.
   --* @param Thr_Min_Fire_Time         Minimum commandable thruster fire time; finite and > 0.
   --* @param Control_Period            Control period the force command applies over; finite and > 0.
   --* @param On_Time_Saturation_Factor Control-period multiplier when on-time saturates; finite and >= 1.
   --* @param Pulsing_Regime            On-pulsing or off-pulsing.
   procedure Set_Config
     (Self                      : Thr_Firing_Schmitt_Algorithm_Access;
      Num_Thrusters             : Unsigned_32;
      Max_Thrust                : access constant Packed_F32x36.C.U_C;
      Level_On                  : Short_Float;
      Level_Off                 : Short_Float;
      Thr_Min_Fire_Time         : Short_Float;
      Control_Period            : Short_Float;
      On_Time_Saturation_Factor : Short_Float;
      Pulsing_Regime            : Thr_Firing_Schmitt_Pulsing_Regime)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setConfig";

   --* @brief Clear the per-thruster ON/OFF history, setting every thruster to OFF.
   --* The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_reInitialize";

   --* @brief Run the update step.
   --* @param Self      The algorithm instance.
   --* @param Force_Cmd Pointer to thruster force command input.
   --* @return The computed on-time command.
   function Update
     (Self      : Thr_Firing_Schmitt_Algorithm_Access;
      Force_Cmd : access constant Thr_Firing_Schmitt_Force_Cmd.C.U_C)
     return Thr_Firing_Schmitt_On_Time_Cmd.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_update";

private

   -- Private representation: opaque null record
   type Thr_Firing_Schmitt_Algorithm is null record;

end Thr_Firing_Schmitt_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
pragma Warnings     (On, "-gnatwx");
