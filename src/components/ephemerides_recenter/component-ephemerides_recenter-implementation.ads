--------------------------------------------------------------------------------
-- Ephemerides_Recenter Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Ephemerides_Recenter_Algorithm_C; use Ephemerides_Recenter_Algorithm_C;

-- Ephemerides recenter component re-expresses up to four body ephemerides about
-- a new central body. Wraps the EphemeridesRecenterAlgorithm C++ algorithm via
-- its C shim.
package Component.Ephemerides_Recenter.Implementation is

   -- The component class instance record:
   type Instance is new Ephemerides_Recenter.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the ephemerides recenter algorithm with the new and previous
   -- central body SPICE IDs and the configured body list.
   --
   -- Init Parameters:
   -- New_Zero_Base_Id : Interfaces.Integer_32 - SPICE ID of the new central
   -- body about which all output ephemerides are expressed.
   -- Previous_Common_Zero_Base_Id : Interfaces.Integer_32 - SPICE ID of the
   -- previous common central body shared by every primary input ephemeris.
   -- Body_Count : Interfaces.Unsigned_32 - Number of configured bodies, in the
   -- range 1 .. 4.
   -- Body_0_Spice_Id : Interfaces.Integer_32 - SPICE ID of body 0.
   -- Body_0_Original_Central_Body_Id : Interfaces.Integer_32 - SPICE ID of
   -- body 0's original central body.
   -- Body_1_Spice_Id : Interfaces.Integer_32 - SPICE ID of body 1.
   -- Body_1_Original_Central_Body_Id : Interfaces.Integer_32 - SPICE ID of
   -- body 1's original central body.
   -- Body_2_Spice_Id : Interfaces.Integer_32 - SPICE ID of body 2.
   -- Body_2_Original_Central_Body_Id : Interfaces.Integer_32 - SPICE ID of
   -- body 2's original central body.
   -- Body_3_Spice_Id : Interfaces.Integer_32 - SPICE ID of body 3.
   -- Body_3_Original_Central_Body_Id : Interfaces.Integer_32 - SPICE ID of
   -- body 3's original central body.
   --
   overriding procedure Init (Self : in out Instance; New_Zero_Base_Id : in Interfaces.Integer_32; Previous_Common_Zero_Base_Id : in Interfaces.Integer_32; Body_Count : in Interfaces.Unsigned_32; Body_0_Spice_Id : in Interfaces.Integer_32; Body_0_Original_Central_Body_Id : in Interfaces.Integer_32; Body_1_Spice_Id : in Interfaces.Integer_32; Body_1_Original_Central_Body_Id : in Interfaces.Integer_32; Body_2_Spice_Id : in Interfaces.Integer_32; Body_2_Original_Central_Body_Id : in Interfaces.Integer_32; Body_3_Spice_Id : in Interfaces.Integer_32; Body_3_Original_Central_Body_Id : in Interfaces.Integer_32);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Ephemerides_Recenter.Base_Instance with record
      Alg : Ephemerides_Recenter_Algorithm_Access := null;
      Body_Count : Interfaces.Unsigned_32 := 0;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   -- Null method which can be implemented to provide some component
   -- set up code. This method is generally called by the assembly
   -- main.adb after all component initialization and tasks have been started.
   -- Some activities need to only be run once at startup, but cannot be run
   -- safely until everything is up and running, ie. command registration, initial
   -- data product updates. This procedure should be implemented to do these things
   -- if necessary.
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Ephemerides Recenter component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Ephemerides_Recenter.Implementation;
