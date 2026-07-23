pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces;         use Interfaces;
with Att_Nav_Input.C;
with Att_Ref.C;
with Att_Guid.C;

package Att_Tracking_Error_Algorithm_C is

   --* Opaque handle for an AttTrackingErrorAlgorithm instance.
   type Att_Tracking_Error_Algorithm is limited private;
   type Att_Tracking_Error_Algorithm_Access is access all Att_Tracking_Error_Algorithm;

   --* @brief Construct a new AttTrackingErrorAlgorithm.
   function Create
     return Att_Tracking_Error_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_create";

   --* @brief Destroy an AttTrackingErrorAlgorithm.
   procedure Destroy
     (Self : Att_Tracking_Error_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_destroy";

   --* @brief Run the update step of the attitude tracking error algorithm.
   --* @param Self    The algorithm instance.
   --* @param Nav_In  Navigation attitude input (sigma_BN, omega_BN_B).
   --* @param Ref_In  Reference attitude input (sigma_RN, omega_RN_N, domega_RN_N).
   --* @return Computed guidance output.
   function Update
     (Self   : Att_Tracking_Error_Algorithm_Access;
      Nav_In : Att_Nav_Input.C.U_C;
      Ref_In : Att_Ref.C.U_C)
     return Att_Guid.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_update";

private

   -- Private representation: opaque null record
   type Att_Tracking_Error_Algorithm is null record;

end Att_Tracking_Error_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
