pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Body_Ephemeris_Payload.C;
with Body_Ephemeris_Payload_X20.C;
with Body_Ephemeris_Payload_X20_Record.C;
with Body_To_Recenter.C;
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

   --* @brief Construct a new EphemeridesRecenterAlgorithm.
   function Create
     return Ephemerides_Recenter_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_create";

   --* @brief Destroy an EphemeridesRecenterAlgorithm.
   procedure Destroy
     (Self : Ephemerides_Recenter_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_destroy";

   --* @brief Validate the configured topology and pre-compute moon hierarchy.
   --* @param Self The algorithm instance.
   procedure Reset
     (Self : Ephemerides_Recenter_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_reset";

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

   --* @brief Set the SPICE ID of the new central body.
   --* @param Self          The algorithm instance.
   --* @param Body_Spice_Id SPICE ID of the new central body.
   procedure Set_New_Zero_Base_Id
     (Self          : Ephemerides_Recenter_Algorithm_Access;
      Body_Spice_Id : Interfaces.Integer_32)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_setNewZeroBaseId";

   --* @brief Get the SPICE ID of the new central body.
   --* @param Self The algorithm instance.
   --* @return SPICE ID of the new central body.
   function Get_New_Zero_Base
     (Self : Ephemerides_Recenter_Algorithm_Access)
     return Interfaces.Integer_32
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_getNewZeroBase";

   --* @brief Set the SPICE ID of the previous common central body.
   --* @param Self          The algorithm instance.
   --* @param Body_Spice_Id SPICE ID of the previous common central body.
   procedure Set_Previous_Common_Zero_Base
     (Self          : Ephemerides_Recenter_Algorithm_Access;
      Body_Spice_Id : Interfaces.Integer_32)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_setPreviousCommonZeroBase";

   --* @brief Get the SPICE ID of the previous common central body.
   --* @param Self The algorithm instance.
   --* @return SPICE ID of the previous common central body.
   function Get_Previous_Common_Zero_Base
     (Self : Ephemerides_Recenter_Algorithm_Access)
     return Interfaces.Integer_32
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_getPreviousCommonZeroBase";

   --* @brief Get the number of bodies that have been added.
   --* @param Self The algorithm instance.
   --* @return The number of configured bodies.
   function Get_Number_Of_Bodies
     (Self : Ephemerides_Recenter_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_getNumberOfBodies";

   --* @brief Get the SPICE IDs of every configured body.
   --* @param Self The algorithm instance.
   --* @return SPICE IDs in insertion order, with trailing entries zero.
   function Get_All_Ids
     (Self : Ephemerides_Recenter_Algorithm_Access)
     return Int32_X20_Record.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_getAllIds";

   --* @brief Add a body to the recenter list.
   --* @param Self The algorithm instance.
   --* @param Body_Item Pointer to a single Body_To_Recenter describing the body.
   procedure Add_Body_Ephemeris_To_Recenter
     (Self      : Ephemerides_Recenter_Algorithm_Access;
      Body_Item : access constant Body_To_Recenter.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_addBodyEphemerisToRecenter";

   --* @brief Remove every body from the recenter list.
   --* @param Self The algorithm instance.
   procedure Clear_All_Bodies
     (Self : Ephemerides_Recenter_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_clearAllBodies";

   --* @brief Look up the index of a body by its SPICE ID.
   --* @param Self          The algorithm instance.
   --* @param Body_Spice_Id SPICE ID to look up.
   --* @return The body's index in the configured list.
   function Find_Body_Index
     (Self          : Ephemerides_Recenter_Algorithm_Access;
      Body_Spice_Id : Interfaces.Integer_32)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "EphemeridesRecenterAlgorithm_findBodyIndex";

private

   -- Private representation: opaque null record
   type Ephemerides_Recenter_Algorithm is null record;

end Ephemerides_Recenter_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
