pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces; use Interfaces;
with Sunline_Srukf_Input.C;
with Sunline_Srukf_Output.C;
with Packed_F32x3.C;
with Packed_F32x32.C;

package Sunline_Srukf_Algorithm_C is

   --* @brief Get the maximum number of CSS sensors.
   --* @return The maximum CSS count (SUNLINE_SRUKF_MAX_NUM_CSS).
   function Get_Max_Num_Css
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "SunlineSRuKFAlgorithm_getMaxNumCss";

   -- ABI validation: the constant-dimensioned Ada input crossing the FFI
   -- boundary must match the C-side SUNLINE_SRUKF_MAX_NUM_CSS, checked at
   -- elaboration.
   -- SunlineSRuKFInput_c: double timeTag; Vector3f_c sigma_BN, omega_BN_B,
   -- vehSunPntBdy; uint32_t nCSS; float cosValues[SUNLINE_SRUKF_MAX_NUM_CSS];
   pragma Assert (Unsigned_32 (Packed_F32x32.Length) = Get_Max_Num_Css);
   pragma Assert (Sunline_Srukf_Input.C.U_C'Object_Size =
      Long_Float'Object_Size + 3 * Packed_F32x3.C.U_C'Object_Size + Unsigned_32'Object_Size + Packed_F32x32.C.U_C'Object_Size);

   --* @brief Run the sunline SRuKF update step (stateless).
   --* @param Input Pointer to the input structure (read-only).
   --* @return The computed output.
   function Update_State
     (Input : access constant Sunline_Srukf_Input.C.U_C)
     return Sunline_Srukf_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "SunlineSRuKFAlgorithm_updateState";

end Sunline_Srukf_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
