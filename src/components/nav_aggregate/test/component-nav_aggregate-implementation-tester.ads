--------------------------------------------------------------------------------
-- Nav_Aggregate Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Nav_Aggregate_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Data_Product;
with Nav_Att.Representation;
with Nav_Trans.Representation;
with Nav_Att;
with Ephemeris;

-- Navigation aggregation algorithm combines multiple navigation message sources
-- into single aggregated attitude and translational navigation messages.
package Component.Nav_Aggregate.Implementation.Tester is

   use Component.Nav_Aggregate_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Aggregated_Nav_Att_History_Package is new Printable_History (Nav_Att.T, Nav_Att.Representation.Image);
   package Aggregated_Nav_Trans_History_Package is new Printable_History (Nav_Trans.T, Nav_Trans.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Nav_Aggregate_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Nav_Aggregate.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Aggregated_Nav_Att_History : Aggregated_Nav_Att_History_Package.Instance;
      Aggregated_Nav_Trans_History : Aggregated_Nav_Trans_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Att_Msg_0 : Nav_Att.T;
      Att_Msg_1 : Nav_Att.T;
      Att_Msg_2 : Nav_Att.T;
      Att_Msg_3 : Nav_Att.T;
      Trans_Msg_0 : Ephemeris.T;
      Trans_Msg_1 : Ephemeris.T;
      Trans_Msg_2 : Ephemeris.T;
      Trans_Msg_3 : Ephemeris.T;
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
      -- the system_Time (above) is returned, otherwise, the value of this variable is returned.
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
   --    Data products for the Nav Aggregate component.
   -- Aggregated attitude navigation message combining fields from multiple sources.
   overriding procedure Aggregated_Nav_Att (Self : in out Instance; Arg : in Nav_Att.T);
   -- Aggregated translational navigation message combining fields from multiple
   -- sources.
   overriding procedure Aggregated_Nav_Trans (Self : in out Instance; Arg : in Nav_Trans.T);

end Component.Nav_Aggregate.Implementation.Tester;
