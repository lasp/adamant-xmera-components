--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Stepper Motor Controller component.
package Stepper_Motor_Controller_Tests.Implementation is

   -- Test data and state:
   type Instance is new Stepper_Motor_Controller_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Across step angles and initial positions, a reference angle commands a step of
   -- the shortest-path magnitude and direction (clockwise for an increasing
   -- position, counterclockwise for a decreasing one).
   overriding procedure Test_Move_Command (Self : in out Instance);
   -- A reference within the minimum step command of the current position produces no
   -- motor command.
   overriding procedure Test_No_Command (Self : in out Instance);
   -- A reference angle outside the configured motor travel range produces no motor
   -- command.
   overriding procedure Test_Out_Of_Range (Self : in out Instance);
   -- Changing the reference mid-move commands a halt, then re-plans a move from the
   -- final position once the motor settles.
   overriding procedure Test_Interrupt (Self : in out Instance);
   -- The applied settle count is the total desired settle count reduced by the enable
   -- hold count, saturating at zero.
   overriding procedure Test_Settle_Enable_Hold (Self : in out Instance);
   -- A move out and back from the fed-back absolute position produces equal and
   -- opposite step counts.
   overriding procedure Test_Position_Tracking (Self : in out Instance);
   -- A move whose step delta exceeds the motor-command field is rejected with an
   -- event rather than sent (or truncated).
   overriding procedure Test_Over_Range_Rejected (Self : in out Instance);
   -- When the motor state data dependency is not available (e.g. before the
   -- interface publishes it), the wrapper commands no motion and emits a
   -- Motor_State_Unavailable event rather than asserting.
   overriding procedure Test_Motor_State_Unavailable (Self : in out Instance);

   -- Test data and state:
   type Instance is new Stepper_Motor_Controller_Tests.Base_Instance with record
      null;
   end record;
end Stepper_Motor_Controller_Tests.Implementation;
