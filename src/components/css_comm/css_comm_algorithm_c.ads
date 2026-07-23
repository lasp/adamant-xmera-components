pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Cheby_Polynomials.C;
with Packed_F64x11.C;

package Css_Comm_Algorithm_C is

   -- TODO: This local FFI type is the solitary exception to the rule that all
   -- C structs crossing the FFI boundary are generated packed records. The C
   -- algorithm currently sizes CssSensorValues_c to MAX_NUM_CSS_SENSORS = 32
   -- while only Css_Sensor_Values.T's 8 physical channels are meaningful.
   -- Once fp32-fsw-xmera narrows the C type to 8, delete this local typing
   -- and pass Css_Sensor_Values.C.U_C directly.
   --
   -- MAX_NUM_CSS_SENSORS bounds the local FFI type below (an Ada array bound
   -- must be static); it is validated against the C definition in the ABI
   -- validation block at the bottom of this package.
   MAX_NUM_CSS_SENSORS : constant := 32;

   --* POD type matching CssSensorValues_c in C.
   --* Layout: double data[MAX_NUM_CSS_SENSORS];
   --* This type exists only to cross the FFI boundary: the published
   --* Css_Sensor_Values.T data product carries fewer entries than the C
   --* algorithm's bound, so the implementation zero-pads into this type on
   --* input and truncates on return.
   type Css_Values_Array_C is array (0 .. MAX_NUM_CSS_SENSORS - 1) of aliased Long_Float
      with Convention => C;
   type Css_Sensor_Values_C is record
      Data : aliased Css_Values_Array_C;
   end record
      with Convention => C_Pass_By_Copy;
   type Css_Sensor_Values_C_Access is access all Css_Sensor_Values_C;

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
      Input_Values : Css_Sensor_Values_C_Access)
     return Css_Sensor_Values_C
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

   -- ABI validation: the constant-dimensioned Ada arrays crossing the FFI
   -- boundary must match the C-side sizing constants, checked at elaboration.
   -- CssSensorValues_c: double data[MAX_NUM_CSS_SENSORS];
   pragma Assert (Unsigned_32 (Css_Values_Array_C'Length) = Get_Max_Num_Css_Sensors);
   pragma Assert (Css_Values_Array_C'Object_Size = Css_Sensor_Values_C'Object_Size);
   pragma Assert (Unsigned_32 (Css_Sensor_Values_C'Object_Size / Long_Float'Object_Size) = Get_Max_Num_Css_Sensors);
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
