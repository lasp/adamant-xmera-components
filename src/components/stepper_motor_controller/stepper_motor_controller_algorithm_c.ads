pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings (Off, "-gnatwu");
-- Boolean is used at the C boundary to match the shim's C99 bool (_Bool):
-- 1-byte, 0/1 representation, interoperable under Convention => C. Suppress
-- the -gnatwx advisory about using a C "char"-style type for the mapping.
pragma Warnings (Off, "-gnatwx");

with Interfaces; use Interfaces;
with Stepper_Motor_Controller_Output.C;

package Stepper_Motor_Controller_Algorithm_C is

   --* Type of command produced by the stepper motor controller. Mirrors the
   --* C StepperMotorCommandType enumeration carried in the Command_Type field
   --* of the update output struct. The representation clause pins the literals
   --* to the C values so that 'Enum_Val is a validity check when
   --* converting the raw output field: an undefined value raises
   --* Constraint_Error rather than silently mapping onto a valid command.
   type Stepper_Motor_Command_Type is
     (None,
      Stop,
      Move)
     with Convention => C;
   for Stepper_Motor_Command_Type use
     (None => 0,
      Stop => 1,
      Move => 2);

   --* Result of one controller update, presenting the command as its
   --* enumeration type. The raw C output struct stays behind Update_C.
   type Update_Result is record
      Command       : Stepper_Motor_Command_Type;
      Steps_To_Move : Integer_32;
   end record;

   --* Opaque handle for a StepperMotorControllerAlgorithm instance.
   type Stepper_Motor_Controller_Algorithm is limited private;
   type Stepper_Motor_Controller_Algorithm_Access is access all Stepper_Motor_Controller_Algorithm;

   --* @brief Report whether a configuration would be accepted by Create/Set_Config.
   --* @param Step_Angle       [rad/step] Motor step angle, must be in [2*pi/100000, 2*pi].
   --* @param Min_Angle        [rad] Lower bound of the motor travel range, must be in [-2*pi, 2*pi].
   --* @param Max_Angle        [rad] Upper bound, must be in [-2*pi, 2*pi] and strictly greater than Min_Angle.
   --* @param Settle_Count_Max [ticks] Settling duration after stepping ends (unconstrained).
   --* @param Min_Step_Command [steps] Minimum step delta magnitude that warrants a command, must be > 0.
   --* @return True if the configuration is valid. Never throws, so it can guard the
   --* throwing Create/Set_Config from an invalid configuration.
   function Validate_Config
     (Step_Angle       : Short_Float;
      Min_Angle        : Short_Float;
      Max_Angle        : Short_Float;
      Settle_Count_Max : Unsigned_32;
      Min_Step_Command : Unsigned_32)
     return Boolean
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_validateConfig";

   --* @brief Construct a new StepperMotorControllerAlgorithm from a configuration.
   --* Validate the values with Validate_Config before calling; throws on invalid input.
   --* @param Step_Angle       [rad/step] Motor step angle, must be in [2*pi/100000, 2*pi].
   --* @param Min_Angle        [rad] Lower bound of the motor travel range, must be in [-2*pi, 2*pi].
   --* @param Max_Angle        [rad] Upper bound, must be in [-2*pi, 2*pi] and strictly greater than Min_Angle.
   --* @param Settle_Count_Max [ticks] Settling duration after stepping ends (unconstrained).
   --* @param Min_Step_Command [steps] Minimum step delta magnitude that warrants a command, must be > 0.
   --* @return The new algorithm instance, which must be released with Destroy.
   function Create
     (Step_Angle       : Short_Float;
      Min_Angle        : Short_Float;
      Max_Angle        : Short_Float;
      Settle_Count_Max : Unsigned_32;
      Min_Step_Command : Unsigned_32)
     return Stepper_Motor_Controller_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_create";

   --* @brief Destroy a StepperMotorControllerAlgorithm.
   --* @param Self The algorithm instance to destroy.
   procedure Destroy
     (Self : Stepper_Motor_Controller_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_destroy";

   --* @brief Apply a new configuration (validated; throws on invalid input).
   --* @param Self             The algorithm instance.
   --* @param Step_Angle       [rad/step] Motor step angle, must be in [2*pi/100000, 2*pi].
   --* @param Min_Angle        [rad] Lower bound of the motor travel range, must be in [-2*pi, 2*pi].
   --* @param Max_Angle        [rad] Upper bound, must be in [-2*pi, 2*pi] and strictly greater than Min_Angle.
   --* @param Settle_Count_Max [ticks] Settling duration after stepping ends (unconstrained).
   --* @param Min_Step_Command [steps] Minimum step delta magnitude that warrants a command, must be > 0.
   procedure Set_Config
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Step_Angle       : Short_Float;
      Min_Angle        : Short_Float;
      Max_Angle        : Short_Float;
      Settle_Count_Max : Unsigned_32;
      Min_Step_Command : Unsigned_32)
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_setConfig";


   --* @brief Run one tick of the controller state machine.
   --* @param Self             The algorithm instance.
   --* @param Current_Position [steps] Current motor step position (tracked by the caller).
   --* @param Reference_Angle  [rad] Reference motor angle.
   --* @param Is_Motor_Moving  True if the motor is currently moving.
   --* @return The command as its enumeration type and the step delta.
   function Update
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : Boolean)
     return Update_Result;

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

private

   -- Private representation: opaque null record
   type Stepper_Motor_Controller_Algorithm is null record;

   -- Raw C entry point. The public Update wraps this so callers receive the
   -- command as its enumeration type while the C ABI keeps its raw struct.
   --* @param Self             The algorithm instance.
   --* @param Current_Position [steps] Current motor step position (tracked by the caller).
   --* @param Reference_Angle  [rad] Reference motor angle.
   --* @param Is_Motor_Moving  True if the motor is currently moving.
   --* @return The raw C output struct.
   function Update_C
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : Boolean)
     return Stepper_Motor_Controller_Output.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "StepperMotorControllerAlgorithm_update";

   -- Convert the raw update output to the idiomatic result. An out-of-range
   -- command value from the C side fails the enum conversion's range check.
   --* @param Output The raw C output struct.
   --* @return The command as its enumeration type and the step delta.
   function To_Result (Output : Stepper_Motor_Controller_Output.C.U_C) return Update_Result
   is ((Command       => Stepper_Motor_Command_Type'Enum_Val (Output.Command_Type),
        Steps_To_Move => Output.Steps_To_Move));

   function Update
     (Self             : Stepper_Motor_Controller_Algorithm_Access;
      Current_Position : Integer_32;
      Reference_Angle  : Short_Float;
      Is_Motor_Moving  : Boolean)
     return Update_Result
   is (To_Result (Update_C (Self, Current_Position, Reference_Angle, Is_Motor_Moving)));

end Stepper_Motor_Controller_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings (On, "-gnatwx");
pragma Warnings (On, "-gnatwu");
