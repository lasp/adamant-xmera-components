--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Tester Body
--------------------------------------------------------------------------------

package body Component.Oe_State_Ephem.Implementation.Tester is

   ---------------------------------------
   -- Initialize heap variables:
   ---------------------------------------
   procedure Init_Base (Self : in out Instance) is
   begin
      -- Initialize tester heap:
      -- Connector histories:
      Self.Data_Product_T_Recv_Sync_History.Init (Depth => 100);
      Self.Event_T_Recv_Sync_History.Init (Depth => 100);
      Self.Sys_Time_T_Return_History.Init (Depth => 100);
      -- Event histories:
      Self.Invalid_Parameter_Table_Format_History.Init (Depth => 100);
      Self.Parameter_Table_Applied_History.Init (Depth => 100);
      Self.Invalid_Parameter_Table_Config_History.Init (Depth => 100);
      Self.Get_Copy_Not_Supported_History.Init (Depth => 100);
      Self.Validate_Not_Supported_History.Init (Depth => 100);
      -- Data product histories:
      Self.Ephemeris_State_History.Init (Depth => 100);
   end Init_Base;

   procedure Final_Base (Self : in out Instance) is
   begin
      -- Destroy tester heap:
      -- Connector histories:
      Self.Data_Product_T_Recv_Sync_History.Destroy;
      Self.Event_T_Recv_Sync_History.Destroy;
      Self.Sys_Time_T_Return_History.Destroy;
      -- Event histories:
      Self.Invalid_Parameter_Table_Format_History.Destroy;
      Self.Parameter_Table_Applied_History.Destroy;
      Self.Invalid_Parameter_Table_Config_History.Destroy;
      Self.Get_Copy_Not_Supported_History.Destroy;
      Self.Validate_Not_Supported_History.Destroy;
      -- Data product histories:
      Self.Ephemeris_State_History.Destroy;
   end Final_Base;

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance) is
   begin
      Self.Component_Instance.Attach_Data_Product_T_Send (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_T_Recv_Sync_Access);
      Self.Component_Instance.Attach_Event_T_Send (To_Component => Self'Unchecked_Access, Hook => Self.Event_T_Recv_Sync_Access);
      Self.Component_Instance.Attach_Sys_Time_T_Get (To_Component => Self'Unchecked_Access, Hook => Self.Sys_Time_T_Return_Access);
      Self.Attach_Tick_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Tick_T_Recv_Sync_Access);
      Self.Attach_Parameters_Memory_Region_T_Request (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Parameters_Memory_Region_T_Service_Access);
   end Connect;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- The data product invoker connector.
   overriding procedure Data_Product_T_Recv_Sync (Self : in out Instance; Arg : in Data_Product.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Data_Product_T_Recv_Sync_History.Push (Arg);
      -- Dispatch the data product to the correct handler:
      Self.Dispatch_Data_Product (Arg);
   end Data_Product_T_Recv_Sync;

   -- Events out (parameter-table-format rejections, table-applied
   -- notifications, Get_Copy-unsupported rejections).
   overriding procedure Event_T_Recv_Sync (Self : in out Instance; Arg : in Event.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Event_T_Recv_Sync_History.Push (Arg);
      -- Dispatch the event to the correct handler:
      Self.Dispatch_Event (Arg);
   end Event_T_Recv_Sync;

   -- System time retrieval, used to timestamp events.
   overriding function Sys_Time_T_Return (Self : in out Instance) return Sys_Time.T is
      -- Return the system time:
      To_Return : constant Sys_Time.T := Self.System_Time;
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Sys_Time_T_Return_History.Push (To_Return);
      return To_Return;
   end Sys_Time_T_Return;

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
   overriding procedure Invalid_Parameter_Table_Format (Self : in out Instance; Arg : in Packed_U32.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Invalid_Parameter_Table_Format_History.Push (Arg);
   end Invalid_Parameter_Table_Format;

   -- A staged parameter table was drained and pushed to the C++ algorithm on this
   -- tick.
   overriding procedure Parameter_Table_Applied (Self : in out Instance) is
      Arg : constant Natural := 0;
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Parameter_Table_Applied_History.Push (Arg);
   end Parameter_Table_Applied;

   -- A staged parameter table passed type-level validation but was rejected by the
   -- algorithm's own configuration validator; the previously applied configuration
   -- was kept.
   overriding procedure Invalid_Parameter_Table_Config (Self : in out Instance) is
      Arg : constant Natural := 0;
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Invalid_Parameter_Table_Config_History.Push (Arg);
   end Invalid_Parameter_Table_Config;

   -- A Get_Copy operation was requested on the parameters memory region
   -- interface; the component does not support Get_Copy. The request was
   -- rejected with Parameter_Error and this event was emitted.
   overriding procedure Get_Copy_Not_Supported (Self : in out Instance) is
      Arg : constant Natural := 0;
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Get_Copy_Not_Supported_History.Push (Arg);
   end Get_Copy_Not_Supported;

   -- A Validate operation was requested on the parameters memory region
   -- interface; the component does not support Validate. The request was
   -- rejected with Parameter_Error and this event was emitted.
   overriding procedure Validate_Not_Supported (Self : in out Instance) is
      Arg : constant Natural := 0;
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Validate_Not_Supported_History.Push (Arg);
   end Validate_Not_Supported;

   -----------------------------------------------
   -- Data product handler primitive:
   -----------------------------------------------
   -- Description:
   --    Data products for the OE State Ephem component.
   -- Computed spacecraft Cartesian state (position and velocity) from Chebyshev
   -- orbital element fit.
   overriding procedure Ephemeris_State (Self : in out Instance; Arg : in Cartesian_State.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Ephemeris_State_History.Push (Arg);
   end Ephemeris_State;

end Component.Oe_State_Ephem.Implementation.Tester;
