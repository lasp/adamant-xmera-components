--------------------------------------------------------------------------------
-- Dv_Accumulation Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Dv_Accumulation_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Packed_F32x3;
with Data_Product;
with Packed_F32x3.Representation;

-- Delta-V accumulation. Integrates the majority voted body frame acceleration
-- that gravity does not cause, one sample per tick over the control period, into
-- the delta-V accumulated since the last reset, and publishes it for the burn
-- executor. The first sample after a reset starts the accumulation window and is
-- not integrated, so the accumulated delta-V is the integral over the time
-- elapsed since then. The accelerometer bias is a parameter, which the state
-- manager sets when a burn is commanded, and is subtracted from each sample.
-- Wraps the DvAccumulationAlgorithm C++ algorithm via its C shim.
package Component.Dv_Accumulation.Implementation.Tester is

   use Component.Dv_Accumulation_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Accumulated_Delta_V_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Dv_Accumulation_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Dv_Accumulation.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Accumulated_Delta_V_History : Accumulated_Delta_V_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Accel_Average : Packed_F32x3.T;
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
   --    Data products for the Dv Accumulation component.
   -- [m/s] Delta-V accumulated in body frame components since the last reset, with
   -- the accelerometer bias removed.
   overriding procedure Accumulated_Delta_V (Self : in out Instance; Arg : in Packed_F32x3.T);

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

end Component.Dv_Accumulation.Implementation.Tester;
