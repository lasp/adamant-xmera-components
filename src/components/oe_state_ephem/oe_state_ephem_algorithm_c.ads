pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Cartesian_State.C;

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

   --* Anomaly-angle interpretation flag matching the C AnomalyType enum
   --* (TRUE_ANOMALY = 0, MEAN_ANOMALY = 1). Convention => C sizes it as a C int.
   type Anomaly_Type_C is (True_Anomaly, Mean_Anomaly)
      with Convention => C;

   --* Fixed C array of Chebyshev coefficients (double[MAX_OE_COEFF]).
   type Oe_Coeff_Array_C is array (0 .. Max_Oe_Coeff - 1) of aliased Long_Float
      with Convention => C;

   --* POD type matching ChebyshevFitArc_c in C. Field order and types mirror
   --* the C struct exactly so the layout is ABI-compatible across the boundary.
   type Cheb_Fit_Arc_C is record
      Number_Cheb_Coefficients      : aliased Unsigned_32;      --* [-] active coefficients in this arc.
      Ephemeris_Time_Middle         : aliased Long_Float;       --* [s] ephemeris time at the arc mid-point.
      Ephemeris_Time_Radius         : aliased Long_Float;       --* [s] half-width of the arc's valid time range.
      Radius_Periapsis_Coefficients : aliased Oe_Coeff_Array_C; --* [-] radius-of-periapsis coefficients.
      Eccentricity_Coefficients     : aliased Oe_Coeff_Array_C; --* [-] eccentricity coefficients.
      Inclination_Coefficients      : aliased Oe_Coeff_Array_C; --* [-] inclination coefficients.
      Arg_Periapsis_Coefficients    : aliased Oe_Coeff_Array_C; --* [-] argument-of-periapsis coefficients.
      Raan_Coefficients             : aliased Oe_Coeff_Array_C; --* [-] RAAN coefficients.
      True_Anomaly_Coefficients     : aliased Oe_Coeff_Array_C; --* [-] anomaly-angle coefficients.
      Anomaly_Flag                  : aliased Anomaly_Type_C;   --* [-] true vs mean anomaly flag.
   end record
      with Convention => C_Pass_By_Copy;

   --* Fixed C array of fit arcs (ChebyshevFitArc_c[MAX_OE_RECORDS]).
   type Cheb_Fit_Arc_Array_C is array (0 .. Max_Oe_Records - 1) of aliased Cheb_Fit_Arc_C
      with Convention => C;

   --* POD config type matching OEStateEphemConfig_c in C.
   type Oe_State_Ephem_Config_C is record
      Central_Body_Gravitational_Parameter : aliased Long_Float;          --* [m^3/s^2] central-body gravitational parameter.
      Number_Of_Arcs                       : aliased Unsigned_32;         --* [-] number of populated arcs.
      Ephemeris_Time_J2000                 : aliased Long_Float;          --* [s] ephemeris time offset referenced to J2000.
      Vehicle_Time_Offset                  : aliased Long_Float;          --* [s] vehicle clock time offset.
      Fit_Coefficients                     : aliased Cheb_Fit_Arc_Array_C; --* [-] table of Chebyshev fit arcs.
   end record
      with Convention => C_Pass_By_Copy;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Config The configuration to check.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Config : access constant Oe_State_Ephem_Config_C)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_validateConfig";

   --* @brief Construct a new OEStateEphemAlgorithm from a configuration.
   --* @param Config The configuration to apply (validated; throws on invalid input).
   --* Validate config values with Validate_Config before calling so an invalid config
   --* never reaches this.
   function Create
     (Config : access constant Oe_State_Ephem_Config_C)
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

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param Config The configuration to apply.
   procedure Set_Config
     (Self   : Oe_State_Ephem_Algorithm_Access;
      Config : access constant Oe_State_Ephem_Config_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setConfig";

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

private

   -- Private representation: opaque null record
   type Oe_State_Ephem_Algorithm is null record;

end Oe_State_Ephem_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
