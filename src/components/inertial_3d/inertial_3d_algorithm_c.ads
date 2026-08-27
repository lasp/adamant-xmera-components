pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces;         use Interfaces;
with Packed_F32x3_Record.C;

package Inertial_3d_Algorithm_C is

   --* Opaque handle for an Inertial3DAlgorithm instance.
   type Inertial_3d_Algorithm is limited private;

   --* Access type to manipulate Inertial3DAlgorithm instances.
   type Inertial_3d_Algorithm_Access is access all Inertial_3d_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Sigma_Rn POD three-vector holding the MRP from inertial frame N to
   --* reference frame R; must be finite.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config (Sigma_Rn : Packed_F32x3_Record.C.U_C)
     return Boolean
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_validateConfig";

   --* @brief Construct a new Inertial3DAlgorithm from a configuration.
   --* Validate the value with Validate_Config before calling; throws on invalid input.
   --* @param Sigma_Rn POD three-vector representing sigma_RN; must be finite.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create (Sigma_Rn : Packed_F32x3_Record.C.U_C)
     return Inertial_3d_Algorithm_Access
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_create";

   --* @brief Destroy a previously created Inertial3DAlgorithm instance.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy (Self : Inertial_3d_Algorithm_Access)
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self     The algorithm instance.
   --* @param Sigma_Rn POD three-vector representing sigma_RN.
   procedure Set_Config
     (Self : Inertial_3d_Algorithm_Access;
      Sigma_Rn : Packed_F32x3_Record.C.U_C)
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_setConfig";

   --* @brief Compute the fixed reference-attitude MRP.
   --* @param Self The algorithm instance.
   --* @return POD three-vector holding the configured sigma_RN. The algorithm
   --* returns the MRP alone; the component builds the attitude reference message
   --* around it, leaving the reference rates zero as the C++ adapter does.
   function Update (Self : Inertial_3d_Algorithm_Access)
     return Packed_F32x3_Record.C.U_C
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_update";

private

   --* Opaque null record backing the Inertial3DAlgorithm handle.
   type Inertial_3d_Algorithm is null record;

end Inertial_3d_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
