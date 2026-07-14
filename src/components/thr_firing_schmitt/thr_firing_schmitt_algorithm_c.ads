pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary for Validate_Config to match the shim's
-- C99 bool (_Bool): 1-byte, 0/1 representation, interoperable under
-- Convention => C. Suppress the -gnatwx advisory about using a C "char"-style
-- type for the mapping.
pragma Warnings     (Off, "-gnatwx");

with Interfaces.C;     use Interfaces; use Interfaces.C;
with Packed_F32x3.C;
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

   ---------------------------------------------------------------------------
   -- Configure_Thrusters input type (Ada-side only)
   --
   -- Retained for symmetry with the sibling thr_firing_remainder component and
   -- to carry the full per-thruster geometry a caller may already hold. Only
   -- Num_Thrusters and Max_Thrust feed the algorithm config; R_Thrust_B and
   -- T_Hat_Thrust_B are unused by the Schmitt algorithm. This record is no
   -- longer passed across the C boundary.
   ---------------------------------------------------------------------------

   --* Single thruster configuration (POD).
   type Thr_Firing_Schmitt_Thruster_Config is record
      R_Thrust_B     : aliased Packed_F32x3.C.U_C;
      T_Hat_Thrust_B : aliased Packed_F32x3.C.U_C;
      Max_Thrust     : aliased Short_Float;
   end record
   with Convention => C_Pass_By_Copy;

   --* Array of thruster configurations.
   type Thr_Config_Array is
     array (0 .. THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT - 1) of
       aliased Thr_Firing_Schmitt_Thruster_Config
     with Convention => C;

   --* Thruster array configuration (POD).
   type Thr_Firing_Schmitt_Array_Config is record
      Num_Thrusters : aliased Unsigned_32;
      Thrusters     : aliased Thr_Config_Array;
   end record
   with Convention => C_Pass_By_Copy;

   type Thr_Firing_Schmitt_Array_Config_Access is
     access all Thr_Firing_Schmitt_Array_Config;

   ---------------------------------------------------------------------------
   -- Config POD types mirroring the C shim (thrFiringSchmittTypes.h)
   ---------------------------------------------------------------------------

   --* Per-thruster maximum thrust array matching ThrFiringSchmittThrusterArray_c.maxThrust.
   type Thr_Firing_Schmitt_Max_Thrust_Array is
     array (0 .. THR_FIRING_SCHMITT_MAX_THRUSTER_COUNT - 1) of aliased Short_Float
     with Convention => C;

   --* POD matching ThrFiringSchmittThrusterArray_c in C.
   --* Layout: uint32_t numThrusters; float maxThrust[MAX];
   type Thr_Firing_Schmitt_Thruster_Array_C is record
      Num_Thrusters : aliased Unsigned_32;                     --* [-] number of thrusters on the vehicle.
      Max_Thrust    : aliased Thr_Firing_Schmitt_Max_Thrust_Array; --* [N] per-thruster maximum thrust.
   end record
   with Convention => C_Pass_By_Copy;

   --* POD matching ThrFiringSchmittControlParameters_c in C.
   --* Layout: float levelOn, levelOff, thrMinFireTime, controlPeriod, onTimeSaturationFactor; enum pulsingRegime;
   type Thr_Firing_Schmitt_Control_Parameters_C is record
      Level_On                  : aliased Short_Float;                       --* [-] ON duty cycle fraction, in (0, 1].
      Level_Off                 : aliased Short_Float;                       --* [-] OFF duty cycle fraction, in [0, 1).
      Thr_Min_Fire_Time         : aliased Short_Float;                       --* [s] minimum commandable fire time.
      Control_Period            : aliased Short_Float;                       --* [s] control period.
      On_Time_Saturation_Factor : aliased Short_Float;                       --* [-] control-period multiplier at saturation.
      Pulsing_Regime            : aliased Thr_Firing_Schmitt_Pulsing_Regime; --* [-] on-pulsing or off-pulsing.
   end record
   with Convention => C_Pass_By_Copy;

   --* POD matching ThrFiringSchmittConfig_c in C.
   --* Layout: ThrFiringSchmittThrusterArray_c thrusterArray; ThrFiringSchmittControlParameters_c controlParameters;
   type Thr_Firing_Schmitt_Config_C is record
      Thruster_Array     : aliased Thr_Firing_Schmitt_Thruster_Array_C;
      Control_Parameters : aliased Thr_Firing_Schmitt_Control_Parameters_C;
   end record
   with Convention => C_Pass_By_Copy;

   --* Named access-to-constant for the config POD passed across the C boundary.
   type Thr_Firing_Schmitt_Config_C_Access is access constant Thr_Firing_Schmitt_Config_C;

   --* Opaque handle for a ThrFiringSchmittAlgorithm instance.
   type Thr_Firing_Schmitt_Algorithm is limited private;
   type Thr_Firing_Schmitt_Algorithm_Access is access all Thr_Firing_Schmitt_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Config The configuration to check.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Config : Thr_Firing_Schmitt_Config_C_Access)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_validateConfig";

   --* @brief Construct a new ThrFiringSchmittAlgorithm from a configuration.
   --* @param Config The configuration to apply (validated; throws on invalid input).
   --* Validate config values with Validate_Config before calling so an invalid config
   --* never reaches this.
   function Create
     (Config : Thr_Firing_Schmitt_Config_C_Access)
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
      Config : Thr_Firing_Schmitt_Config_C_Access)
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
