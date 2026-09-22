--------------------------------------------------------------------------------
-- Mrp_Steering Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameter_Update;
with Mrp_Steering_Algorithm_C; use Mrp_Steering_Algorithm_C;

-- MRP steering attitude control law with integral feedback and reaction wheel
-- momentum compensation. Steers the body rate toward a saturated rate command
-- derived from the attitude error, and computes the commanded body torque from
-- the rate tracking error, the reference motion, and the reaction wheel speeds.
-- Wraps the MrpSteeringAlgorithm C++ algorithm via its C shim.
package Component.Mrp_Steering.Implementation is

   -- The component class instance record:
   type Instance is new Mrp_Steering.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the MRP steering algorithm with the control period and the default
   -- parameter values.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates. The rate error integral advances by this much per tick, so
   -- it must equal the rate at which the component is scheduled. Fixed by the
   -- assembly, so it is not a runtime parameter. The type keeps it greater than
   -- zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Mrp_Steering.Base_Instance with record
      Alg : Mrp_Steering_Algorithm_Access := null;
      -- [s] Time between two algorithm updates, supplied by the assembly at
      -- initialization. The default keeps the configuration valid for the generated
      -- parameter default check, which runs before Init.
      Control_Period : Basic_Types.Positive_Short_Float := 0.2;
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
   -- Zero the integral of the rate tracking error. Called on GNC state change so the
   -- integral does not carry over from the previous state.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
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
   --    Parameters for the Mrp Steering component.

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
   -- to be implemented here. This function is also called through Assert_Valid_Parameter_Defaults from Set_Id_Bases and from
   -- unit test setup, before the component is connected or initialized, to check the compiled-in default parameter values. The
   -- implementation must therefore be a pure function of the passed-in parameter values, with no dependence on Init state and
   -- no connector invocations.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Proportional_Gain_K1 : in Packed_F32.U;
      Cubic_Gain_K3 : in Packed_F32.U;
      Omega_Max : in Packed_F32.U;
      Ignore_Outer_Loop_Feedforward : in Packed_Boolean.U;
      Derivative_Gain_P : in Packed_F32.U;
      Integral_Gain_Ki : in Packed_F32.U;
      Integral_Limit : in Packed_F32.U;
      Known_Torque_Pnt_B_B : in Packed_F32x3.U;
      Inertia : in Packed_F32x9.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Rw_Inertias : in Packed_F32x4.U;
      Wheel_Availability : in Wheel_Availability_X4.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Mrp Steering component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Mrp_Steering.Implementation;
