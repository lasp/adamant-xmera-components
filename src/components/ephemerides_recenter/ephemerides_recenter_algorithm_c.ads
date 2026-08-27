pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings     (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Body_Ephemeris_Payload.C;
with Body_Ephemeris_Payload_X20.C;
with Body_Ephemeris_Payload_X20_Record.C;
with Int32_X20.C;
with Int32_X20_Record.C;

package Ephemerides_Recenter_Algorithm_C is

   --* @brief Get the MAX_NUM_CHANGE_BODIES constant for validation.
   --* @return The maximum number of change bodies (MAX_NUM_CHANGE_BODIES).
   function Get_Max_Num_Change_Bodies
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_getMaxNumChangeBodies";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side MAX_NUM_CHANGE_BODIES, checked at
   -- elaboration.
   -- BodyEphemerisPayloadArray20_c: BodyEphemerisPayload_c body[MAX_NUM_CHANGE_BODIES];
   pragma Assert (Unsigned_32 (Body_Ephemeris_Payload_X20.Length) = Get_Max_Num_Change_Bodies);
   pragma Assert (Body_Ephemeris_Payload_X20.C.U_C'Object_Size = Body_Ephemeris_Payload_X20_Record.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Body_Ephemeris_Payload_X20_Record.C.U_C'Object_Size / Body_Ephemeris_Payload.C.U_C'Object_Size) = Get_Max_Num_Change_Bodies);
   -- IntArray20_c: int id[MAX_NUM_CHANGE_BODIES];
   pragma Assert (Unsigned_32 (Int32_X20.Length) = Get_Max_Num_Change_Bodies);
   pragma Assert (Int32_X20.C.U_C'Object_Size = Int32_X20_Record.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Int32_X20_Record.C.U_C'Object_Size / Integer_32'Object_Size) = Get_Max_Num_Change_Bodies);

   --* Opaque handle for an EphemeridesRecenterAlgorithm instance.
   type Ephemerides_Recenter_Algorithm is limited private;
   type Ephemerides_Recenter_Algorithm_Access is access all Ephemerides_Recenter_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param New_Central_Body_Id       SPICE ID of the new central body.
   --* @param Previous_Central_Body_Id  SPICE ID of the previous common central body.
   --* @param Body_Ids                  SPICE IDs of every configured body (first Body_Count used).
   --* @param Original_Central_Body_Ids Original central-body SPICE ID for each configured body.
   --* @param Body_Count                Number of configured bodies (<= MAX_NUM_CHANGE_BODIES).
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (New_Central_Body_Id       : Interfaces.Integer_32;
      Previous_Central_Body_Id  : Interfaces.Integer_32;
      Body_Ids                  : access constant Int32_X20_Record.C.U_C;
      Original_Central_Body_Ids : access constant Int32_X20_Record.C.U_C;
      Body_Count                : Unsigned_32)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_validateConfig";

   --* @brief Construct a new EphemeridesRecenterAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid topology.
   --* @param New_Central_Body_Id       SPICE ID of the new central body.
   --* @param Previous_Central_Body_Id  SPICE ID of the previous common central body.
   --* @param Body_Ids                  SPICE IDs of every configured body (first Body_Count used).
   --* @param Original_Central_Body_Ids Original central-body SPICE ID for each configured body.
   --* @param Body_Count                Number of configured bodies (<= MAX_NUM_CHANGE_BODIES).
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (New_Central_Body_Id       : Interfaces.Integer_32;
      Previous_Central_Body_Id  : Interfaces.Integer_32;
      Body_Ids                  : access constant Int32_X20_Record.C.U_C;
      Original_Central_Body_Ids : access constant Int32_X20_Record.C.U_C;
      Body_Count                : Unsigned_32)
     return Ephemerides_Recenter_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_create";

   --* @brief Destroy an EphemeridesRecenterAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Ephemerides_Recenter_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_destroy";

   --* @brief Apply a new configuration and recompute the moon hierarchy
   --* (validated; throws on invalid topology).
   --* @param Self                      The algorithm instance.
   --* @param New_Central_Body_Id       SPICE ID of the new central body.
   --* @param Previous_Central_Body_Id  SPICE ID of the previous common central body.
   --* @param Body_Ids                  SPICE IDs of every configured body (first Body_Count used).
   --* @param Original_Central_Body_Ids Original central-body SPICE ID for each configured body.
   --* @param Body_Count                Number of configured bodies (<= MAX_NUM_CHANGE_BODIES).
   procedure Set_Config
     (Self                      : Ephemerides_Recenter_Algorithm_Access;
      New_Central_Body_Id       : Interfaces.Integer_32;
      Previous_Central_Body_Id  : Interfaces.Integer_32;
      Body_Ids                  : access constant Int32_X20_Record.C.U_C;
      Original_Central_Body_Ids : access constant Int32_X20_Record.C.U_C;
      Body_Count                : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_setConfig";

   --* @brief Run the recentering update.
   --* @param Self       The algorithm instance.
   --* @param New_Bodies Pointer to a single record carrying input r/v for every configured body.
   --* @return Output r/v for each body relative to the new central body.
   function Update_State
     (Self       : Ephemerides_Recenter_Algorithm_Access;
      New_Bodies : access constant Body_Ephemeris_Payload_X20_Record.C.U_C)
     return Body_Ephemeris_Payload_X20_Record.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_updateState";

private

   -- Private representation: opaque null record
   type Ephemerides_Recenter_Algorithm is null record;

end Ephemerides_Recenter_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
pragma Warnings     (On, "-gnatwx");
