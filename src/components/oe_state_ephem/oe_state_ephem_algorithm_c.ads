pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Cartesian_State.C;
with Oe_Coefficients.C;

package Oe_State_Ephem_Algorithm_C is

   --* Opaque handle for an OEStateEphemAlgorithm instance.
   type Oe_State_Ephem_Algorithm is limited private;
   type Oe_State_Ephem_Algorithm_Access is access all Oe_State_Ephem_Algorithm;

   --* Maximum number of Chebyshev coefficients per orbital element.
   Max_Oe_Coeff : constant := 20;

   --* Maximum number of time-segmented arc records.
   Max_Oe_Records : constant := 10;

   --* @brief Validate Max_Oe_Coeff matches the C++ constant.
   function Get_Max_Oe_Coeff return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getMaxOeCoeff";

   --* @brief Validate Max_Oe_Records matches the C++ constant.
   function Get_Max_Oe_Records return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getMaxOeRecords";

   --* Runtime validation catches mismatches at program startup.
   pragma Assert (Unsigned_32 (Max_Oe_Coeff) = Get_Max_Oe_Coeff);
   pragma Assert (Unsigned_32 (Max_Oe_Records) = Get_Max_Oe_Records);

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
      Mu   : C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setCentralBodyGravitationalParameter";

   --* @brief Get the central body gravitational parameter.
   --* @param Self The algorithm instance.
   --* @return [m^3/s^2] The gravitational parameter.
   function Get_Central_Body_Gravitational_Parameter
     (Self : Oe_State_Ephem_Algorithm_Access)
     return C.double
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getCentralBodyGravitationalParameter";

   --* @brief Set the number of orbital element coefficient arcs.
   --* @param Self The algorithm instance.
   --* @param Arcs Number of arcs.
   procedure Set_Number_Of_Arcs
     (Self : Oe_State_Ephem_Algorithm_Access;
      Arcs : C.unsigned)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setNumberOfArcs";

   --* @brief Get the number of orbital element coefficient arcs.
   --* @param Self The algorithm instance.
   --* @return Number of arcs.
   function Get_Number_Of_Arcs
     (Self : Oe_State_Ephem_Algorithm_Access)
     return C.unsigned
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getNumberOfArcs";

   --* @brief Set the ephemeris time offset referenced to J2000.
   --* @param Self            The algorithm instance.
   --* @param Ephemeris_J2000 [s] Ephemeris time offset.
   procedure Set_Ephemeris_Time_J2000
     (Self            : Oe_State_Ephem_Algorithm_Access;
      Ephemeris_J2000 : C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setEphemerisTimeJ2000";

   --* @brief Get the ephemeris time offset referenced to J2000.
   --* @param Self The algorithm instance.
   --* @return [s] Ephemeris time offset.
   function Get_Ephemeris_Time_J2000
     (Self : Oe_State_Ephem_Algorithm_Access)
     return C.double
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getEphemerisTimeJ2000";

   --* @brief Set the vehicle time offset.
   --* @param Self        The algorithm instance.
   --* @param Time_Offset [s] Vehicle time offset.
   procedure Set_Vehicle_Time_Offset
     (Self        : Oe_State_Ephem_Algorithm_Access;
      Time_Offset : C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setVehicleTimeOffset";

   --* @brief Get the vehicle time offset.
   --* @param Self The algorithm instance.
   --* @return [s] Vehicle time offset.
   function Get_Vehicle_Time_Offset
     (Self : Oe_State_Ephem_Algorithm_Access)
     return C.double
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getVehicleTimeOffset";

   --* @brief Set number of Chebyshev coefficients for a given arc.
   procedure Set_Arc_Number_Of_Coefficients
     (Self                  : Oe_State_Ephem_Algorithm_Access;
      Arc_Number            : C.unsigned;
      Number_Of_Coefficients : C.unsigned)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcNumberOfCoefficients";

   --* @brief Get number of Chebyshev coefficients for a given arc.
   function Get_Arc_Number_Of_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return C.unsigned
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcNumberOfCoefficients";

   --* @brief Set the ephemeris time midpoint for a given arc.
   procedure Set_Arc_Middle_Time
     (Self        : Oe_State_Ephem_Algorithm_Access;
      Arc_Number  : C.unsigned;
      Time_Middle : C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcMiddleTime";

   --* @brief Get the ephemeris time midpoint for a given arc.
   function Get_Arc_Middle_Time
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return C.double
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcMiddleTime";

   --* @brief Set the ephemeris time radius for a given arc.
   procedure Set_Arc_Radius_Time
     (Self        : Oe_State_Ephem_Algorithm_Access;
      Arc_Number  : C.unsigned;
      Time_Radius : C.double)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcRadiusTime";

   --* @brief Get the ephemeris time radius for a given arc.
   function Get_Arc_Radius_Time
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return C.double
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcRadiusTime";

   --* @brief Set the anomaly flag for a given arc.
   procedure Set_Arc_Anomaly_Flag
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Anomaly_Flag : C.unsigned)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcAnomalyFlag";

   --* @brief Get the anomaly flag for a given arc.
   function Get_Arc_Anomaly_Flag
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return C.unsigned
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcAnomalyFlag";

   --* @brief Set radius periapsis Chebyshev coefficients for a given arc.
   procedure Set_Arc_Radius_Periapsis_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcRadiusPeriapsisCoefficients";

   --* @brief Get radius periapsis Chebyshev coefficients for a given arc.
   function Get_Arc_Radius_Periapsis_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcRadiusPeriapsisCoefficients";

   --* @brief Set eccentricity Chebyshev coefficients for a given arc.
   procedure Set_Arc_Eccentricity_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcEccentricityCoefficients";

   --* @brief Get eccentricity Chebyshev coefficients for a given arc.
   function Get_Arc_Eccentricity_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcEccentricityCoefficients";

   --* @brief Set inclination Chebyshev coefficients for a given arc.
   procedure Set_Arc_Inclination_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcInclinationCoefficients";

   --* @brief Get inclination Chebyshev coefficients for a given arc.
   function Get_Arc_Inclination_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcInclinationCoefficients";

   --* @brief Set argument of periapsis Chebyshev coefficients for a given arc.
   procedure Set_Arc_Arg_Periapsis_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcArgPeriapsisCoefficients";

   --* @brief Get argument of periapsis Chebyshev coefficients for a given arc.
   function Get_Arc_Arg_Periapsis_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcArgPeriapsisCoefficients";

   --* @brief Set RAAN Chebyshev coefficients for a given arc.
   procedure Set_Arc_Raan_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcRaanCoefficients";

   --* @brief Get RAAN Chebyshev coefficients for a given arc.
   function Get_Arc_Raan_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
     return Oe_Coefficients.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getArcRaanCoefficients";

   --* @brief Set true anomaly Chebyshev coefficients for a given arc.
   procedure Set_Arc_True_Anomaly_Coefficients
     (Self         : Oe_State_Ephem_Algorithm_Access;
      Arc_Number   : C.unsigned;
      Coefficients : access constant Oe_Coefficients.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setArcTrueAnomalyCoefficients";

   --* @brief Get true anomaly Chebyshev coefficients for a given arc.
   function Get_Arc_True_Anomaly_Coefficients
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : C.unsigned)
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
