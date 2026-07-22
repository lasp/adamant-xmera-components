--------------------------------------------------------------------------------
-- Average_Mimu_Data Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Average_Mimu_Data_Reciprocal;
with Printable_History;
with Sys_Time.Representation;
with Event.Representation;
with Data_Product.Representation;
with Event;
with Data_Product;
with Averaged_Imu_Data.Representation;

-- Averages MIMU accelerometer and gyro data within a configurable time window and
-- transforms to the spacecraft body frame.
package Component.Average_Mimu_Data.Implementation.Tester is

   use Component.Average_Mimu_Data_Reciprocal;
   -- Invoker connector history packages:
   package Sys_Time_T_Return_History_Package is new Printable_History (Sys_Time.T, Sys_Time.Representation.Image);
   package Event_T_Recv_Sync_History_Package is new Printable_History (Event.T, Event.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Event history packages:
   package Packet_Buffer_Overflow_History_Package is new Printable_History (Natural, Natural'Image);

   -- Data product history packages:
   package Imu_Body_Data_History_Package is new Printable_History (Averaged_Imu_Data.T, Averaged_Imu_Data.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Average_Mimu_Data_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Average_Mimu_Data.Implementation.Instance;
      -- Connector histories:
      Sys_Time_T_Return_History : Sys_Time_T_Return_History_Package.Instance;
      Event_T_Recv_Sync_History : Event_T_Recv_Sync_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Event histories:
      Packet_Buffer_Overflow_History : Packet_Buffer_Overflow_History_Package.Instance;
      -- Data product histories:
      Imu_Body_Data_History : Imu_Body_Data_History_Package.Instance;
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
   -- The system time is retrieved via this connector.
   overriding function Sys_Time_T_Return (Self : in out Instance) return Sys_Time.T;
   -- The event send connector
   overriding procedure Event_T_Recv_Sync (Self : in out Instance; Arg : in Event.T);
   -- The data product invoker connector
   overriding procedure Data_Product_T_Recv_Sync (Self : in out Instance; Arg : in Data_Product.T);

   -----------------------------------------------
   -- Event handler primitive:
   -----------------------------------------------
   -- Description:
   --    Events for the Average Mimu Data component.
   -- A raw MIMU data packet was received but the internal buffer is full. The
   -- incoming packet was dropped.
   overriding procedure Packet_Buffer_Overflow (Self : in out Instance);

   -----------------------------------------------
   -- Data product handler primitives:
   -----------------------------------------------
   -- Description:
   --    Data products for the Average Mimu Data component.
   -- Averaged IMU acceleration and angular velocity in spacecraft body frame.
   overriding procedure Imu_Body_Data (Self : in out Instance; Arg : in Averaged_Imu_Data.T);

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

end Component.Average_Mimu_Data.Implementation.Tester;
