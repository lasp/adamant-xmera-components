pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Cheby_Polynomials.C;
with Css_Sensor_Values.C;
with Packed_F64x8.C;
with Packed_F64x11.C;

package Css_Comm_Algorithm_C is

   --* Opaque handle for a CssCommAlgorithm instance.
   type Css_Comm_Algorithm is limited private;
   type Css_Comm_Algorithm_Access is access all Css_Comm_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Num_Sensors       Number of active CSS sensors, in [1, MAX_NUM_CSS_SENSORS].
   --* @param Max_Sensor_Values Per-sensor scale factors (each active entry finite and > 0).
   --* @param Polynomials       Chebyshev polynomial coefficients.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Num_Sensors       : Unsigned_32;
      Max_Sensor_Values : access constant Packed_F64x8.C.U_C;
      Polynomials       : access constant Cheby_Polynomials.C.U_C)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_validateConfig";

   --* @brief Construct a new CssCommAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Num_Sensors       Number of active CSS sensors, in [1, MAX_NUM_CSS_SENSORS].
   --* @param Max_Sensor_Values Per-sensor scale factors (each active entry finite and > 0).
   --* @param Polynomials       Chebyshev polynomial coefficients.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Num_Sensors       : Unsigned_32;
      Max_Sensor_Values : access constant Packed_F64x8.C.U_C;
      Polynomials       : access constant Cheby_Polynomials.C.U_C)
     return Css_Comm_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_create";

   --* @brief Destroy a CssCommAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Css_Comm_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self              The algorithm instance.
   --* @param Num_Sensors       Number of active CSS sensors, in [1, MAX_NUM_CSS_SENSORS].
   --* @param Max_Sensor_Values Per-sensor scale factors (each active entry finite and > 0).
   --* @param Polynomials       Chebyshev polynomial coefficients.
   procedure Set_Config
     (Self              : Css_Comm_Algorithm_Access;
      Num_Sensors       : Unsigned_32;
      Max_Sensor_Values : access constant Packed_F64x8.C.U_C;
      Polynomials       : access constant Cheby_Polynomials.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_setConfig";

   --* @brief Run the CSS communication correction update.
   --* @param Self         The algorithm instance.
   --* @param Input_Values Pointer to the input CSS sensor values.
   --* @return The corrected CSS sensor values.
   function Update
     (Self         : Css_Comm_Algorithm_Access;
      Input_Values : access constant Css_Sensor_Values.C.U_C)
     return Css_Sensor_Values.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_update";

   --* @brief Get the MAX_NUM_CSS_SENSORS constant for Ada validation.
   --* @return The C-side MAX_NUM_CSS_SENSORS sensor-array bound.
   function Get_Max_Num_Css_Sensors
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxNumCssSensors";

   --* @brief Get the MAX_NUM_CHEBY_POLYS constant for Ada validation.
   --* @return The C-side MAX_NUM_CHEBY_POLYS coefficient-array bound.
   function Get_Max_Num_Cheby_Polys
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxNumChebyPolys";

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side sizing constants, checked at elaboration.
   -- CssSensorValues_c: double data[MAX_NUM_CSS_SENSORS];
   pragma Assert (Unsigned_32 (Packed_F64x8.Length) = Get_Max_Num_Css_Sensors);
   pragma Assert (Packed_F64x8.C.U_C'Object_Size = Css_Sensor_Values.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Css_Sensor_Values.C.U_C'Object_Size / Long_Float'Object_Size) = Get_Max_Num_Css_Sensors);
   -- ChebyPolynomials_c: double data[MAX_NUM_CHEBY_POLYS];
   pragma Assert (Unsigned_32 (Packed_F64x11.Length) = Get_Max_Num_Cheby_Polys);
   pragma Assert (Packed_F64x11.C.U_C'Object_Size = Cheby_Polynomials.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Cheby_Polynomials.C.U_C'Object_Size / Long_Float'Object_Size) = Get_Max_Num_Cheby_Polys);

private

   -- Private representation: opaque null record
   type Css_Comm_Algorithm is null record;

end Css_Comm_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
