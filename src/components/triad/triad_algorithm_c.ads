pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Packed_F32x3_Record.C;
with Triad_Enums;

package Triad_Algorithm_C is

   --* Fallback constraint axis. The representation clause pins the literals to the C
   --* N3Axis_c values so that 'Enum_Val is a genuine validity gate when converting
   --* the parameter value into this type.
   type Triad_N3_Axis is
     (Plus_Z_Hat_N,
      Minus_Z_Hat_N)
     with Convention => C;
   for Triad_N3_Axis use
     (Plus_Z_Hat_N  => 0,
      Minus_Z_Hat_N => 1);

   --* Convert the component's fallback axis parameter value into the C enumeration
   --* above. The conversion lives here, with the C type, because it is boundary
   --* marshalling: the two enumerations exist separately only because the generated
   --* Adamant enumeration cannot carry Convention => C, and so is sized for Ada rather
   --* than for the C int the shim expects. Going through 'Enum_Rep and 'Enum_Val
   --* honors both representation clauses rather than relying on literal position.
   function To_C (Value : in Triad_Enums.N3_Axis.E)
      return Triad_N3_Axis
   is (Triad_N3_Axis'Enum_Val (Triad_Enums.N3_Axis.E'Enum_Rep (Value)));

   --* Opaque handle for a TriadAlgorithm instance.
   type Triad_Algorithm is limited private;
   type Triad_Algorithm_Access is access all Triad_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Sada_Hat_B       [-] Solar array drive axis in body frame components; must be a unit vector.
   --* @param Thrust_Req_Hat_N [-] Requested thrust direction in inertial frame components; must be a unit
   --*                             vector.
   --* @param N3_Axis          [-] Inertial z axis direction used as the fallback constraint axis.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Sada_Hat_B       : access constant Packed_F32x3_Record.C.U_C;
      Thrust_Req_Hat_N : access constant Packed_F32x3_Record.C.U_C;
      N3_Axis          : Triad_N3_Axis)
     return Boolean
     with Import        => True,
          Convention    => C,
          External_Name => "TriadAlgorithm_validateConfig";

   --* @brief Construct a new TriadAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* The parameters are as for Validate_Config.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Sada_Hat_B       : access constant Packed_F32x3_Record.C.U_C;
      Thrust_Req_Hat_N : access constant Packed_F32x3_Record.C.U_C;
      N3_Axis          : Triad_N3_Axis)
     return Triad_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "TriadAlgorithm_create";

   --* @brief Destroy a TriadAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Triad_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "TriadAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input). The algorithm
   --* holds no runtime state. The parameters are as for Validate_Config.
   --* @param Self The algorithm instance.
   procedure Set_Config
     (Self             : Triad_Algorithm_Access;
      Sada_Hat_B       : access constant Packed_F32x3_Record.C.U_C;
      Thrust_Req_Hat_N : access constant Packed_F32x3_Record.C.U_C;
      N3_Axis          : Triad_N3_Axis)
     with Import        => True,
          Convention    => C,
          External_Name => "TriadAlgorithm_setConfig";

   --* @brief Compute the reference attitude that aligns the thrust direction with the requested
   --* inertial direction while keeping the solar array drive axis orthogonal to the sun.
   --* @param Self         The algorithm instance.
   --* @param R_Hat_Sb_N   [-] Unit sun direction in inertial frame components.
   --* @param Thrust_Hat_B [-] Unit thrust direction in body frame components.
   --* @return [-] Reference attitude MRP relative to inertial. Zero when the triad cannot be formed.
   function Update
     (Self         : Triad_Algorithm_Access;
      R_Hat_Sb_N   : access constant Packed_F32x3_Record.C.U_C;
      Thrust_Hat_B : access constant Packed_F32x3_Record.C.U_C)
     return Packed_F32x3_Record.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "TriadAlgorithm_update";

private

   -- Private representation: opaque null record
   type Triad_Algorithm is null record;

end Triad_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
pragma Warnings (On, "-gnatwx");
