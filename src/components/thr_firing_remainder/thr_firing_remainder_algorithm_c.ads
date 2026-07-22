pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces.C;     use Interfaces; use Interfaces.C;
with Packed_F32x3.C;
with Packed_F32x36.C;
with Thr_Firing_Remainder_Force_Cmd.C;
with Thr_Firing_Remainder_On_Time_Cmd.C;

package Thr_Firing_Remainder_Algorithm_C is

   -- THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT must match the #define in
   -- thrFiringRemainderAlgorithm_c.h:17
   -- Re-run h2ads if the C header changes to regenerate this binding
   THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT : constant := 36;

   --* @brief Get the maximum thruster count constant for validation.
   --* @return The maximum thruster count (THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT).
   function Get_Max_Thruster_Count
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_getMaxThrusterCount";

   --* Thrust pulsing regime selection.
   type Thr_Firing_Remainder_Pulsing_Regime is
     (On_Pulsing,
      Off_Pulsing)
     with Convention => C;

   --* Single thruster configuration (POD).
   type Thr_Firing_Remainder_Thruster_Config is record
      R_Thrust_B     : aliased Packed_F32x3.C.U_C;
      T_Hat_Thrust_B : aliased Packed_F32x3.C.U_C;
      Max_Thrust     : aliased Short_Float;
   end record
   with Convention => C_Pass_By_Copy;

   --* Array of thruster configurations.
   type Thr_Config_Array is
     array (0 .. THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT - 1) of
       aliased Thr_Firing_Remainder_Thruster_Config
     with Convention => C;

   --* Thruster array configuration (POD).
   type Thr_Firing_Remainder_Array_Config is record
      Num_Thrusters : aliased Unsigned_32;
      Thrusters     : aliased Thr_Config_Array;
   end record
   with Convention => C_Pass_By_Copy;

   type Thr_Firing_Remainder_Array_Config_Access is
     access all Thr_Firing_Remainder_Array_Config;

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT,
   -- checked at elaboration.
   -- ThrFiringRemainderArrayConfig: uint32_t numThrusters;
   -- ThrFiringRemainderThrusterConfig thrusters[THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT];
   pragma Assert (Unsigned_32 (Thr_Config_Array'Length) = Get_Max_Thruster_Count);
   pragma Assert (Thr_Firing_Remainder_Array_Config'Object_Size = Unsigned_32'Object_Size + Thr_Config_Array'Object_Size);
   -- ThrFiringRemainderForceCmd: float thrForce[THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT];
   pragma Assert (Unsigned_32 (Packed_F32x36.Length) = Get_Max_Thruster_Count);
   pragma Assert (Packed_F32x36.C.U_C'Object_Size = Thr_Firing_Remainder_Force_Cmd.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thr_Firing_Remainder_Force_Cmd.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Thruster_Count);
   -- ThrFiringRemainderOnTimeCmd: float onTimeRequest[THR_FIRING_REMAINDER_MAX_THRUSTER_COUNT];
   pragma Assert (Packed_F32x36.C.U_C'Object_Size = Thr_Firing_Remainder_On_Time_Cmd.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Thr_Firing_Remainder_On_Time_Cmd.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Thruster_Count);

   --* Opaque handle for a ThrFiringRemainderAlgorithm instance.
   type Thr_Firing_Remainder_Algorithm is limited private;
   type Thr_Firing_Remainder_Algorithm_Access is access all Thr_Firing_Remainder_Algorithm;

   --* @brief Construct a new ThrFiringRemainderAlgorithm.
   function Create
     return Thr_Firing_Remainder_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_create";

   --* @brief Destroy a ThrFiringRemainderAlgorithm.
   procedure Destroy
     (Self : Thr_Firing_Remainder_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_destroy";

   --* @brief Reset the algorithm state.
   --* @param Self Pointer to the instance.
   procedure Reset
     (Self : Thr_Firing_Remainder_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_reset";

   --* @brief Run the update step.
   --* @param Self      Pointer to the instance.
   --* @param Force_Cmd Pointer to thruster force command input.
   --* @return The computed on-time command.
   function Update
     (Self      : Thr_Firing_Remainder_Algorithm_Access;
      Force_Cmd : access constant Thr_Firing_Remainder_Force_Cmd.C.U_C)
     return Thr_Firing_Remainder_On_Time_Cmd.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_update";

   --* @brief Set the thruster array configuration.
   --* @param Self   Pointer to the instance.
   --* @param Config Pointer to thruster array configuration.
   procedure Set_Thrusters
     (Self   : Thr_Firing_Remainder_Algorithm_Access;
      Config : access constant Thr_Firing_Remainder_Array_Config)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_setThrusters";

   --* @brief Set the minimum thruster fire time.
   --* @param Self          Pointer to the instance.
   --* @param Min_Fire_Time Minimum fire time in seconds.
   procedure Set_Thr_Min_Fire_Time
     (Self          : Thr_Firing_Remainder_Algorithm_Access;
      Min_Fire_Time : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_setThrMinFireTime";

   --* @brief Get the minimum thruster fire time.
   --* @param Self Pointer to the instance.
   --* @return Minimum fire time in seconds.
   function Get_Thr_Min_Fire_Time
     (Self : Thr_Firing_Remainder_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_getThrMinFireTime";

   --* @brief Set the thrust pulsing regime.
   --* @param Self           Pointer to the instance.
   --* @param Pulsing_Regime The pulsing regime (on-pulsing or off-pulsing).
   procedure Set_Thrust_Pulsing_Regime
     (Self           : Thr_Firing_Remainder_Algorithm_Access;
      Pulsing_Regime : Thr_Firing_Remainder_Pulsing_Regime)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_setThrustPulsingRegime";

   --* @brief Get the thrust pulsing regime.
   --* @param Self Pointer to the instance.
   --* @return The current pulsing regime.
   function Get_Thrust_Pulsing_Regime
     (Self : Thr_Firing_Remainder_Algorithm_Access)
     return Thr_Firing_Remainder_Pulsing_Regime
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_getThrustPulsingRegime";

   --* @brief Set the control period.
   --* @param Self   Pointer to the instance.
   --* @param Period Control period in seconds.
   procedure Set_Control_Period
     (Self   : Thr_Firing_Remainder_Algorithm_Access;
      Period : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_setControlPeriod";

   --* @brief Get the control period.
   --* @param Self Pointer to the instance.
   --* @return Control period in seconds.
   function Get_Control_Period
     (Self : Thr_Firing_Remainder_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_getControlPeriod";

   --* @brief Set the on-time saturation factor.
   --* @param Self   Pointer to the instance.
   --* @param Factor Saturation factor.
   procedure Set_On_Time_Saturation_Factor
     (Self   : Thr_Firing_Remainder_Algorithm_Access;
      Factor : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_setOnTimeSaturationFactor";

   --* @brief Get the on-time saturation factor.
   --* @param Self Pointer to the instance.
   --* @return The saturation factor.
   function Get_On_Time_Saturation_Factor
     (Self : Thr_Firing_Remainder_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "ThrFiringRemainderAlgorithm_getOnTimeSaturationFactor";

private

   -- Private representation: opaque null record
   type Thr_Firing_Remainder_Algorithm is null record;

end Thr_Firing_Remainder_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
