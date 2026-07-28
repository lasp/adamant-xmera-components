--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Stepper_Motor_Controller_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Stepper_Controller_Step.Representation;
with Event.Representation;
with Sys_Time.Representation;
with Stepper_Motor_State;
with Event;
with Packed_I32.Representation;

-- Stepper motor controller algorithm commands a stepper motor to track a
-- reference angle. Each tick it fetches the motor state, runs the controller
-- state machine, and sends step or halt commands to the stepper motor interface.
package Component.Stepper_Motor_Controller.Implementation.Tester is

   use Component.Stepper_Motor_Controller_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Stepper_Controller_Step_T_Recv_Sync_History_Package is new Printable_History (Stepper_Controller_Step.T, Stepper_Controller_Step.Representation.Image);
   package Event_T_Recv_Sync_History_Package is new Printable_History (Event.T, Event.Representation.Image);
   package Sys_Time_T_Return_History_Package is new Printable_History (Sys_Time.T, Sys_Time.Representation.Image);

   -- Event history packages:
   package Step_Command_Saturated_History_Package is new Printable_History (Packed_I32.T, Packed_I32.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Stepper_Motor_Controller_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Stepper_Motor_Controller.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Stepper_Controller_Step_T_Recv_Sync_History : Stepper_Controller_Step_T_Recv_Sync_History_Package.Instance;
      Event_T_Recv_Sync_History : Event_T_Recv_Sync_History_Package.Instance;
      Sys_Time_T_Return_History : Sys_Time_T_Return_History_Package.Instance;
      -- Event histories:
      Step_Command_Saturated_History : Step_Command_Saturated_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Motor_State : Stepper_Motor_State.T;
      -- The return status for the data dependency fetch. This can be set
      -- during unit test to return something other than Success.
      Data_Dependency_Return_Status_Override : Data_Product_Enums.Fetch_Status.E := Data_Product_Enums.Fetch_Status.Success;
      -- The ID to return with the data dependency. If this is set to zero then
      -- the valid ID for the requested dependency is returned, otherwise, the
      -- value of this variable is returned.
      Data_Dependency_Return_Id_Override : Data_Product_Types.Data_Product_Id := 0;
      -- The length to return with the data dependency. If this is set to zero then
      -- the valid length for the requested dependency is returned, otherwise, the
      -- value of this variable is returned.
      Data_Dependency_Return_Length_Override : Data_Product_Types.Data_Product_Buffer_Length_Type := 0;
      -- The timestamp to return with the data dependency. If this is set to (0, 0) then
      -- the System_Time (above) is returned, otherwise, the value of this variable is returned.
      Data_Dependency_Timestamp_Override : Sys_Time.T := (0, 0);
   end record;
   type Instance_Access is access all Instance;

   ---------------------------------------
   -- Initialize component heap variables:
   ---------------------------------------
   procedure Init_Base (Self : in out Instance);
   procedure Final_Base (Self : in out Instance);

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance);

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Fetch a data product item from the database.
   overriding function Data_Product_Fetch_T_Service (Self : in out Instance; Arg : in Data_Product_Fetch.T) return Data_Product_Return.T;
   -- Send the computed step or halt command to the stepper motor interface
   -- component.
   overriding procedure Stepper_Controller_Step_T_Recv_Sync (Self : in out Instance; Arg : in Stepper_Controller_Step.T);
   -- The event send connector
   overriding procedure Event_T_Recv_Sync (Self : in out Instance; Arg : in Event.T);
   -- The system time is retrieved via this connector.
   overriding function Sys_Time_T_Return (Self : in out Instance) return Sys_Time.T;

   -----------------------------------------------
   -- Event handler primitive:
   -----------------------------------------------
   -- Description:
   --    Events for the Stepper Motor Controller component.
   -- The algorithm commanded a step delta whose magnitude exceeds the step command's
   -- Num_Steps field range. The commanded number of steps was saturated; the
   -- remainder is re-commanded on subsequent control cycles after the motor settles.
   -- The parameter is the raw commanded step delta.
   overriding procedure Step_Command_Saturated (Self : in out Instance; Arg : in Packed_I32.T);

   -----------------------------------------------
   -- Special primitives for aiding in the staging,
   -- fetching, and updating of parameters
   -----------------------------------------------
   -- Stage a parameter value within the component
   not overriding function Stage_Parameter (Self : in out Instance; Par : in Parameter.T) return Parameter_Update_Status.E;
   -- Fetch the value of a parameter with the component
   not overriding function Fetch_Parameter (Self : in out Instance; Id : in Parameter_Types.Parameter_Id; Par : out Parameter.T) return Parameter_Update_Status.E;
   -- Ask the component to validate all parameters. This will call the
   -- Validate_Parameters subprogram within the component implementation,
   -- which allows custom checking of the parameter set prior to updating.
   not overriding function Validate_Parameters (Self : in out Instance) return Parameter_Update_Status.E;
   -- Tell the component it is OK to atomically update all of its
   -- working parameter values with the staged values.
   not overriding function Update_Parameters (Self : in out Instance) return Parameter_Update_Status.E;

end Component.Stepper_Motor_Controller.Implementation.Tester;
