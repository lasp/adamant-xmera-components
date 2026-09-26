--------------------------------------------------------------------------------
-- Sunline_Filter Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Sunline_Filter_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Data_Product;
with Nav_Att_Output.Representation;
with Sunline_Filter_State.Representation;
with Sunline_Filter_Css_Fit_Residuals.Representation;
with Sunline_Filter_Rate_Fit_Residuals.Representation;
with Packed_F32x3;
with Css_Sensor_Values;

-- Sunline filter. Estimates the sun direction in the body frame, the body rate,
-- and the coarse sun sensor intensity bias from the coarse sun sensor cosines and
-- the body rate with a square root unscented Kalman filter, and publishes the
-- estimate for the guidance algorithms. The filter state, the variance of each
-- state, and the residuals of each measurement are published as data products.
-- The filter keeps its own time base, which restarts at the tick after it is
-- built or reset, and takes the time of each measurement from its data product.
-- Wraps the SunlineFilterAlgorithm C++ algorithm via its C shim.
package Component.Sunline_Filter.Implementation.Tester is

   use Component.Sunline_Filter_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Sun_Direction_Estimate_History_Package is new Printable_History (Nav_Att_Output.T, Nav_Att_Output.Representation.Image);
   package Filter_State_History_Package is new Printable_History (Sunline_Filter_State.T, Sunline_Filter_State.Representation.Image);
   package Css_Pre_Fit_Residuals_History_Package is new Printable_History (Sunline_Filter_Css_Fit_Residuals.T, Sunline_Filter_Css_Fit_Residuals.Representation.Image);
   package Css_Post_Fit_Residuals_History_Package is new Printable_History (Sunline_Filter_Css_Fit_Residuals.T, Sunline_Filter_Css_Fit_Residuals.Representation.Image);
   package Rate_Residuals_History_Package is new Printable_History (Sunline_Filter_Rate_Fit_Residuals.T, Sunline_Filter_Rate_Fit_Residuals.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Sunline_Filter_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Sunline_Filter.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Sun_Direction_Estimate_History : Sun_Direction_Estimate_History_Package.Instance;
      Filter_State_History : Filter_State_History_Package.Instance;
      Css_Pre_Fit_Residuals_History : Css_Pre_Fit_Residuals_History_Package.Instance;
      Css_Post_Fit_Residuals_History : Css_Post_Fit_Residuals_History_Package.Instance;
      Rate_Residuals_History : Rate_Residuals_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Body_Rate : Packed_F32x3.T;
      Css_Cosines : Css_Sensor_Values.T;
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
   --    Data products for the Sunline Filter component.
   -- Estimated sun direction in the body frame and body rate, stamped with the time
   -- the filter advanced to. The attitude is not estimated by this filter and is
   -- zero.
   overriding procedure Sun_Direction_Estimate (Self : in out Instance; Arg : in Nav_Att_Output.T);
   -- The filter state after the update, the variance of each state, and the system
   -- time of the last coarse sun sensor and body rate readings applied.
   overriding procedure Filter_State (Self : in out Instance; Arg : in Sunline_Filter_State.T);
   -- Coarse sun sensor residuals before this update, with whether that measurement
   -- fired and how many sensors were active.
   overriding procedure Css_Pre_Fit_Residuals (Self : in out Instance; Arg : in Sunline_Filter_Css_Fit_Residuals.T);
   -- Coarse sun sensor residuals after this update, with whether that measurement
   -- fired and how many sensors were active.
   overriding procedure Css_Post_Fit_Residuals (Self : in out Instance; Arg : in Sunline_Filter_Css_Fit_Residuals.T);
   -- Gyro rate residuals of this update, with whether that measurement fired.
   overriding procedure Rate_Residuals (Self : in out Instance; Arg : in Sunline_Filter_Rate_Fit_Residuals.T);

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

end Component.Sunline_Filter.Implementation.Tester;
