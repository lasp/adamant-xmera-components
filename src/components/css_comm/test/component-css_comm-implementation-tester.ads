--------------------------------------------------------------------------------
-- Css_Comm Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Css_Comm_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Css_Sensor_Values;
with Data_Product;
with Css_Sensor_Values.Representation;

-- CSS communication algorithm converts raw CSS sensor readings into corrected
-- cosine values using Chebyshev polynomial fitting.
package Component.Css_Comm.Implementation.Tester is

   use Component.Css_Comm_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Css_Sensor_Output_History_Package is new Printable_History (Css_Sensor_Values.T, Css_Sensor_Values.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Css_Comm_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Css_Comm.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Css_Sensor_Output_History : Css_Sensor_Output_History_Package.Instance;
      -- Data dependency return values:
      Css_Sensor_Input : Css_Sensor_Values.T;
      -- Data dependency fetch overrides:
      Data_Dependency_Return_Status_Override : Data_Product_Enums.Fetch_Status.E := Data_Product_Enums.Fetch_Status.Success;
      Data_Dependency_Return_Id_Override : Data_Product_Types.Data_Product_Id := 0;
      Data_Dependency_Return_Length_Override : Data_Product_Types.Data_Product_Buffer_Length_Type := 0;
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
   overriding function Data_Product_Fetch_T_Service (Self : in out Instance; Arg : in Data_Product_Fetch.T) return Data_Product_Return.T;
   overriding procedure Data_Product_T_Recv_Sync (Self : in out Instance; Arg : in Data_Product.T);

   -----------------------------------------------
   -- Data product handler primitives:
   -----------------------------------------------
   overriding procedure Css_Sensor_Output (Self : in out Instance; Arg : in Css_Sensor_Values.T);

   -----------------------------------------------
   -- Parameter staging/update helpers:
   -----------------------------------------------
   not overriding function Stage_Parameter (Self : in out Instance; Par : in Parameter.T) return Parameter_Update_Status.E;
   not overriding function Fetch_Parameter (Self : in out Instance; Id : in Parameter_Types.Parameter_Id; Par : out Parameter.T) return Parameter_Update_Status.E;
   not overriding function Validate_Parameters (Self : in out Instance) return Parameter_Update_Status.E;
   not overriding function Update_Parameters (Self : in out Instance) return Parameter_Update_Status.E;

end Component.Css_Comm.Implementation.Tester;
