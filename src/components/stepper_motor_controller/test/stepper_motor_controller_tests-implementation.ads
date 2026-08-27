--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Stepper Motor Controller component
package Stepper_Motor_Controller_Tests.Implementation is

   -- Test data and state:
   type Instance is new Stepper_Motor_Controller_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Verify nominal move commands with shortest-path wrapping through the full Ada
   -- to C++ path.
   overriding procedure Test_Nominal_Move (Self : in out Instance);
   -- Verify no step command is issued while the step delta is below the minimum step
   -- command threshold.
   overriding procedure Test_Below_Min_Step_Command (Self : in out Instance);
   -- Verify a reference change mid-move produces a halt command and the controller
   -- re-plans from the settled position after the settle duration.
   overriding procedure Test_Interrupt_And_Replan (Self : in out Instance);
   -- Verify references outside a partial motor angle range produce no motion and an
   -- in-range reference uses the linear path.
   overriding procedure Test_Out_Of_Range_Reference (Self : in out Instance);
   -- Verify step deltas exceeding the Num_Steps field range are saturated and
   -- reported via event.
   overriding procedure Test_Step_Command_Saturation (Self : in out Instance);
   -- Verify a stale motor state is accepted and used, while an unavailable motor
   -- state fails an assertion.
   overriding procedure Test_Motor_State_Staleness (Self : in out Instance);
   -- Verify malformed parameter staging requests are rejected by status.
   overriding procedure Test_Parameter_Staging_Errors (Self : in out Instance);
   -- A staged parameter set the algorithm's config validators would reject is refused
   -- by Validate_Parameters, one field at a time.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Stepper_Motor_Controller_Tests.Base_Instance with record
      null;
   end record;
end Stepper_Motor_Controller_Tests.Implementation;
