pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Cartesian_State.C;
with Oe_State_Ephem_Enums;
with Oe_Coefficients.C;
with Packed_F64x20.C;
with Oe_Arc.C;
with Oe_Arc_Records;

package Oe_State_Ephem_Algorithm_C is

   --* Opaque handle for an OEStateEphemAlgorithm instance.
   type Oe_State_Ephem_Algorithm is limited private;
   type Oe_State_Ephem_Algorithm_Access is access all Oe_State_Ephem_Algorithm;

   --* Opaque handle for a heap-resident OEStateEphemConfig staging object. Built
   --* incrementally (Config_Reset, Config_Set_Scalars, then Config_Add_Arc once
   --* per active arc); each mutating call validates its input on the C++ side
   --* and reports rejection as False, so the config is at every moment either
   --* empty or a valid configuration. The arc count is owned by the config and
   --* incremented by Config_Add_Arc. Building arc by arc keeps the caller's
   --* transient stack at one arc; once built, the config is handed to the
   --* algorithm by handle and reset for reuse on the next build.
   type Oe_State_Ephem_Config is limited private;
   type Oe_State_Ephem_Config_Access is access all Oe_State_Ephem_Config;

   --* @brief Get MAX_OE_COEFF, the number of Chebyshev coefficients per
   --* orbital element, for ABI validation.
   --* @return The C-side MAX_OE_COEFF coefficients-per-element count.
   function Get_Max_Oe_Coeff return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getMaxOeCoeff";

   --* @brief Get MAX_OE_RECORDS, the maximum number of time-segmented arc records.
   --* @return The C-side MAX_OE_RECORDS arc-table bound.
   function Get_Max_Oe_Records return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getMaxOeRecords";

   --* @brief Get sizeof(ChebyshevFitArc_c) in bits, for per-arc ABI validation.
   --* @return The size of one C-side Chebyshev fit arc, in bits.
   function Get_Fit_Arc_Size_Bits return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getFitArcSizeBits";

   -- ABI validation: the constant-dimensioned Ada types crossing the FFI boundary
   -- must match the C-side sizing constants, checked at elaboration.
   -- OeCoefficients: double data[MAX_OE_COEFF];
   pragma Assert (Unsigned_32 (Packed_F64x20.Length) = Get_Max_Oe_Coeff);
   pragma Assert (Packed_F64x20.C.U_C'Object_Size = Oe_Coefficients.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Oe_Coefficients.C.U_C'Object_Size / Long_Float'Object_Size) = Get_Max_Oe_Coeff);
   -- ChebyshevFitArc_c fitCoefficients[MAX_OE_RECORDS]. The arc array crosses by
   -- reference and the C++ side reads it at fixed offsets, so a layout drift misreads
   -- data rather than failing to compile.
   pragma Assert (Unsigned_32 (Oe_Arc_Records.Length) = Get_Max_Oe_Records);
   -- This size assert is narrower than it looks: it catches a field added or removed,
   -- or a Long_Float narrowed, but not an Anomaly_Flag width change (the seven bytes
   -- of padding that follow absorb any width up to 64 bits) and not a size-preserving
   -- field reorder. Field order is guarded behaviourally by the component tests.
   pragma Assert (Oe_Arc.C.U_C'Object_Size = Get_Fit_Arc_Size_Bits);
   -- Anomaly_Flag pairs with a uint8_t-backed C enum, and the generated Adamant
   -- enumeration carries no size clause -- its 8-bit width is a GNAT default that
   -- nothing in the model pins. Assert it directly, since the size assert above
   -- cannot see it.
   pragma Assert (Oe_State_Ephem_Enums.Anomaly_Type.E'Object_Size = 8);

   --* @brief Allocate a new configuration in the empty state (zero arcs, zeroed
   --* storage). Must be released with Config_Destroy.
   function Config_Create
     return Oe_State_Ephem_Config_Access
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemConfig_create";

   --* @brief Destroy a previously created configuration.
   --* @param Config The configuration to destroy.
   procedure Config_Destroy
     (Config : Oe_State_Ephem_Config_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemConfig_destroy";

   --* @brief Return a configuration to the empty state for reuse.
   --* @param Config The configuration to reset.
   procedure Config_Reset
     (Config : Oe_State_Ephem_Config_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemConfig_reset";

   --* @brief Set the scalar half of a configuration.
   --* @param Config          The configuration.
   --* @param Central_Body_Mu [m^3/s^2] Central-body gravitational parameter.
   --* @param Ephemeris_Time  [s] Ephemeris time offset referenced to J2000.
   --* @param Vehicle_Time    [s] Vehicle clock time offset.
   --* @return True on success; False if a value was rejected (the configuration
   --* is unmodified).
   function Config_Set_Scalars
     (Config          : Oe_State_Ephem_Config_Access;
      Central_Body_Mu : Long_Float;
      Ephemeris_Time  : Long_Float;
      Vehicle_Time    : Long_Float)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemConfig_setScalars";

   --* @brief Append one active arc to a configuration. The arc count is owned by
   --* the configuration.
   --* @param Config  The configuration.
   --* @param Fit_Arc The arc to append.
   --* @return True on success; False if the arc was rejected or the table is
   --* already full (the configuration is unmodified).
   function Config_Add_Arc
     (Config  : Oe_State_Ephem_Config_Access;
      Fit_Arc : access constant Oe_Arc.C.U_C)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemConfig_addArc";

   --* @brief Report whether a configuration would be accepted by the algorithm.
   --* @param Config The configuration.
   --* @return True if valid; False if empty (or otherwise invalid). Because every
   --* mutation validates its input, an empty configuration is the only reachable
   --* invalid state; the full re-check is defense in depth.
   function Config_Validate
     (Config : Oe_State_Ephem_Config_Access)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemConfig_validate";

   --* @brief Construct a new OEStateEphemAlgorithm from a configuration.
   --* Validate with Config_Validate before calling; throws on an invalid
   --* configuration.
   --* @param Config The configuration to copy into the algorithm.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Config : Oe_State_Ephem_Config_Access)
     return Oe_State_Ephem_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_create";

   --* @brief Destroy an OEStateEphemAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Oe_State_Ephem_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_destroy";

   --* @brief Replace the algorithm's configuration. Validate with Config_Validate
   --* before calling; throws on an invalid configuration, leaving the active
   --* configuration intact.
   --* @param Self   The algorithm instance.
   --* @param Config The configuration to copy into the algorithm.
   procedure Set_Config
     (Self   : Oe_State_Ephem_Algorithm_Access;
      Config : Oe_State_Ephem_Config_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_setConfig";

   --* @brief Read back the scalar half of the algorithm's active configuration.
   --* Together with Get_Config_Arc this exposes the configuration the algorithm is
   --* actually using, so parameter dumps serve real algorithm state (the single
   --* source of truth) rather than a component-side copy.
   --* @param Self            The algorithm instance.
   --* @param Central_Body_Mu [m^3/s^2] Central-body gravitational parameter.
   --* @param Number_Of_Arcs  [-] Number of populated arcs.
   --* @param Ephemeris_Time  [s] Ephemeris time offset referenced to J2000.
   --* @param Vehicle_Time    [s] Vehicle clock time offset.
   procedure Get_Config_Scalars
     (Self            : Oe_State_Ephem_Algorithm_Access;
      Central_Body_Mu : out Long_Float;
      Number_Of_Arcs  : out Unsigned_32;
      Ephemeris_Time  : out Long_Float;
      Vehicle_Time    : out Long_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getConfigScalars";

   --* @brief Read back one Chebyshev fit arc of the active configuration. Slots at
   --* or above the active count read back zero-filled.
   --* Per-arc granularity keeps the caller's transient storage at one arc: reading
   --* the full configuration back never requires a table-sized buffer.
   --* @param Self       The algorithm instance.
   --* @param Arc_Number [-] Arc index; must be below MAX_OE_RECORDS.
   --* @param Fit_Arc    The arc's coefficients and time window (written).
   procedure Get_Config_Arc
     (Self       : Oe_State_Ephem_Algorithm_Access;
      Arc_Number : Unsigned_32;
      Fit_Arc    : access Oe_Arc.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "OEStateEphemAlgorithm_getConfigArc";

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

   -- Private representation: opaque null records
   type Oe_State_Ephem_Algorithm is null record;
   type Oe_State_Ephem_Config is null record;

end Oe_State_Ephem_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
