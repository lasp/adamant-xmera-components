pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Interfaces.C;
with Rw_Speed_Sample.C;
with Rwa_Speeds.C;

package Average_Rw_Speed_Data_Algorithm_C is

   --* Opaque handle for an AverageRwSpeedDataAlgorithm instance.
   type Average_Rw_Speed_Data_Algorithm is limited private;
   type Average_Rw_Speed_Data_Algorithm_Access is access all Average_Rw_Speed_Data_Algorithm;

   --* @brief Get the RW_EFF_CNT constant for Ada validation.
   --* @return The maximum number of reaction wheels.
   function Get_Max_Num_Rw
     return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_getMaxNumRw";

   -- ABI validation: the wheel speeds cross the FFI boundary as the reaction wheel
   -- assembly speeds record, which must be exactly the shim's float wheelSpeeds[RW_EFF_CNT],
   -- both on its own as AverageRwSpeeds_c and behind the measurement time in
   -- RwSpeedSample_c. Checked at elaboration.
   pragma Assert (Unsigned_32 (Rwa_Speeds.C.U_C'Object_Size / Short_Float'Object_Size) = Get_Max_Num_Rw);
   pragma Assert (Rw_Speed_Sample.C.U_C'Object_Size = Unsigned_64'Object_Size + Rwa_Speeds.C.U_C'Object_Size);

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Rw_Speed_Averaging_Window [s] Reaction wheel speed averaging window; must be
   --*                                  greater than zero and at most the algorithm's maximum.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Rw_Speed_Averaging_Window : Short_Float)
     return Interfaces.C.C_bool
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_validateConfig";

   --* @brief Construct a new AverageRwSpeedDataAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Rw_Speed_Averaging_Window [s] Reaction wheel speed averaging window.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Rw_Speed_Averaging_Window : Short_Float)
     return Average_Rw_Speed_Data_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_create";

   --* @brief Destroy an AverageRwSpeedDataAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Average_Rw_Speed_Data_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* The stored samples are kept.
   --* @param Self                      The algorithm instance.
   --* @param Rw_Speed_Averaging_Window [s] Reaction wheel speed averaging window.
   procedure Set_Config
     (Self                      : Average_Rw_Speed_Data_Algorithm_Access;
      Rw_Speed_Averaging_Window : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_setConfig";

   --* @brief Clear the stored samples.
   --* The configuration is left untouched.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Average_Rw_Speed_Data_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_reInitialize";

   --* @brief Ingest one sample and return the mean of the samples in the window.
   --* A sample with a measurement time of zero is not ingested.
   --* @param Self   The algorithm instance.
   --* @param Sample The reaction wheel speed sample.
   --* @return [rad/s] The averaged wheel speeds; zero when no sample is in the window.
   function Update
     (Self   : Average_Rw_Speed_Data_Algorithm_Access;
      Sample : access constant Rw_Speed_Sample.C.U_C)
     return Rwa_Speeds.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "AverageRwSpeedDataAlgorithm_update";

private

   -- Private representation: opaque null record
   type Average_Rw_Speed_Data_Algorithm is null record;

end Average_Rw_Speed_Data_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
