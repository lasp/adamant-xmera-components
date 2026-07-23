pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces;         use Interfaces;
with Att_Ref.C;
with Packed_F32x3_Record.C;

package Inertial_3d_Algorithm_C is

   --* Opaque handle for an Inertial3DAlgorithm instance.
   type Inertial_3d_Algorithm is limited private;

   --* Access type to manipulate Inertial3DAlgorithm instances.
   type Inertial_3d_Algorithm_Access is access all Inertial_3d_Algorithm;

   --* @brief Construct a new Inertial3DAlgorithm instance.
   function Create return Inertial_3d_Algorithm_Access
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_create";

   --* @brief Destroy a previously created Inertial3DAlgorithm instance.
   procedure Destroy (Self : Inertial_3d_Algorithm_Access)
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_destroy";

   --* @brief Set the MRP from inertial frame N to reference frame R.
   --* @param Self      The algorithm instance.
   --* @param Sigma_Rn  POD three-vector representing sigma_RN.
   procedure Set_Sigma_Rn
     (Self : Inertial_3d_Algorithm_Access;
      Sigma_Rn : Packed_F32x3_Record.C.U_C)
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_setSigmaRN";

   --* @brief Get the MRP from inertial frame N to reference frame R.
   --* @param Self The algorithm instance.
   --* @return POD three-vector representing sigma_RN.
   function Get_Sigma_Rn (Self : Inertial_3d_Algorithm_Access)
     return Packed_F32x3_Record.C.U_C
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_getSigmaRN";

   --* @brief Compute the inertial attitude reference message.
   --* @param Self The algorithm instance.
   --* @return Attitude reference message payload.
   function Update (Self : Inertial_3d_Algorithm_Access)
     return Att_Ref.C.U_C
     with Import => True,
          Convention => C,
          External_Name => "Inertial3DAlgorithm_update";

private

   --* Opaque null record backing the Inertial3DAlgorithm handle.
   type Inertial_3d_Algorithm is null record;

end Inertial_3d_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
