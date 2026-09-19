pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Att_Ref.C;
with Packed_F64x3_Record.C;

package Hill_Point_Algorithm_C is

   --* Opaque handle for a HillPointAlgorithm instance.
   type Hill_Point_Algorithm is limited private;
   type Hill_Point_Algorithm_Access is access all Hill_Point_Algorithm;

   --* @brief Construct a new HillPointAlgorithm. The algorithm has no configuration.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     return Hill_Point_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "HillPointAlgorithm_create";

   --* @brief Destroy a HillPointAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Hill_Point_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "HillPointAlgorithm_destroy";

   --* @brief Compute the Hill frame attitude reference for the spacecraft state.
   --* The orbit is taken about the primary body whose state is R_Pn_N / V_Pn_N. Pass
   --* zeros for the primary body state when the spacecraft state is already expressed
   --* relative to that body.
   --* @param Self   The algorithm instance.
   --* @param R_Bn_N [m]   Spacecraft inertial position in the inertial frame N.
   --* @param V_Bn_N [m/s] Spacecraft inertial velocity in the inertial frame N.
   --* @param R_Pn_N [m]   Primary body inertial position in the inertial frame N.
   --* @param V_Pn_N [m/s] Primary body inertial velocity in the inertial frame N.
   --* @return Hill frame reference attitude, rate, and acceleration. All zero when the
   --* orbit geometry is degenerate.
   function Update
     (Self   : Hill_Point_Algorithm_Access;
      R_Bn_N : Packed_F64x3_Record.C.U_C;
      V_Bn_N : Packed_F64x3_Record.C.U_C;
      R_Pn_N : Packed_F64x3_Record.C.U_C;
      V_Pn_N : Packed_F64x3_Record.C.U_C)
     return Att_Ref.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "HillPointAlgorithm_update";

private

   -- Private representation: opaque null record
   type Hill_Point_Algorithm is null record;

end Hill_Point_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
