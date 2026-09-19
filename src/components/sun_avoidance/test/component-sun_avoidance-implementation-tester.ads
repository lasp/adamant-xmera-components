--------------------------------------------------------------------------------
-- Sun_Avoidance Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Sun_Avoidance_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Nav_Att_Output;
with Att_Ref;
with Cartesian_State;
with Data_Product;
with Att_Ref.Representation;

-- Sun avoidance attitude guidance. Superimposes a constant rate slew from the
-- current body attitude onto the input attitude reference, taking the long way
-- around when the short slew would sweep a sensitive body axis across the Sun.
-- The slew is planned on the first tick after a reset and fed forward at the
-- configured rate until the reference is reached. Wraps the SunAvoidanceAlgorithm
-- C++ algorithm via its C shim.
package Component.Sun_Avoidance.Implementation.Tester is

   use Component.Sun_Avoidance_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Attitude_Reference_History_Package is new Printable_History (Att_Ref.T, Att_Ref.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Sun_Avoidance_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Sun_Avoidance.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Attitude_Reference_History : Attitude_Reference_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Spacecraft_Attitude : Nav_Att_Output.T;
      Input_Attitude_Reference : Att_Ref.T;
      Spacecraft_State : Cartesian_State.T;
      Sun_State : Cartesian_State.T;
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
   --    Data products for the Sun Avoidance component.
   -- The input attitude reference rotated by the remaining slew, with the slew rate
   -- added to the reference rate while the slew is in progress.
   overriding procedure Attitude_Reference (Self : in out Instance; Arg : in Att_Ref.T);

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

end Component.Sun_Avoidance.Implementation.Tester;
