pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary for Validate_Config to match the shim's
-- C99 bool (_Bool): 1-byte, 0/1 representation, interoperable under
-- Convention => C. Suppress the -gnatwx advisory about using a C "char"-style
-- type for the mapping.
pragma Warnings     (Off, "-gnatwx");

with Interfaces.C;     use Interfaces; use Interfaces.C;
with Thr_Firing_Schmitt_Force_Cmd.C;
with Thr_Firing_Schmitt_On_Time_Cmd.C;

package Thr_Firing_Schmitt_Algorithm_C is

   -- THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT must match the #define in
   -- thrFiringSchmittAlgorithm_c.h:12
   -- Re-run h2ads if the C header changes to regenerate this binding
   THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT : constant := 36;

   --* @brief Get the maximum thruster count constant for validation.
   --* @return The maximum thruster count (THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT).
   function Get_Max_Thruster_Count
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_getMaxThrusterCount";

   -- Runtime validation: ensure Ada constant matches C definition
   pragma Assert (Unsigned_32 (THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT) = Get_Max_Thruster_Count);

   --* Thrust pulsing regime selection.
   type Thr_Firing_Schmitt_Pulsing_Regime is
     (On_Pulsing,
      Off_Pulsing)
     with Convention => C;
   --* Underlying codes match the C enum ThrFiringSchmittPulsingRegime, so the
   --* byte->enum mapping is a representation conversion ('Enum_Val), not a case.
   for Thr_Firing_Schmitt_Pulsing_Regime use (On_Pulsing => 0, Off_Pulsing => 1);

   ---------------------------------------------------------------------------
   -- Config POD types mirroring the C shim (thrFiringSchmittTypes.h)
   ---------------------------------------------------------------------------

   --* Per-thruster maximum thrust array matching ThrFiringSchmittThrusterArray_c.maxThrust.
   type Thr_Firing_Schmitt_Max_Thrust_Array is
     array (0 .. THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT - 1) of aliased Short_Float
     with Convention => C;

   --* Named access-to-constant for the config POD passed across the C boundary.
   --  type Thr_Firing_Schmitt_Config_C_Access is access constant Thr_Firing_Schmitt_Config_C;

   --* Opaque handle for a ThrFiringSchmittAlgorithm instance.
   type Thr_Firing_Schmitt_Algorithm is limited private;
   type Thr_Firing_Schmitt_Algorithm_Access is access all Thr_Firing_Schmitt_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Config The configuration to check.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Num_Thrusters             : Unsigned_32;
      Max_Thrust                : Thr_Firing_Schmitt_Max_Thrust_Array;
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
   --* @param Config The configuration to apply (validated; throws on invalid input).
   --* Validate config values with Validate_Config before calling so an invalid config
   --* never reaches this.
   function Create
     (Num_Thrusters             : Unsigned_32;
      Max_Thrust                : Thr_Firing_Schmitt_Max_Thrust_Array;
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
   procedure Destroy
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param Config The configuration to apply.
   --* The Schmitt-trigger state is preserved.
   procedure Set_Config
     (Self   : Thr_Firing_Schmitt_Algorithm_Access;
      Num_Thrusters             : Unsigned_32;
      Max_Thrust                : Thr_Firing_Schmitt_Max_Thrust_Array;
      Level_On                  : Short_Float;
      Level_Off                 : Short_Float;
      Thr_Min_Fire_Time         : Short_Float;
      Control_Period            : Short_Float;
      On_Time_Saturation_Factor : Short_Float;
      Pulsing_Regime            : Thr_Firing_Schmitt_Pulsing_Regime)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setConfig";

   --* @brief Clear the algorithm's per-thruster ON/OFF history (sets all to OFF).
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_reInitialize";

   --* @brief Run the update step.
   --* @param Self      Pointer to the instance.
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
