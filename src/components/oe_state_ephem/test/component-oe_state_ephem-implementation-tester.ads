--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Oe_State_Ephem_Reciprocal;
with Printable_History;
with Data_Product.Representation;
with Event.Representation;
with Sys_Time.Representation;
with Data_Product;
with Cartesian_State.Representation;
with Event;
with Packed_U32.Representation;

-- Orbital element state ephemeris algorithm. Computes spacecraft Cartesian
-- state (position and velocity) from Chebyshev polynomial fits of classical
-- orbital elements. The algorithm's configuration (central body gravitational
-- parameter and per-arc Chebyshev coefficients) is delivered as a single
-- Oe_State_Ephem_Parameter_Table payload via a Parameter_Table_Forwarder
-- upstream; the component validates the bytes, stages them on a protected
-- area, and applies them to the algorithm on the next tick.
package Component.Oe_State_Ephem.Implementation.Tester is

   use Component.Oe_State_Ephem_Reciprocal;
   -- Invoker connector history packages:
   package Data_Product_T_Recv_Sync_History_Package is new Printable_History (Data_Product.T, Data_Product.Representation.Image);
   package Event_T_Recv_Sync_History_Package is new Printable_History (Event.T, Event.Representation.Image);
   package Sys_Time_T_Return_History_Package is new Printable_History (Sys_Time.T, Sys_Time.Representation.Image);

   -- Event history packages:
   package Invalid_Parameter_Table_Format_History_Package is new Printable_History (Packed_U32.T, Packed_U32.Representation.Image);
   package Parameter_Table_Applied_History_Package is new Printable_History (Natural, Natural'Image);
   package Get_Copy_Not_Supported_History_Package is new Printable_History (Natural, Natural'Image);
   package Validate_Not_Supported_History_Package is new Printable_History (Natural, Natural'Image);

   -- Data product history packages:
   package Ephemeris_State_History_Package is new Printable_History (Cartesian_State.T, Cartesian_State.Representation.Image);

   -- Component class instance:
   type Instance is new Component.Oe_State_Ephem_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Oe_State_Ephem.Implementation.Instance;
      -- Connector histories:
      Data_Product_T_Recv_Sync_History : Data_Product_T_Recv_Sync_History_Package.Instance;
      Event_T_Recv_Sync_History : Event_T_Recv_Sync_History_Package.Instance;
      Sys_Time_T_Return_History : Sys_Time_T_Return_History_Package.Instance;
      -- Event histories:
      Invalid_Parameter_Table_Format_History : Invalid_Parameter_Table_Format_History_Package.Instance;
      Parameter_Table_Applied_History : Parameter_Table_Applied_History_Package.Instance;
      Get_Copy_Not_Supported_History : Get_Copy_Not_Supported_History_Package.Instance;
      Validate_Not_Supported_History : Validate_Not_Supported_History_Package.Instance;
      -- Data product histories:
      Ephemeris_State_History : Ephemeris_State_History_Package.Instance;
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
   -- The data product invoker connector.
   overriding procedure Data_Product_T_Recv_Sync (Self : in out Instance; Arg : in Data_Product.T);
   -- Events out (parameter-table-format rejections, table-applied
   -- notifications, Get_Copy-unsupported rejections).
   overriding procedure Event_T_Recv_Sync (Self : in out Instance; Arg : in Event.T);
   -- System time retrieval, used to timestamp events.
   overriding function Sys_Time_T_Return (Self : in out Instance) return Sys_Time.T;

   -----------------------------------------------
   -- Event handler primitive:
   -----------------------------------------------
   -- Description:
   --    Events for the OE State Ephem component.
   -- A parameter table was received that failed type-level validation (e.g.,
   -- an out-of-range Anomaly_Type in some arc). The bytes were rejected
   -- before deserialization. The Errant_Field value identifies the failing
   -- field by its packed-record field index. The table was not staged or
   -- applied.
   overriding procedure Invalid_Parameter_Table_Format (Self : in out Instance; Arg : in Packed_U32.T);
   -- A staged parameter table was drained and pushed to the C++ algorithm on this
   -- tick.
   overriding procedure Parameter_Table_Applied (Self : in out Instance);
   -- A Get_Copy operation was requested on the parameters memory region
   -- interface; the component does not support Get_Copy.
   overriding procedure Get_Copy_Not_Supported (Self : in out Instance);
   -- A Validate operation was requested on the parameters memory region
   -- interface; the component does not support Validate.
   overriding procedure Validate_Not_Supported (Self : in out Instance);

   -----------------------------------------------
   -- Data product handler primitives:
   -----------------------------------------------
   -- Description:
   --    Data products for the OE State Ephem component.
   -- Computed spacecraft Cartesian state (position and velocity) from Chebyshev
   -- orbital element fit.
   overriding procedure Ephemeris_State (Self : in out Instance; Arg : in Cartesian_State.T);

end Component.Oe_State_Ephem.Implementation.Tester;
