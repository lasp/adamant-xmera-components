pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary for Validate_Config to match the shim's
-- C99 bool (_Bool): 1-byte, 0/1 representation, interoperable under
-- Convention => C. Suppress the -gnatwx advisory about the char-style mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Css_Sensor_Values.C;

package Css_Comm_Algorithm_C is

   -- MAX_NUM_CSS_SENSORS must match the #define in definitions.h
   MAX_NUM_CSS_SENSORS : constant := 32;

   -- MAX_NUM_CHEBY_POLYS must match the #define in cssCommTypes.h
   MAX_NUM_CHEBY_POLYS : constant := 11;

   --* @brief Get the MAX_NUM_CSS_SENSORS constant for Ada validation.
   function Get_Max_Num_Css_Sensors
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxNumCssSensors";

   --* @brief Get the MAX_NUM_CHEBY_POLYS constant for Ada validation.
   function Get_Max_Num_Cheby_Polys
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxNumChebyPolys";

   -- Runtime validation: ensure Ada constants match C definitions
   pragma Assert (Unsigned_32 (MAX_NUM_CSS_SENSORS) = Get_Max_Num_Css_Sensors);
   pragma Assert (Unsigned_32 (MAX_NUM_CHEBY_POLYS) = Get_Max_Num_Cheby_Polys);

   ---------------------------------------------------------------------------
   -- Config POD types mirroring the C shim (cssCommTypes.h)
   ---------------------------------------------------------------------------

   --* Per-sensor maximum values matching CssCommConfig_c.maxSensorValues.
   type Css_Max_Sensor_Values_C is array (0 .. MAX_NUM_CSS_SENSORS - 1) of aliased Long_Float
      with Convention => C;

   --* Chebyshev polynomial coefficients matching CssCommConfig_c.chebyPolynomials.
   type Css_Cheby_Polynomials_C is array (0 .. MAX_NUM_CHEBY_POLYS - 1) of aliased Long_Float
      with Convention => C;

   --* POD config mirroring CssCommConfig_c in C.
   --* Layout: uint32_t numSensors; double maxSensorValues[MAX_NUM_CSS_SENSORS];
   --*         double chebyPolynomials[MAX_NUM_CHEBY_POLYS];
   type Css_Comm_Config_C is record
      Num_Sensors       : aliased Unsigned_32;
      Max_Sensor_Values : aliased Css_Max_Sensor_Values_C;
      Cheby_Polynomials : aliased Css_Cheby_Polynomials_C;
   end record
      with Convention => C_Pass_By_Copy;

   --* Named access-to-constant for the config POD passed across the C boundary.
   type Css_Comm_Config_C_Access is access constant Css_Comm_Config_C;

   --* Opaque handle for a CssCommAlgorithm instance.
   type Css_Comm_Algorithm is limited private;
   type Css_Comm_Algorithm_Access is access all Css_Comm_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Config The configuration to check.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Config : Css_Comm_Config_C_Access)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_validateConfig";

   --* @brief Construct a new CssCommAlgorithm from a configuration.
   --* @param Config The configuration to apply (validated; throws on invalid input).
   function Create
     (Config : Css_Comm_Config_C_Access)
     return Css_Comm_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_create";

   --* @brief Destroy a CssCommAlgorithm.
   procedure Destroy
     (Self : Css_Comm_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param Config The configuration to apply.
   procedure Set_Config
     (Self   : Css_Comm_Algorithm_Access;
      Config : Css_Comm_Config_C_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_setConfig";

   --* @brief Run the CSS communication correction update.
   --* @param Self         The algorithm instance.
   --* @param Input_Values Pointer to the input CSS sensor values.
   --* @return The corrected CSS sensor values.
   function Update
     (Self         : Css_Comm_Algorithm_Access;
      Input_Values : Css_Sensor_Values.C.U_C_Access)
     return Css_Sensor_Values.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_update";

private

   -- Private representation: opaque null record
   type Css_Comm_Algorithm is null record;

end Css_Comm_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
