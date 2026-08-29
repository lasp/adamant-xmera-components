--------------------------------------------------------------------------------
-- Sun_Search_Point Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Sun_Search_Point_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Packed_F32x3;
with Packed_U32;
with Data_Product;
with Packed_F32x3.Representation;
with Packed_Boolean.Representation;

-- Safe-mode sun search and pointing guidance. Runs a scripted sun-search rotation
-- sequence, then transitions to closed-loop sun pointing once the sun is acquired
-- or the sequence elapses.
package Component.Sun_Search_Point.Implementation.Tester is

   use Component.Sun_Search_Point_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Sigma_Br_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);
   package Omega_Br_B_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);
   package Omega_Rn_B_History_Package is new Printable_History (Packed_F32x3.T, Packed_F32x3.Representation.Image);
   package Fault_Detected_History_Package is new Printable_History (Packed_Boolean.T, Packed_Boolean.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Sun_Search_Point_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Sun_Search_Point.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Sigma_Br_History : Sigma_Br_History_Package.Instance;
      Omega_Br_B_History : Omega_Br_B_History_Package.Instance;
      Omega_Rn_B_History : Omega_Rn_B_History_Package.Instance;
      Fault_Detected_History : Fault_Detected_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Omega_Bn_B : Packed_F32x3.T;
      R_Hat_Sb_B : Packed_F32x3.T;
      Num_Css_Viewing_Sun : Packed_U32.T;
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
   --    Data products for the Sun Search Point component.
   -- Attitude error (MRPs) of the body frame relative to the reference frame.
   overriding procedure Sigma_Br (Self : in out Instance; Arg : in Packed_F32x3.T);
   -- [rad/s] Body rate error of B relative to R, in B frame components.
   overriding procedure Omega_Br_B (Self : in out Instance; Arg : in Packed_F32x3.T);
   -- [rad/s] Reference frame rate of R relative to N, in B frame components.
   overriding procedure Omega_Rn_B (Self : in out Instance; Arg : in Packed_F32x3.T);
   -- True once the search sequence elapsed without acquiring the sun and pointing
   -- was forced.
   overriding procedure Fault_Detected (Self : in out Instance; Arg : in Packed_Boolean.T);

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

end Component.Sun_Search_Point.Implementation.Tester;
