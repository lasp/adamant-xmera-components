--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Packed_F32x3_Record;
with Inertial_3d_Algorithm_C; use Inertial_3d_Algorithm_C;

-- Inertial 3D algorithm produces a fixed inertial attitude reference message. The
-- reference attitude is immutable algorithm configuration, supplied as a data
-- dependency and pushed into the algorithm only when it changes.
package Component.Inertial_3d.Implementation is

   -- The component class instance record:
   type Instance is new Inertial_3d.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Inertial_3d.Base_Instance with record
      Alg : Inertial_3d_Algorithm_Access := null;
      -- The reference attitude currently held by the algorithm. The flattened shim
      -- exposes no getters, so the component tracks it here to tell a changed
      -- dependency value from an unchanged one. The zero default matches the
      -- configuration Init constructs the algorithm with.
      Applied_Sigma_Reference : Packed_F32x3_Record.T := (Value => [0.0, 0.0, 0.0]);
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
   --    Data dependencies for the Inertial 3D component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Inertial_3d.Implementation;
