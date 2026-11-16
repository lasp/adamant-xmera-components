--------------------------------------------------------------------------------
-- Gimbal_Angles_To_Motor_Angles Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Gimbal_Angles_To_Motor_Angles_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Gimbal_Angles;
with Data_Product;
with Packed_F32.Representation;

-- Gimbal angles to motor angles. Computes the two stepper motor angles that place
-- the gimbal at the requested tip and tilt angles. Each motor has one bicubic
-- B-spline surface that gives the motor steps, and the steps are multiplied by
-- the step angle. A request outside the addressable rhombus of gimbal angles
-- keeps the last motor angles that were computed. Wraps the
-- GimbalAnglesToMotorAnglesAlgorithm C++ algorithm via its C shim.
package Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester is

   use Component.Gimbal_Angles_To_Motor_Angles_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Motor_1_Angle_History_Package is new Printable_History (Packed_F32.T, Packed_F32.Representation.Image);
   package Motor_2_Angle_History_Package is new Printable_History (Packed_F32.T, Packed_F32.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Gimbal_Angles_To_Motor_Angles_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Gimbal_Angles_To_Motor_Angles.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Motor_1_Angle_History : Motor_1_Angle_History_Package.Instance;
      Motor_2_Angle_History : Motor_2_Angle_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Gimbal_Command : Gimbal_Angles.T;
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
   -- The data product invoker connector
   overriding procedure Data_Product_T_Recv_Sync (Self : in out Instance; Arg : in Data_Product.T);

   -----------------------------------------------
   -- Data product handler primitives:
   -----------------------------------------------
   -- Description:
   --    Data products for the Gimbal Angles To Motor Angles component.
   -- [rad] Motor 1 angle for the requested gimbal angles.
   overriding procedure Motor_1_Angle (Self : in out Instance; Arg : in Packed_F32.T);
   -- [rad] Motor 2 angle for the requested gimbal angles.
   overriding procedure Motor_2_Angle (Self : in out Instance; Arg : in Packed_F32.T);

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
   -- Tell the component to forget any staged parameter values that
   -- have not yet been marked for update.
   not overriding function Discard_Parameters (Self : in out Instance) return Parameter_Update_Status.E;

end Component.Gimbal_Angles_To_Motor_Angles.Implementation.Tester;
