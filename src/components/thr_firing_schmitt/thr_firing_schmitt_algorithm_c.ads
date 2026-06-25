pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

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

   --* Opaque handle for a ThrFiringSchmittAlgorithm instance.
   type Thr_Firing_Schmitt_Algorithm is limited private;
   type Thr_Firing_Schmitt_Algorithm_Access is access all Thr_Firing_Schmitt_Algorithm;

   --* @brief Construct a new ThrFiringSchmittAlgorithm.
   function Create
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

   --* @brief Reset the algorithm state (clears previous-state thruster history).
   --* @param Self Pointer to the instance.
   procedure Reset
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_reset";

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

   --* @brief Configure the thruster array (number of thrusters and per-thruster max thrust).
   --* @param Self   Pointer to the instance.
   --* @param Config Pointer to thruster array configuration.
   procedure Set_Thrusters
     (Self   : Thr_Firing_Schmitt_Algorithm_Access;
      Config : access constant Thr_Firing_Schmitt_Array_Config)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setupThrusters";

   --* @brief Set the ON and OFF duty cycle fractions.
   --* @param Self      Pointer to the instance.
   --* @param Level_On  ON duty cycle fraction in (0.0, 1.0].
   --* @param Level_Off OFF duty cycle fraction in [0.0, 1.0); must not exceed Level_On.
   procedure Set_Levels_On_Off
     (Self      : Thr_Firing_Schmitt_Algorithm_Access;
      Level_On  : Short_Float;
      Level_Off : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setLevelsOnOff";

   --* @brief Set the minimum thruster fire time.
   --* @param Self          Pointer to the instance.
   --* @param Min_Fire_Time Minimum fire time in seconds.
   procedure Set_Thr_Min_Fire_Time
     (Self          : Thr_Firing_Schmitt_Algorithm_Access;
      Min_Fire_Time : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setThrMinFireTime";

   --* @brief Get the minimum thruster fire time.
   --* @param Self Pointer to the instance.
   --* @return Minimum fire time in seconds.
   function Get_Thr_Min_Fire_Time
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_getThrMinFireTime";

   --* @brief Set the thrust pulsing regime.
   --* @param Self           Pointer to the instance.
   --* @param Pulsing_Regime The pulsing regime (on-pulsing or off-pulsing).
   procedure Set_Thrust_Pulsing_Regime
     (Self           : Thr_Firing_Schmitt_Algorithm_Access;
      Pulsing_Regime : Thr_Firing_Schmitt_Pulsing_Regime)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setThrustPulsingRegime";

   --* @brief Get the thrust pulsing regime.
   --* @param Self Pointer to the instance.
   --* @return The current pulsing regime.
   function Get_Thrust_Pulsing_Regime
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     return Thr_Firing_Schmitt_Pulsing_Regime
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_getThrustPulsingRegime";

   --* @brief Set the control period.
   --* @param Self   Pointer to the instance.
   --* @param Period Control period in seconds.
   procedure Set_Control_Period
     (Self   : Thr_Firing_Schmitt_Algorithm_Access;
      Period : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setControlPeriod";

   --* @brief Get the control period.
   --* @param Self Pointer to the instance.
   --* @return Control period in seconds.
   function Get_Control_Period
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_getControlPeriod";

   --* @brief Set the on-time saturation factor.
   --* @param Self   Pointer to the instance.
   --* @param Factor Saturation factor.
   procedure Set_On_Time_Saturation_Factor
     (Self   : Thr_Firing_Schmitt_Algorithm_Access;
      Factor : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_setOnTimeSaturationFactor";

   --* @brief Get the on-time saturation factor.
   --* @param Self Pointer to the instance.
   --* @return The saturation factor.
   function Get_On_Time_Saturation_Factor
     (Self : Thr_Firing_Schmitt_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringSchmittAlgorithm_getOnTimeSaturationFactor";

private

   -- Private representation: opaque null record
   type Thr_Firing_Schmitt_Algorithm is null record;

end Thr_Firing_Schmitt_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
