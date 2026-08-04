pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Packed_F32x3_Record.C;
with Packed_F64x3_Record.C;

package Sunline_Ephem_Algorithm_C is

   --* Opaque handle for a SunlineEphemAlgorithm instance.
   type Sunline_Ephem_Algorithm is limited private;
   type Sunline_Ephem_Algorithm_Access is access all Sunline_Ephem_Algorithm;

   --* @brief Construct a new SunlineEphemAlgorithm.
   function Create
     return Sunline_Ephem_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "SunlineEphemAlgorithm_create";

   --* @brief Destroy a SunlineEphemAlgorithm.
   procedure Destroy
     (Self : Sunline_Ephem_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "SunlineEphemAlgorithm_destroy";

   --* @brief Compute ephemeris-based sunline heading in body frame.
   --* @param Self     The algorithm instance.
   --* @param Sun_Pos  Sun inertial position r_SN_N [m] (Vector3d_c).
   --* @param Sc_Pos   Spacecraft inertial position r_BN_N [m] (Vector3d_c).
   --* @param Sigma_Bn Spacecraft attitude MRP, body relative to inertial (Vector3f_c).
   --* @param Result   Out: sunline direction (unit vector) in body frame (Vector3f_c).
   procedure Update
     (Self     : Sunline_Ephem_Algorithm_Access;
      Sun_Pos  : access constant Packed_F64x3_Record.C.U_C;
      Sc_Pos   : access constant Packed_F64x3_Record.C.U_C;
      Sigma_Bn : access constant Packed_F32x3_Record.C.U_C;
      Result   : access Packed_F32x3_Record.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "SunlineEphemAlgorithm_update";

private

   -- Private representation: opaque null record
   type Sunline_Ephem_Algorithm is null record;

end Sunline_Ephem_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
