pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Gyro_Input.C;
with Inertial_Filter_Output.C;
with Nav_Att.C;
with Rw_Array_Config_Input.C;
with Rw_Speeds_Input.C;
with St_Att_Input.C;
with Vehicle_Config_Input.C;

package Inertial_UKF_Algorithm_C is

   --* Combined output of the inertial UKF algorithm update step.
   type Inertial_UKF_Output is record
      Nav_Att_Est : aliased Nav_Att.C.U_C;
      Filter  : aliased Inertial_Filter_Output.C.U_C;
   end record
   with Convention => C_Pass_By_Copy;

   --* @brief Run the inertial UKF algorithm update step.
   --* @param St_Att     Pointer to star tracker attitude input.
   --* @param Gyro       Pointer to gyro measurement input.
   --* @param Rw_Speeds  Pointer to reaction wheel speeds input.
   --* @param Rw_Config  Pointer to reaction wheel array configuration input.
   --* @param Veh_Config Pointer to vehicle configuration input.
   --* @return Combined navigation attitude and filter output.
   function Update_State
     (St_Att     : access constant St_Att_Input.C.U_C;
      Gyro       : access constant Gyro_Input.C.U_C;
      Rw_Speeds  : access constant Rw_Speeds_Input.C.U_C;
      Rw_Config  : access constant Rw_Array_Config_Input.C.U_C;
      Veh_Config : access constant Vehicle_Config_Input.C.U_C)
     return Inertial_UKF_Output
     with Import       => True,
          Convention   => C,
          External_Name => "InertialUKFAlgorithm_updateState";

end Inertial_UKF_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
