pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Dv_Maneuver_Enums;
with Dv_Maneuver_Output.C;
with Packed_F32x3_Record.C;

package Dv_Maneuver_Algorithm_C is

   -- ABI validation: the output crossing the FFI boundary is the C enumeration of
   -- the burn state, the width of a C int, followed by three floats, checked at
   -- elaboration.
   pragma Assert (Dv_Maneuver_Output.C.U_C'Object_Size = Dv_Maneuver_Enums.Burn_State.C.E_C'Object_Size + 3 * Short_Float'Object_Size);

   --* Opaque handle for a DvManeuverAlgorithm instance.
   type Dv_Maneuver_Algorithm is limited private;
   type Dv_Maneuver_Algorithm_Access is access all Dv_Maneuver_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Min_Time       [s]   Minimum burn time before completion; finite and not negative.
   --* @param Max_Time       [s]   Maximum burn time; finite, positive, and greater than Min_Time
   --*                             once both are rounded to nanoseconds.
   --* @param Control_Period [s]   Update period; finite and at least 1 ns.
   --* @param Cmd_Force_B    [N]   Body force commanded while the burn executes; finite.
   --* @param Cmd_Dv_N       [m/s] Commanded delta-V in inertial frame components; finite.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Min_Time       : Long_Float;
      Max_Time       : Long_Float;
      Control_Period : Long_Float;
      Cmd_Force_B    : access constant Packed_F32x3_Record.C.U_C;
      Cmd_Dv_N       : access constant Packed_F32x3_Record.C.U_C)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "DvManeuverAlgorithm_validateConfig";

   --* @brief Construct a new DvManeuverAlgorithm from a configuration. Validate the
   --* values with Validate_Config before calling; throws on invalid input. The
   --* parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Min_Time       : Long_Float;
      Max_Time       : Long_Float;
      Control_Period : Long_Float;
      Cmd_Force_B    : access constant Packed_F32x3_Record.C.U_C;
      Cmd_Dv_N       : access constant Packed_F32x3_Record.C.U_C)
     return Dv_Maneuver_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "DvManeuverAlgorithm_create";

   --* @brief Destroy a DvManeuverAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Dv_Maneuver_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "DvManeuverAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The burn
   --* state is kept; Re_Initialize restarts it. The parameters are as for
   --* Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self           : Dv_Maneuver_Algorithm_Access;
      Min_Time       : Long_Float;
      Max_Time       : Long_Float;
      Control_Period : Long_Float;
      Cmd_Force_B    : access constant Packed_F32x3_Record.C.U_C;
      Cmd_Dv_N       : access constant Packed_F32x3_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "DvManeuverAlgorithm_setConfig";

   --* @brief Reset the burn state machine so the burn starts at the next update.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Dv_Maneuver_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "DvManeuverAlgorithm_reInitialize";

   --* @brief Advance the burn one step.
   --* @param Self             The algorithm instance.
   --* @param Dv_Accumulated_B [m/s] Delta-V accumulated in body frame components.
   --* @return The burn state after this step and the body force command.
   function Update
     (Self             : Dv_Maneuver_Algorithm_Access;
      Dv_Accumulated_B : access constant Packed_F32x3_Record.C.U_C)
     return Dv_Maneuver_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "DvManeuverAlgorithm_update";

private

   -- Private representation: opaque null record
   type Dv_Maneuver_Algorithm is null record;

end Dv_Maneuver_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
