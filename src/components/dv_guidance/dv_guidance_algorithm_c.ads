pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Att_Ref.C;
with Packed_F32x3_Record.C;

package Dv_Guidance_Algorithm_C is

   -- ABI validation: the reference payload crossing the FFI boundary is the
   -- AttRefMsgF32Payload of the C side, three vectors of three floats, checked at
   -- elaboration.
   pragma Assert (Att_Ref.C.U_C'Object_Size = 3 * 3 * Short_Float'Object_Size);

   --* Opaque handle for a DvGuidanceAlgorithm instance.
   type Dv_Guidance_Algorithm is limited private;
   type Dv_Guidance_Algorithm_Access is access all Dv_Guidance_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Cmd_Dv_N     [m/s] Commanded delta-V, inertial frame; finite and at least 1e-6 long.
   --* @param R_Hat_Pref_N [-]   Preferred direction of the burn frame's second axis, inertial
   --*                           frame; finite, within 1e-3 of unit length, and not parallel to the
   --*                           commanded delta-V.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Cmd_Dv_N     : Packed_F32x3_Record.C.U_C;
      R_Hat_Pref_N : Packed_F32x3_Record.C.U_C)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "DvGuidanceAlgorithm_validateConfig";

   --* @brief Construct a new DvGuidanceAlgorithm from a configuration. Validate the
   --* values with Validate_Config before calling; throws on invalid input. The
   --* parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Cmd_Dv_N     : Packed_F32x3_Record.C.U_C;
      R_Hat_Pref_N : Packed_F32x3_Record.C.U_C)
     return Dv_Guidance_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "DvGuidanceAlgorithm_create";

   --* @brief Destroy a DvGuidanceAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Dv_Guidance_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "DvGuidanceAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The
   --* parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self         : Dv_Guidance_Algorithm_Access;
      Cmd_Dv_N     : Packed_F32x3_Record.C.U_C;
      R_Hat_Pref_N : Packed_F32x3_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "DvGuidanceAlgorithm_setConfig";

   --* @brief Compute the inertially fixed attitude reference for the burn.
   --* @param Self The algorithm instance.
   --* @return The reference attitude as the MRP from the inertial frame to the burn
   --* frame, with the reference rate and acceleration zero.
   function Update
     (Self : Dv_Guidance_Algorithm_Access)
     return Att_Ref.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "DvGuidanceAlgorithm_update";

private

   -- Private representation: opaque null record
   type Dv_Guidance_Algorithm is null record;

end Dv_Guidance_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
