--------------------------------------------------------------------------------
-- Sunline_Srukf Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Sunline_Srukf_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Data_Product;
with Sunline_Srukf_Output.Representation;
with Nav_Att;
with Packed_F32x8;

-- Sunline SRuKF pass-through algorithm wrapping the C++ SunlineSRuKFAlgorithm.
package Component.Sunline_Srukf.Implementation.Tester is

   use Component.Sunline_Srukf_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Sunline_Srukf_State_History_Package is new Printable_History (Sunline_Srukf_Output.T, Sunline_Srukf_Output.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Sunline_Srukf_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Sunline_Srukf.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Sunline_Srukf_State_History : Sunline_Srukf_State_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Spacecraft_Attitude : Nav_Att.T;
      Css_Cos_Values_A : Packed_F32x8.T;
      Css_Cos_Values_B : Packed_F32x8.T;
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
   --    Data products for the Sunline SRuKF component.
   -- Output state from the sunline SRuKF algorithm (timeTag, sigma_BN, omega_BN_B,
   -- vehSunPntBdy).
   overriding procedure Sunline_Srukf_State (Self : in out Instance; Arg : in Sunline_Srukf_Output.T);

end Component.Sunline_Srukf.Implementation.Tester;
