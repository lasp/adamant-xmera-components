pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Cartesian_State.C;
with Oe_Coefficients.C;
with Packed_F64x20.C;

package Oe_State_Ephem_Algorithm_C is

   --* Opaque handle for an OEStateEphemAlgorithm instance.
   type Oe_State_Ephem_Algorithm is limited private;
   type Oe_State_Ephem_Algorithm_Access is access all Oe_State_Ephem_Algorithm;

   --* @brief Get MAX_OE_COEFF, the number of Chebyshev coefficients per
   --* orbital element, for ABI validation.
   function Get_Max_Oe_Coeff return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getMaxOeCoeff";

   --* @brief Get MAX_OE_RECORDS, the maximum number of time-segmented arc
   --* records. No Ada type is dimensioned by this constant; the C setters
   --* enforce the arc count at runtime, so there is nothing to validate on
   --* the Ada side.
   function Get_Max_Oe_Records return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getMaxOeRecords";

   -- ABI validation: the constant-dimensioned Ada array crossing the FFI
   -- boundary must match the C-side MAX_OE_COEFF, checked at elaboration.
   -- OeCoefficients: double data[MAX_OE_COEFF];
   pragma Assert (Unsigned_32 (Packed_F64x20.Length) = Get_Max_Oe_Coeff);
   pragma Assert (Packed_F64x20.C.U_C'Object_Size = Oe_Coefficients.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Oe_Coefficients.C.U_C'Object_Size / Long_Float'Object_Size) = Get_Max_Oe_Coeff);

   --* @brief Construct a new OEStateEphemAlgorithm.
   function Create
     return Oe_State_Ephem_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_create";

   --* @brief Destroy an OEStateEphemAlgorithm.
   procedure Destroy
     (Self : Oe_State_Ephem_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_destroy";

   --* @brief Run the ephemeris update step.
   --* @param Self      The algorithm instance.
   --* @param Call_Time Vehicle time in nanoseconds.
   --* @return Cartesian state with position and velocity vectors.
   function Update
     (Self      : Oe_State_Ephem_Algorithm_Access;
      Call_Time : Unsigned_64)
     return Cartesian_State.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_update";

   --* @brief Set the central body gravitational parameter.
   --* @param Self The algorithm instance.
   --* @param Mu   [m^3/s^2] Gravitational parameter.
   procedure Set_Central_Body_Gravitational_Parameter
     (Self : Oe_State_Ephem_Algorithm_Access;
      Mu   : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setCentralBodyGravitationalParameter";

   --* @brief Get the central body gravitational parameter.
   --* @param Self The algorithm instance.
   --* @return [m^3/s^2] The gravitational parameter.
   function Get_Central_Body_Gravitational_Parameter
     (Self : Oe_State_Ephem_Algorithm_Access)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getCentralBodyGravitationalParameter";

   --* @brief Set the number of orbital element coefficient arcs.
   --* @param Self The algorithm instance.
   --* @param Arcs Number of arcs.
   procedure Set_Number_Of_Arcs
     (Self : Oe_State_Ephem_Algorithm_Access;
      Arcs : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setNumberOfArcs";

   --* @brief Get the number of orbital element coefficient arcs.
   --* @param Self The algorithm instance.
   --* @return Number of arcs.
   function Get_Number_Of_Arcs
     (Self : Oe_State_Ephem_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getNumberOfArcs";

   --* @brief Set the ephemeris time offset referenced to J2000.
   --* @param Self            The algorithm instance.
   --* @param Ephemeris_J2000 [s] Ephemeris time offset.
   procedure Set_Ephemeris_Time_J2000
     (Self            : Oe_State_Ephem_Algorithm_Access;
      Ephemeris_J2000 : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setEphemerisTimeJ2000";

   --* @brief Get the ephemeris time offset referenced to J2000.
   --* @param Self The algorithm instance.
   --* @return [s] Ephemeris time offset.
   function Get_Ephemeris_Time_J2000
     (Self : Oe_State_Ephem_Algorithm_Access)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getEphemerisTimeJ2000";

   --* @brief Set the vehicle time offset.
   --* @param Self        The algorithm instance.
   --* @param Time_Offset [s] Vehicle time offset.
   procedure Set_Vehicle_Time_Offset
     (Self        : Oe_State_Ephem_Algorithm_Access;
      Time_Offset : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setVehicleTimeOffset";

   --* @brief Get the vehicle time offset.
   --* @param Self The algorithm instance.
   --* @return [s] Vehicle time offset.
   function Get_Vehicle_Time_Offset
     (Self : Oe_State_Ephem_Algorithm_Access)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getVehicleTimeOffset";

   --* @brief Set number of Chebyshev coefficients for a given arc.
   procedure Set_Arc_Number_Of_Coefficients
     (Self                   : Oe_State_Ephem_Algorithm_Access;
      Arc_Number             : Unsigned_32;
      Number_Of_Coefficients : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcNumberOfCoefficients";

   --* @brief Get number of Chebyshev coefficients for a given arc.
   function Get_Arc_Number_Of_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcNumberOfCoefficients";

   --* @brief Set the ephemeris time midpoint for a given arc.
   procedure Set_Arc_Middle_Time
     (Self        : Oe_State_Ephem_Algorithm_Access;
      Arc_Number  : Unsigned_32;
      Time_Middle : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcMiddleTime";

   --* @brief Get the ephemeris time midpoint for a given arc.
   function Get_Arc_Middle_Time
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcMiddleTime";

   --* @brief Set the ephemeris time radius for a given arc.
   procedure Set_Arc_Radius_Time
     (Self        : Oe_State_Ephem_Algorithm_Access;
      Arc_Number  : Unsigned_32;
      Time_Radius : Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcRadiusTime";

   --* @brief Get the ephemeris time radius for a given arc.
   function Get_Arc_Radius_Time
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Long_Float
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcRadiusTime";

   --* @brief Set the anomaly flag for a given arc.
   procedure Set_Arc_Anomaly_Flag
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Anomaly_Flag : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcAnomalyFlag";

   --* @brief Get the anomaly flag for a given arc.
   function Get_Arc_Anomaly_Flag
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcAnomalyFlag";

   --* @brief Set radius periapsis Chebyshev coefficients for a given arc.
   procedure Set_Arc_Radius_Periapsis_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcRadiusPeriapsisCoefficients";

   --* @brief Get radius periapsis Chebyshev coefficients for a given arc.
   function Get_Arc_Radius_Periapsis_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcRadiusPeriapsisCoefficients";

   --* @brief Set eccentricity Chebyshev coefficients for a given arc.
   procedure Set_Arc_Eccentricity_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcEccentricityCoefficients";

   --* @brief Get eccentricity Chebyshev coefficients for a given arc.
   function Get_Arc_Eccentricity_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcEccentricityCoefficients";

   --* @brief Set inclination Chebyshev coefficients for a given arc.
   procedure Set_Arc_Inclination_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcInclinationCoefficients";

   --* @brief Get inclination Chebyshev coefficients for a given arc.
   function Get_Arc_Inclination_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcInclinationCoefficients";

   --* @brief Set argument of periapsis Chebyshev coefficients for a given arc.
   procedure Set_Arc_Arg_Periapsis_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcArgPeriapsisCoefficients";

   --* @brief Get argument of periapsis Chebyshev coefficients for a given arc.
   function Get_Arc_Arg_Periapsis_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcArgPeriapsisCoefficients";

   --* @brief Set RAAN Chebyshev coefficients for a given arc.
   procedure Set_Arc_Raan_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcRaanCoefficients";

   --* @brief Get RAAN Chebyshev coefficients for a given arc.
   function Get_Arc_Raan_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcRaanCoefficients";

   --* @brief Set true anomaly Chebyshev coefficients for a given arc.
   procedure Set_Arc_True_Anomaly_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : Unsigned_32;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcTrueAnomalyCoefficients";

   --* @brief Get true anomaly Chebyshev coefficients for a given arc.
   function Get_Arc_True_Anomaly_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcTrueAnomalyCoefficients";

private

   -- Private representation: opaque null record
   type Oe_State_Ephem_Algorithm is null record;

end Oe_State_Ephem_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
