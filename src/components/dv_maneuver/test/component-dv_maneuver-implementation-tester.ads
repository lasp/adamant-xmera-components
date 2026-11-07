--------------------------------------------------------------------------------
-- Dv_Maneuver Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Dv_Maneuver_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Packed_F32x3;
with Data_Product;
with Cmd_Force_Body.Representation;
with Packed_Burn_State.Representation;

-- Delta-V burn executor. Commands the configured body force while a burn executes
-- and zero once it is complete, and publishes the burn state. The burn times, the
-- commanded delta-V and the body force are parameters. The times and the delta-V
-- are set by the state manager when a burn is commanded, and the algorithm
-- validates them before they are applied. The burn starts at the first tick after
-- the component is built or reset, and completes when the accumulated delta-V
-- reaches the commanded one after the minimum burn time, or when the maximum burn
-- time is reached. Complete is terminal until the next reset, so the assembly
-- fires the reset when the burn is to start and ticks the component only while
-- the burn state is in use. Wraps the DvManeuverAlgorithm C++ algorithm via its C
-- shim.
package Component.Dv_Maneuver.Implementation.Tester is

   use Component.Dv_Maneuver_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Commanded_Force_History_Package is new Printable_History (Cmd_Force_Body.T, Cmd_Force_Body.Representation.Image);
   package Burn_State_History_Package is new Printable_History (Packed_Burn_State.T, Packed_Burn_State.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Dv_Maneuver_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Dv_Maneuver.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Commanded_Force_History : Commanded_Force_History_Package.Instance;
      Burn_State_History : Burn_State_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Accumulated_Delta_V : Packed_F32x3.T;
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
   --    Data products for the Dv Maneuver component.
   -- [N] The configured body force while the burn executes, zero once it is
   -- complete.
   overriding procedure Commanded_Force (Self : in out Instance; Arg : in Cmd_Force_Body.T);
   -- Whether the burn is executing or complete.
   overriding procedure Burn_State (Self : in out Instance; Arg : in Packed_Burn_State.T);

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

end Component.Dv_Maneuver.Implementation.Tester;
