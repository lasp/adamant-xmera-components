--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Oe_State_Ephem_Reciprocal;
with Printable_History;
with Data_Product_Return.Representation;
with Data_Product_Fetch.Representation;
with Data_Product.Representation;
with Data_Product;
with Cartesian_State.Representation;
with Tdb_Vehicle_Clock_Correlation;
with Cartesian_State;
with Oe_Coefficients;
with Interfaces.C;

-- Orbital element state ephemeris algorithm computes spacecraft position and
-- velocity using Chebyshev polynomial fits of classical orbital elements.
package Component.Oe_State_Ephem.Implementation.Tester is

   use Component.Oe_State_Ephem_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_Fetch_T_Service_History_Package is new Printable_History (Data_Product_Fetch.T, Data_Product_Fetch.Representation.Image);
   package Data_Product_Fetch_T_Service_Return_History_Package is new Printable_History (Data_Product_Return.T, Data_Product_Return.Representation.Image);
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);

   -- Data product history packages:
   package Ephemeris_State_History_Package is new Printable_History (Cartesian_State.T, Cartesian_State.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Oe_State_Ephem_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Oe_State_Ephem.Implementation.Instance;
      -- Connector histories:
      Data_Product_Fetch_T_Service_History : Data_Product_Fetch_T_Service_History_Package.Instance;
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      -- Data product histories:
      Ephemeris_State_History : Ephemeris_State_History_Package.Instance;
      -- Data dependency return values. These can be set during unit test
      -- and will be returned to the component when a data dependency call
      -- is made.
      Clock_Correlation : Tdb_Vehicle_Clock_Correlation.T := (Ephemeris_Time => 0.0, Vehicle_Clock_Time => 0.0);
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
   -- Algorithm configuration helpers:
   ---------------------------------------
   -- Reaches into the component's private algorithm pointer to drive
   -- the underlying C++ Chebyshev fitter directly. Used by tests to
   -- arm coefficients before sending Tick.
   procedure Set_Central_Body_Mu (Self : in out Instance; Mu : in Interfaces.C.double);
   procedure Configure_Arc (
      Self : in out Instance;
      Arc_Number : in Interfaces.C.unsigned;
      Number_Of_Coefficients : in Interfaces.C.unsigned;
      Middle_Time : in Interfaces.C.double;
      Radius_Time : in Interfaces.C.double;
      Anomaly_Flag : in Interfaces.C.unsigned;
      Radius_Periapsis : in Oe_Coefficients.T;
      Eccentricity : in Oe_Coefficients.T;
      Inclination : in Oe_Coefficients.T;
      Arg_Periapsis : in Oe_Coefficients.T;
      Raan : in Oe_Coefficients.T;
      True_Anomaly : in Oe_Coefficients.T
   );

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
   --    Data products for the OE State Ephem component.
   -- Computed spacecraft Cartesian state (position and velocity) from
   -- Chebyshev orbital element fit.
   overriding procedure Ephemeris_State (Self : in out Instance; Arg : in Cartesian_State.T);

end Component.Oe_State_Ephem.Implementation.Tester;
