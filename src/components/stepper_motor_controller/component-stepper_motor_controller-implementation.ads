--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameter_Update;
with Stepper_Motor_Controller_Algorithm_C; use Stepper_Motor_Controller_Algorithm_C;

-- Stepper motor controller algorithm commands a stepper motor to track a
-- reference angle. Each tick it fetches the motor state, runs the controller
-- state machine, and sends step or halt commands to the stepper motor interface.
package Component.Stepper_Motor_Controller.Implementation is

   -- The component class instance record:
   type Instance is new Stepper_Motor_Controller.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the stepper motor controller algorithm.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Stepper_Motor_Controller.Base_Instance with record
      Alg : Stepper_Motor_Controller_Algorithm_Access := null;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   -- Null method which can be implemented to provide some component
   -- set up code. This method is generally called by the assembly
   -- main.adb after all component initialization and tasks have been started.
   -- Some activities need to only be run once at startup, but cannot be run
   -- safely until everything is up and running, i.e. command registration, initial
   -- data product updates. This procedure should be implemented to do these things
   -- if necessary.
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Stepper_Controller_Step_T_Send message is dropped due to a full queue.
   overriding procedure Stepper_Controller_Step_T_Send_Dropped (Self : in out Instance; Arg : in Stepper_Controller_Step.T) is null;
   -- This procedure is called when a Event_T_Send message is dropped due to a full queue.
   overriding procedure Event_T_Send_Dropped (Self : in out Instance; Arg : in Event.T) is null;

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Stepper Motor Controller component

   -- Invalid parameter handler. This procedure is called when a parameter's type is found to be invalid:
   -- Null: the staging code rejects the value and returns an error status to the Parameters
   -- component, which reports the offending parameter ID to the ground. That is sufficient, and
   -- we avoid adding per-component event overhead to these algorithm components.
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is null;
   -- This procedure is called when the parameters of a component have been updated. It applies
   -- the parameter values to the C algorithm via its configuration setters.
   overriding procedure Update_Parameters_Action (Self : in out Instance);
   -- This function is called when the parameter operation type is "Validate".
   -- No custom validation: float garbage (NaN/Inf) is rejected by type
   -- validation during staging, and out-of-range values are the C algorithm
   -- setters' contract to reject.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Step_Angle : in Packed_F32.U;
      Motor_Min_Angle : in Packed_F32.U;
      Motor_Max_Angle : in Packed_F32.U;
      Settle_Count_Max : in Packed_U32.U;
      Enable_Hold_Count : in Packed_U32.U;
      Min_Step_Command : in Packed_U32.U;
      Reference_Angle : in Packed_F32.U
   ) return Parameter_Validation_Status.E is (Parameter_Validation_Status.Valid);

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Stepper Motor Controller component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Stepper_Motor_Controller.Implementation;
