pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Rotation_Properties.C;
with Rotation_Properties_X4;
with Rotation_Properties_X4.C;
with Rotation_Properties_X4_Record.C;
with Sun_Search_Point_Output.C;

package Sun_Search_Point_Algorithm_C is

   --* Result of one guidance update, presenting the three output vectors as packed
   --* records and the search-failure flag as a native Boolean. The raw C output
   --* struct stays behind Update_C.
   type Update_Result is record
      Sigma_Br       : Packed_F32x3.T;
      Omega_Br_B     : Packed_F32x3.T;
      Omega_Rn_B     : Packed_F32x3.T;
      Fault_Detected : Boolean;
   end record;

   --* Opaque handle for a SunSearchPointAlgorithm instance.
   type Sun_Search_Point_Algorithm is limited private;
   type Sun_Search_Point_Algorithm_Access is access all Sun_Search_Point_Algorithm;

   --* @brief Report the rotation count the C shim was built with.
   --* @return The number of rotation slots in the sun-search sequence.
   function Get_Num_Rotations return Unsigned_32
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_getNumRotations";

   -- ABI validation: the Ada rotation sequence crossing the FFI boundary must match
   -- the C shim's SUN_SEARCH_POINT_NUM_ROTATIONS. Assert on the types themselves, so
   -- a width change on either side is caught at elaboration rather than corrupting
   -- memory on the first call.
   pragma Assert (Unsigned_32 (Rotation_Properties_X4.Length) = Get_Num_Rotations);
   pragma Assert (Rotation_Properties_X4.C.U_C'Object_Size = Rotation_Properties_X4_Record.C.U_C'Object_Size);
   pragma Assert (Unsigned_32 (Rotation_Properties_X4_Record.C.U_C'Object_Size / Rotation_Properties.C.U_C'Object_Size) = Get_Num_Rotations);

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Rotations             [-] Sun-search rotation sequence; each duration must be finite and > 0, each rate finite, each axis defined.
   --* @param S_Hat_Bdy_Cmd         [-] Commanded body vector to point at the sun; norm must be within 1e-3 of 1.0.
   --* @param Sun_Axis_Spin_Rate    [rad/s] Spin rate about the sun heading vector, must be finite.
   --* @param Omega_Rn_B            [rad/s] Fallback body rate when no sun direction is available, must be finite.
   --* @param Observation_Threshold [-] CSS count at or above which to transition to pointing (unconstrained).
   --* @param Control_Period        [s] Per-update time step, must be finite and > 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Rotations             : access constant Rotation_Properties_X4_Record.C.U_C;
      S_Hat_Bdy_Cmd         : Packed_F32x3_Record.C.U_C;
      Sun_Axis_Spin_Rate    : Short_Float;
      Omega_Rn_B            : Packed_F32x3_Record.C.U_C;
      Observation_Threshold : Unsigned_32;
      Control_Period        : Short_Float)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_validateConfig";

   --* @brief Construct a new SunSearchPointAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Rotations             [-] Sun-search rotation sequence; each duration must be finite and > 0, each rate finite, each axis defined.
   --* @param S_Hat_Bdy_Cmd         [-] Commanded body vector to point at the sun; norm must be within 1e-3 of 1.0.
   --* @param Sun_Axis_Spin_Rate    [rad/s] Spin rate about the sun heading vector, must be finite.
   --* @param Omega_Rn_B            [rad/s] Fallback body rate when no sun direction is available, must be finite.
   --* @param Observation_Threshold [-] CSS count at or above which to transition to pointing (unconstrained).
   --* @param Control_Period        [s] Per-update time step, must be finite and > 0.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Rotations             : access constant Rotation_Properties_X4_Record.C.U_C;
      S_Hat_Bdy_Cmd         : Packed_F32x3_Record.C.U_C;
      Sun_Axis_Spin_Rate    : Short_Float;
      Omega_Rn_B            : Packed_F32x3_Record.C.U_C;
      Observation_Threshold : Unsigned_32;
      Control_Period        : Short_Float)
     return Sun_Search_Point_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_create";

   --* @brief Destroy a SunSearchPointAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Sun_Search_Point_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* Installs the parameters only; the search phase keeps running where it was, so a
   --* caller needing the sequence restarted must follow with Re_Initialize.
   --* @param Self                  The algorithm instance.
   --* @param Rotations             [-] Sun-search rotation sequence; each duration must be finite and > 0, each rate finite, each axis defined.
   --* @param S_Hat_Bdy_Cmd         [-] Commanded body vector to point at the sun; norm must be within 1e-3 of 1.0.
   --* @param Sun_Axis_Spin_Rate    [rad/s] Spin rate about the sun heading vector, must be finite.
   --* @param Omega_Rn_B            [rad/s] Fallback body rate when no sun direction is available, must be finite.
   --* @param Observation_Threshold [-] CSS count at or above which to transition to pointing (unconstrained).
   --* @param Control_Period        [s] Per-update time step, must be finite and > 0.
   procedure Set_Config
     (Self                  : Sun_Search_Point_Algorithm_Access;
      Rotations             : access constant Rotation_Properties_X4_Record.C.U_C;
      S_Hat_Bdy_Cmd         : Packed_F32x3_Record.C.U_C;
      Sun_Axis_Spin_Rate    : Short_Float;
      Omega_Rn_B            : Packed_F32x3_Record.C.U_C;
      Observation_Threshold : Unsigned_32;
      Control_Period        : Short_Float)
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_setConfig";

   --* @brief Re-arm the runtime state machine so the next update begins a fresh
   --* search sequence. Does not touch the configuration.
   --* @param Self The algorithm instance.
   procedure Re_Initialize
     (Self : Sun_Search_Point_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_reInitialize";

   --* @brief Run the update step.
   --* @param Self                The algorithm instance.
   --* @param R_Hat_Sb_B          Sun direction vector in body frame.
   --* @param Omega_Bn_B          [rad/s] Inertial body angular velocity in body frame.
   --* @param Num_Css_Viewing_Sun [-] Coarse sun sensors observing the sun this cycle.
   --* @return The three guidance vectors and the search-failure flag.
   function Update
     (Self                : Sun_Search_Point_Algorithm_Access;
      R_Hat_Sb_B          : Packed_F32x3_Record.C.U_C;
      Omega_Bn_B          : Packed_F32x3_Record.C.U_C;
      Num_Css_Viewing_Sun : Unsigned_32)
     return Update_Result;

private

   -- Private representation: opaque null record
   type Sun_Search_Point_Algorithm is null record;

   -- Raw C entry point. The public Update wraps this so callers receive native
   -- Ada types while the C ABI keeps its output struct.
   --* @param Self                The algorithm instance.
   --* @param R_Hat_Sb_B          Sun direction vector in body frame.
   --* @param Omega_Bn_B          [rad/s] Inertial body angular velocity in body frame.
   --* @param Num_Css_Viewing_Sun [-] Coarse sun sensors observing the sun this cycle.
   --* @return The raw C output struct.
   function Update_C
     (Self                : Sun_Search_Point_Algorithm_Access;
      R_Hat_Sb_B          : Packed_F32x3_Record.C.U_C;
      Omega_Bn_B          : Packed_F32x3_Record.C.U_C;
      Num_Css_Viewing_Sun : Unsigned_32)
     return Sun_Search_Point_Output.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "SunSearchPointAlgorithm_update";

   -- Convert the raw update output to the idiomatic result.
   --* @param Output The raw C output struct.
   --* @return The three guidance vectors and the search-failure flag as native Ada types.
   function To_Result (Output : Sun_Search_Point_Output.C.U_C) return Update_Result
   is ((Sigma_Br       => Packed_F32x3.C.Pack (Output.Sigma_Br),
        Omega_Br_B     => Packed_F32x3.C.Pack (Output.Omega_Br_B),
        Omega_Rn_B     => Packed_F32x3.C.Pack (Output.Omega_Rn_B),
        Fault_Detected => Output.Fault_Detected /= 0));

   function Update
     (Self                : Sun_Search_Point_Algorithm_Access;
      R_Hat_Sb_B          : Packed_F32x3_Record.C.U_C;
      Omega_Bn_B          : Packed_F32x3_Record.C.U_C;
      Num_Css_Viewing_Sun : Unsigned_32)
     return Update_Result
   is (To_Result (Update_C (Self, R_Hat_Sb_B, Omega_Bn_B, Num_Css_Viewing_Sun)));

end Sun_Search_Point_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwx");
pragma Warnings (On, "-gnatwu");
