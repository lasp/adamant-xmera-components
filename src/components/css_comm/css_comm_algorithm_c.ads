pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Css_Sensor_Values.C;
with Cheby_Polynomials.C;

package Css_Comm_Algorithm_C is

   -- MAX_NUM_CSS_SENSORS must match the #define in definitions.h
   MAX_NUM_CSS_SENSORS : constant := 16;

   -- MAX_NUM_CHEBY_POLYS must match the #define in cssCommTypes.h
   MAX_NUM_CHEBY_POLYS : constant := 11;

   --* Opaque handle for a CssCommAlgorithm instance.
   type Css_Comm_Algorithm is limited private;
   type Css_Comm_Algorithm_Access is access all Css_Comm_Algorithm;

   --* @brief Construct a new CssCommAlgorithm.
   function Create
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

   --* @brief Set the number of CSS sensors.
   --* @param Self              The algorithm instance.
   --* @param Number_Of_Sensors The number of CSS sensors to process.
   procedure Set_Num_Sensors
     (Self              : Css_Comm_Algorithm_Access;
      Number_Of_Sensors : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_setNumSensors";

   --* @brief Get the number of CSS sensors.
   --* @param Self The algorithm instance.
   --* @return The number of CSS sensors.
   function Get_Num_Sensors
     (Self : Css_Comm_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getNumSensors";

   --* @brief Set the maximum sensor value (scale factor).
   --* @param Self      The algorithm instance.
   --* @param Max_Value The maximum sensor value.
   procedure Set_Max_Sensor_Value
     (Self      : Css_Comm_Algorithm_Access;
      Max_Value : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_setMaxSensorValue";

   --* @brief Get the maximum sensor value (scale factor).
   --* @param Self The algorithm instance.
   --* @return The maximum sensor value.
   function Get_Max_Sensor_Value
     (Self : Css_Comm_Algorithm_Access)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxSensorValue";

   --* @brief Set the Chebyshev polynomial count.
   --* @param Self  The algorithm instance.
   --* @param Count The number of Chebyshev polynomials.
   procedure Set_Cheby_Count
     (Self  : Css_Comm_Algorithm_Access;
      Count : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_setChebyCount";

   --* @brief Get the Chebyshev polynomial count.
   --* @param Self The algorithm instance.
   --* @return The number of Chebyshev polynomials.
   function Get_Cheby_Count
     (Self : Css_Comm_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getChebyCount";

   --* @brief Set the Chebyshev polynomial coefficients.
   --* @param Self        The algorithm instance.
   --* @param Polynomials Pointer to the polynomial coefficients.
   procedure Set_Cheby_Polynomials
     (Self        : Css_Comm_Algorithm_Access;
      Polynomials : Cheby_Polynomials.C.U_C_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_setChebyPolynomials";

   --* @brief Get the Chebyshev polynomial coefficients.
   --* @param Self The algorithm instance.
   --* @return The polynomial coefficients.
   function Get_Cheby_Polynomials
     (Self : Css_Comm_Algorithm_Access)
     return Cheby_Polynomials.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getChebyPolynomials";

   --* @brief Get the MAX_NUM_CSS_SENSORS constant for Ada validation.
   --* @return The value of MAX_NUM_CSS_SENSORS.
   function Get_Max_Num_Css_Sensors
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxNumCssSensors";

   --* @brief Get the MAX_NUM_CHEBY_POLYS constant for Ada validation.
   --* @return The value of MAX_NUM_CHEBY_POLYS.
   function Get_Max_Num_Cheby_Polys
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "CssCommAlgorithm_getMaxNumChebyPolys";

   -- Runtime validation: ensure Ada constants match C definitions
   pragma Assert (Unsigned_32 (MAX_NUM_CSS_SENSORS) = Get_Max_Num_Css_Sensors);
   pragma Assert (Unsigned_32 (MAX_NUM_CHEBY_POLYS) = Get_Max_Num_Cheby_Polys);

private

   -- Private representation: opaque null record
   type Css_Comm_Algorithm is null record;

end Css_Comm_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
