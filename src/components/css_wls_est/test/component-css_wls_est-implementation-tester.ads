--------------------------------------------------------------------------------
-- Css_Wls_Est Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Css_Wls_Est_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Data_Product;
with Packed_F32x3.Representation;
with Packed_U32.Representation;
with Packed_F32x8.Representation;
with Css_Sensor_Values;

-- CSS weighted least squares estimator fits a sun heading and body rate to the
-- readings of a coarse sun sensor constellation.
package Component.Css_Wls_Est.Implementation.Tester is

   use Component.Css_Wls_Est_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Sun_Heading_B_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);
   package Omega_Bn_B_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);
   package Num_Active_Css_History_Package is new Printable_History (Packed_U32.T, Packed_U32.Representation.Image);
   package Residual_State_Heading_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);
   package Post_Fit_Residuals_History_Package is new Printable_History (Packed_F32x8.T, Packed_F32x8.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Css_Wls_Est_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Css_Wls_Est.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Sun_Heading_B_History : Sun_Heading_B_History_Package.Instance;
      Omega_Bn_B_History : Omega_Bn_B_History_Package.Instance;
      Num_Active_Css_History : Num_Active_Css_History_Package.Instance;
      Residual_State_Heading_History : Residual_State_Heading_History_Package.Instance;
      Post_Fit_Residuals_History : Post_Fit_Residuals_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Css_Sensor_Input : Css_Sensor_Values.T;
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
   --    Data products for the Css Wls Est component.
   -- [-] Estimated unit sun heading in the body frame. Zero when no fit was
   -- possible.
   overriding procedure Sun_Heading_B (Self : in out Instance; Arg : in Packed_F32x3.T);
   -- [r/s] Inertial angular velocity in the body frame. Zero until two headings have
   -- been observed.
   overriding procedure Omega_Bn_B (Self : in out Instance; Arg : in Packed_F32x3.T);
   -- [-] Sensors whose reading exceeded the use threshold this cycle.
   overriding procedure Num_Active_Css (Self : in out Instance; Arg : in Packed_U32.T);
   -- [-] Heading captured before the singular-fit zeroing, for diagnostics.
   overriding procedure Residual_State_Heading (Self : in out Instance; Arg : in Packed_F32x3.T);
   -- [-] Post-fit measurement residuals for the 8 physical channels.
   overriding procedure Post_Fit_Residuals (Self : in out Instance; Arg : in Packed_F32x8.T);

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

end Component.Css_Wls_Est.Implementation.Tester;
