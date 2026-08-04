pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces; use Interfaces;
with St_Platform_Attitude.C;
with St_Platform_Angular_Velocity.C;
with St_Att.C;
with Packed_F32x9_Record.C;

package Convert_St_Platform_To_Body_Algorithm_C is

   --* Opaque handle for a ConvertStPlatformToBodyAlgorithm instance.
   type Convert_St_Platform_To_Body_Algorithm is limited private;
   type Convert_St_Platform_To_Body_Algorithm_Access is access all Convert_St_Platform_To_Body_Algorithm;

   --* @brief Construct a new ConvertStPlatformToBodyAlgorithm.
   function Create
     return Convert_St_Platform_To_Body_Algorithm_Access
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_create";

   --* @brief Destroy a ConvertStPlatformToBodyAlgorithm.
   procedure Destroy
     (Self : Convert_St_Platform_To_Body_Algorithm_Access)
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_destroy";

   --* @brief Convert star tracker case-frame attitude and rate to body frame.
   --* @param Self                       The algorithm instance.
   --* @param Platform_Attitude          Inertial-to-case attitude quaternion input.
   --* @param Platform_Angular_Velocity  Case-frame delta quaternion rate input.
   --* @return Star tracker attitude output in body frame.
   function Update
     (Self                       : Convert_St_Platform_To_Body_Algorithm_Access;
      Platform_Attitude          : access constant St_Platform_Attitude.C.U_C;
      Platform_Angular_Velocity  : access constant St_Platform_Angular_Velocity.C.U_C)
     return St_Att.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_update";

   --* @brief Set the DCM from body to star tracker case frame (row-major 3x3).
   --* @param Self   The algorithm instance.
   --* @param Dcm_Cb 3x3 row-major DCM from body to case frame.
   procedure Set_Dcm_Cb
     (Self   : Convert_St_Platform_To_Body_Algorithm_Access;
      Dcm_Cb : Packed_F32x9_Record.C.U_C)
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_setDcmCB";

   --* @brief Get the current DCM from body to star tracker case frame.
   --* @param Self The algorithm instance.
   --* @return 3x3 row-major DCM from body to case frame.
   function Get_Dcm_Cb
     (Self : Convert_St_Platform_To_Body_Algorithm_Access)
     return Packed_F32x9_Record.C.U_C
     with Import        => True,
          Convention    => C,
          External_Name => "ConvertStPlatformToBodyAlgorithm_getDcmCB";

private

   -- Private representation: opaque null record
   type Convert_St_Platform_To_Body_Algorithm is null record;

end Convert_St_Platform_To_Body_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");