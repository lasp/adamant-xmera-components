--------------------------------------------------------------------------------
-- Solar_Array_Reference Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Solar_Array_Reference_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Nav_Att_Output;
with Att_Ref;
with Packed_F32x3;
with Packed_Tracking_Mode;
with Packed_F32;
with Packed_Array_Angle;
with Data_Product;
with Packed_F32.Representation;

-- Solar array reference angle guidance. Computes the array rotation angle that
-- turns the array surface normal toward the sun in the reference attitude, or
-- holds a commanded angle, and publishes it for the array drive controller. The
-- tracking mode and the angles are commanded through data products. Wraps the
-- SolarArrayReferenceAlgorithm C++ algorithm via its C shim.
package Component.Solar_Array_Reference.Implementation.Tester is

   use Component.Solar_Array_Reference_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Reference_Angle_History_Package is new Printable_History (Packed_F32.T, Packed_F32.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Solar_Array_Reference_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Solar_Array_Reference.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Reference_Angle_History : Reference_Angle_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Navigation_Attitude : Nav_Att_Output.T;
      Attitude_Reference : Att_Ref.T;
      Sun_Direction_Body : Packed_F32x3.T;
      Tracking_Mode : Packed_Tracking_Mode.T;
      Specified_Array_Angle : Packed_Array_Angle.T;
      Offset_Angle : Packed_Array_Angle.T;
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
   --    Data products for the Solar Array Reference component.
   -- [rad] Reference rotation angle of the solar array about its drive axis, wrapped
   -- to [-pi, pi].
   overriding procedure Reference_Angle (Self : in out Instance; Arg : in Packed_F32.T);

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

end Component.Solar_Array_Reference.Implementation.Tester;
