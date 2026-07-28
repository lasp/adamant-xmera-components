pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Motor_Angle_Range.C;
with Stepper_Motor_Controller_Output.C;

package Stepper_Motor_Controller_Algorithm_C is

   --* Type of command produced by the stepper motor controller. Mirrors the
   --* C StepperMotorCommandType enumeration carried in the Command_Type field
   --* of the update output struct.
   type Stepper_Motor_Command_Type is
     (None,
      Stop,
      Move)
     with Convention => C;

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
   --* @param Self The algorithm instance.
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
   --* @return Command type (NONE, STOP, MOVE) and step delta.
   function Update
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : Boolean)
     return Stepper_Motor_Controller_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_update";

   --* @brief Convert a reference angle to an integer step position using the configured step angle.
   --* @param Self  The algorithm instance.
   --* @param Angle [rad] Reference angle.
   --* @return Step position rounded to the nearest integer.
   function Angle_To_Steps
     (Self  : Stepper_Motor_Controller_Algorithm_Access;
      Angle : Short_Float)
     return Integer_32
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_angleToSteps";

   --* @brief Set the angle traversed per motor step.
   --* @param Self       The algorithm instance.
   --* @param Step_Angle [rad/step] Motor step angle, must be in [2*pi/100000, 2*pi].
   procedure Set_Step_Angle
     (Self       : Stepper_Motor_Controller_Algorithm_Access;
      Step_Angle : Short_Float)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setStepAngle";

   --* @brief Get the angle traversed per motor step.
   --* @param Self The algorithm instance.
   --* @return Motor step angle [rad/step].
   function Get_Step_Angle
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     return Short_Float
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_getStepAngle";

   --* @brief Set the motor's angular travel range. Reference angles outside this range
   --*        are rejected for partial ranges; full-circle ranges accept any angle and
   --*        wrap via shortest path.
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

   --* @brief Get the motor's angular travel range.
   --* @param Self The algorithm instance.
   --* @return The {Min_Angle, Max_Angle} range in radians.
   function Get_Motor_Angle_Range
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     return Motor_Angle_Range.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_getMotorAngleRange";

   --* @brief Set the maximum settling tick count.
   --* @param Self             The algorithm instance.
   --* @param Settle_Count_Max [ticks] Number of ticks to wait during settling.
   procedure Set_Settle_Count_Max
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Settle_Count_Max : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setSettleCountMax";

   --* @brief Get the maximum settling tick count.
   --* @param Self The algorithm instance.
   --* @return Settling duration [ticks].
   function Get_Settle_Count_Max
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_getSettleCountMax";

   --* @brief Set the minimum step delta magnitude that triggers a MOVE (from IDLE)
   --*        or a STOP-and-replan (from MOVING).
   --* @param Self             The algorithm instance.
   --* @param Min_Step_Command [steps] Minimum step delta magnitude that warrants a command (must be > 0).
   procedure Set_Min_Step_Command
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Min_Step_Command : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setMinStepCommand";

   --* @brief Get the minimum commandable step delta.
   --* @param Self The algorithm instance.
   --* @return Minimum step delta magnitude [steps].
   function Get_Min_Step_Command
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     return Unsigned_32
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_getMinStepCommand";

private

   -- Private representation: opaque null record
   type Stepper_Motor_Controller_Algorithm is null record;

end Stepper_Motor_Controller_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwx");
pragma Warnings (On, "-gnatwu");
