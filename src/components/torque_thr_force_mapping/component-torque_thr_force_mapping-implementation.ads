--------------------------------------------------------------------------------
-- Torque_Thr_Force_Mapping Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameter_Update;
with Force_Torque_Thr_Force_Mapping_Algorithm_C; use Force_Torque_Thr_Force_Mapping_Algorithm_C;

-- Torque thruster force mapping converts a commanded body torque into per-
-- thruster force commands using the truncated-SVD pseudo-inverse of the thruster
-- control mapping matrix. It is the force torque thruster force mapping with the
-- commanded force fixed at zero, for states that change the attitude without a
-- delta-v. Wraps the ForceTorqueThrForceMappingAlgorithm C++ algorithm via its C
-- shim.
package Component.Torque_Thr_Force_Mapping.Implementation is

   -- The component class instance record:
   type Instance is new Torque_Thr_Force_Mapping.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster force mapping algorithm with the default parameter
   -- values.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Torque_Thr_Force_Mapping.Base_Instance with record
      Alg : Force_Torque_Thr_Force_Mapping_Algorithm_Access := null;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   -- Null method which can be implemented to provide some component
   -- set up code. This method is generally called by the assembly
   -- main.adb after all component initialization and tasks have been started.
   -- Some activities need to only be run once at startup, but cannot be run
   -- safely until everything is up and running, i.e. command registration, initial
   -- data product updates. This procedure should be implemented to do these things
   -- if necessary.
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Torque Thr Force Mapping component. They are the same as the
   --    force torque thruster force mapping parameters, since both components configure
   --    the same algorithm.

   -- Invalid parameter handler. This procedure is called when a parameter's type is found to be invalid:
   -- Null: the staging code rejects the value and returns an error status to the Parameters
   -- component, which reports the offending parameter ID to the ground. That is sufficient, and
   -- we avoid adding per-component event overhead to these algorithm components.
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is null;
   -- This procedure is called when the parameters of a component have been updated. The default implementation of this
   -- subprogram in the implementation package is a null procedure. However, this procedure can, and should be implemented if
   -- something special needs to happen after a parameter update. Examples of this might be copying certain parameters to
   -- hardware registers, or performing other special functionality that only needs to be performed after parameters have
   -- been updated.
   overriding procedure Update_Parameters_Action (Self : in out Instance);
   -- This function is called when the parameter operation type is "Validate". The default implementation of this
   -- subprogram in the implementation package is a function that returns "Valid". However, this function can, and should be
   -- overridden if something special needs to happen to further validate a parameter. Examples of this might be validation of
   -- certain parameters beyond individual type ranges, or performing other special functionality that only needs to be
   -- performed after parameters have been validated. Note that range checking is performed during staging, and does not need
   -- to be implemented here.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Num_Thrusters : in Packed_U32.U;
      R_Thruster_B : in Packed_F32x24.U;
      T_Hat_Thruster_B : in Packed_F32x24.U;
      Center_Of_Mass_B : in Packed_F32x3.U;
      Desired_Control_Axes_B : in Desired_Control_Axes.U;
      Thruster_Availability : in Thruster_Availability_X8.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Torque Thr Force Mapping component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Torque_Thr_Force_Mapping.Implementation;
