pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Packed_F32x3_Record.C;

package Thrust_Vectoring_Algorithm_C is

   --* Opaque handle for a ThrustVectoringAlgorithm instance.
   type Thrust_Vectoring_Algorithm is limited private;
   type Thrust_Vectoring_Algorithm_Access is access all Thrust_Vectoring_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param R_Mb_B [m] Thrust point M relative to the B origin, B components; must be finite.
   --* @param Thrust [N] Thrust magnitude; must be finite and positive.
   --* @param R_Cb_B [m] Center of mass relative to the B origin, B components; must be finite and farther
   --*                   than 1 mm from the thrust point M.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (R_Mb_B : access constant Packed_F32x3_Record.C.U_C;
      Thrust : Short_Float;
      R_Cb_B : access constant Packed_F32x3_Record.C.U_C)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "ThrustVectoringAlgorithm_validateConfig";

   --* @brief Construct a new ThrustVectoringAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param R_Mb_B [m] Thrust point M relative to the B origin, B components.
   --* @param Thrust [N] Thrust magnitude.
   --* @param R_Cb_B [m] Center of mass relative to the B origin, B components.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (R_Mb_B : access constant Packed_F32x3_Record.C.U_C;
      Thrust : Short_Float;
      R_Cb_B : access constant Packed_F32x3_Record.C.U_C)
     return Thrust_Vectoring_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "ThrustVectoringAlgorithm_create";

   --* @brief Destroy a ThrustVectoringAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Thrust_Vectoring_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "ThrustVectoringAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self   The algorithm instance.
   --* @param R_Mb_B [m] Thrust point M relative to the B origin, B components.
   --* @param Thrust [N] Thrust magnitude.
   --* @param R_Cb_B [m] Center of mass relative to the B origin, B components.
   procedure Set_Config
     (Self   : Thrust_Vectoring_Algorithm_Access;
      R_Mb_B : access constant Packed_F32x3_Record.C.U_C;
      Thrust : Short_Float;
      R_Cb_B : access constant Packed_F32x3_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "ThrustVectoringAlgorithm_setConfig";

   --* @brief Compute the thrust direction that produces the requested torque.
   --* @param Self   The algorithm instance.
   --* @param Lreq_B [Nm] Requested thruster torque about the center of mass, body frame components.
   --* @return [-] Thrust unit direction, body frame components.
   function Update
     (Self   : Thrust_Vectoring_Algorithm_Access;
      Lreq_B : access constant Packed_F32x3_Record.C.U_C)
     return Packed_F32x3_Record.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "ThrustVectoringAlgorithm_update";

private

   -- Private representation: opaque null record
   type Thrust_Vectoring_Algorithm is null record;

end Thrust_Vectoring_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
