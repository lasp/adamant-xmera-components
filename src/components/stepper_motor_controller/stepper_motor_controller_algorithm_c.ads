pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");

with Interfaces.C; use Interfaces; use Interfaces.C;
with Stepper_Motor_Controller_Output.C;

package Stepper_Motor_Controller_Algorithm_C is

   --* Opaque handle for a StepperMotorControllerAlgorithm instance.
   type Stepper_Motor_Controller_Algorithm is limited private;
   type Stepper_Motor_Controller_Algorithm_Access is access all Stepper_Motor_Controller_Algorithm;

   --* @brief Construct a new StepperMotorControllerAlgorithm.
   function Create
     return Stepper_Motor_Controller_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_create";

   --* @brief Destroy a StepperMotorControllerAlgorithm.
   procedure Destroy
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_destroy";

   --* @brief Reset the algorithm state machine to IDLE and clear cached positions.
   --* @param Self  The algorithm instance.
   procedure Reset
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_reset";

   --* @brief Run one tick of the controller state machine.
   --* @param Self             The algorithm instance.
   --* @param Current_Position [steps] Current motor step position (tracked by the caller).
   --* @param Reference_Angle  [rad] Reference motor angle.
   --* @param Is_Motor_Moving  True if the motor is currently moving.
   --* @return The algorithm's command (None, Stop, or Move) and step delta.
   function Update
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : Boolean)
     return Stepper_Motor_Controller_Output.C.U_C;

   --* @brief Set the angle traversed per motor step.
   --* @param Self       The algorithm instance.
   --* @param Step_Angle [rad/step] Motor step angle, must be in [2*pi/100000, 2*pi].
   procedure Set_Step_Angle
     (Self       : Stepper_Motor_Controller_Algorithm_Access;
      Step_Angle : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setStepAngle";

   --* @brief Set the motor's angular travel range. Reference angles outside this range are
   --*        rejected for partial ranges; full-circle ranges accept any angle and wrap via
   --*        shortest path.
   --* @param Self      The algorithm instance.
   --* @param Min_Angle [rad] Lower bound, must be in [-2*pi, 2*pi].
   --* @param Max_Angle [rad] Upper bound, must be in [-2*pi, 2*pi] and strictly greater than Min_Angle.
   procedure Set_Motor_Angle_Range
     (Self      : Stepper_Motor_Controller_Algorithm_Access;
      Min_Angle : Short_Float;
      Max_Angle : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setMotorAngleRange";

   --* @brief Set the maximum settling tick count.
   --* @param Self             The algorithm instance.
   --* @param Settle_Count_Max [ticks] Number of ticks to wait during settling.
   procedure Set_Settle_Count_Max
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Settle_Count_Max : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setSettleCountMax";

   --* @brief Set the minimum step delta magnitude that triggers a MOVE (from IDLE) or a
   --*        STOP-and-replan (from MOVING).
   --* @param Self             The algorithm instance.
   --* @param Min_Step_Command [steps] Minimum step delta magnitude that warrants a command (must be > 0).
   procedure Set_Min_Step_Command
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Min_Step_Command : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setMinStepCommand";

private

   -- Private representation: opaque null record
   type Stepper_Motor_Controller_Algorithm is null record;

   -- Raw C entry point. The public Update wraps this so callers pass an Ada Boolean while the C ABI
   -- keeps its 1-byte bool.
   function Update_C
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : C_bool)
     return Stepper_Motor_Controller_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_update";

   function Update
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : Boolean)
     return Stepper_Motor_Controller_Output.C.U_C
   is (Update_C (Self, Current_Position, Reference_Angle, C_bool (Is_Motor_Moving)));

end Stepper_Motor_Controller_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwu");
