--------------------------------------------------------------------------------
-- Css_Weighted_Least_Squares Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Parameter_Update;
with Css_Weighted_Least_Squares_Algorithm_C; use Css_Weighted_Least_Squares_Algorithm_C;

-- Coarse sun sensor weighted least squares estimator. Fits a unit sun heading in
-- the body frame to the cosine readings of the coarse sun sensor constellation
-- and differences successive headings into a body rate. Wraps the
-- CssWeightedLeastSquaresAlgorithm C++ algorithm via its C shim.
package Component.Css_Weighted_Least_Squares.Implementation is

   -- The component class instance record:
   type Instance is new Css_Weighted_Least_Squares.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the estimator with the control period and the default parameter
   -- values.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates. The body rate is the change in heading over this much time,
   -- so it must equal the rate at which the component is scheduled. Fixed by the
   -- assembly, so it is not a runtime parameter. The type keeps it greater than
   -- zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Css_Weighted_Least_Squares.Base_Instance with record
      Alg : Css_Weighted_Least_Squares_Algorithm_Access := null;
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
   -- Discard the prior heading so no rate is produced until two headings have been
   -- observed again. Called on GNC state change so a heading from the previous state
   -- is not differenced into a rate.
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
   --    Parameters for the Css Weighted Least Squares component.

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
      Css_N_Hat_B : in Packed_F32x24.U;
      Css_Availability : in Css_Availability_X8.U;
      Use_Measurements_As_Weights : in Packed_Boolean.U;
      Sensor_Use_Thresh : in Packed_F32.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Css Weighted Least Squares component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Css_Weighted_Least_Squares.Implementation;
