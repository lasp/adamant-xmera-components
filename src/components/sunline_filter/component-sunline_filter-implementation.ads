--------------------------------------------------------------------------------
-- Sunline_Filter Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Algorithm_Tick;
with Tick;
with Parameter_Update;
with Sunline_Filter_Algorithm_C; use Sunline_Filter_Algorithm_C;

-- Sunline filter. Estimates the sun direction in the body frame, the body rate,
-- and the coarse sun sensor intensity bias from the coarse sun sensor cosines and
-- the body rate with a square root unscented Kalman filter, and publishes the
-- estimate for the guidance algorithms. The filter state, the variance of each
-- state, and the residuals of each measurement are published as data products. The
-- filter keeps its own time base, which starts at the first measurement after it
-- is built or reset, and takes the time of each measurement from its data product.
-- Wraps the SunlineFilterAlgorithm C++ algorithm via its C shim.
package Component.Sunline_Filter.Implementation is

   -- The component class instance record:
   type Instance is new Sunline_Filter.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sunline filter with the default parameter values, which seed
   -- the filter state and covariance.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Sunline_Filter.Base_Instance with record
      Alg : Sunline_Filter_Algorithm_Access := null;
      -- The filter keeps time in seconds from an origin at zero: it anchors there when
      -- built or reset and propagates from the anchor to the current time. Handing it
      -- system time would make that first propagation span the whole mission, so the
      -- component gives it a time base of its own, in nanoseconds of system time: the
      -- timestamp of the first measurement after the filter is built or reset, of
      -- either kind. That measurement only sets the base, its data is not fed, and the
      -- filter propagates from it. Until it arrives the filter is held at time zero.
      -- TODO: This emulates a planned change to the algorithm, which will record the
      -- time of its first measurement, drop that measurement, and propagate from there
      -- on its own. Once the C++ filter does so, the epoch and first reading handling
      -- here goes away and the filter is handed system time directly.
      Epoch_Ns : Unsigned_64 := 0;
      Awaiting_First_Reading : Boolean := True;
      -- Timestamps of the last body rate and sun sensor products consumed by the
      -- filter. A product is consumed only when its timestamp has advanced past these,
      -- so one that has not been refreshed since the last tick, or since before a
      -- reset, is not consumed twice. They are also reported in the filter state
      -- product as the times of the last measurements.
      Last_Rate_Time_Ns : Unsigned_64 := 0;
      Last_Css_Time_Ns : Unsigned_64 := 0;
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
   -- Run the filter up to the tick's call time, folding in the coarse sun sensor and
   -- body rate readings that are new since the last tick.
   overriding procedure Algorithm_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Algorithm_Tick.T);
   -- Re-seed the filter state and covariance from the configured initial values and
   -- clear the pending measurements and residuals. The filter's time base restarts at
   -- the next measurement. The assembly fires this on every entry to the navigation
   -- state, where the filter is first put into use.
   overriding procedure Reset_Estimate_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- Clear the pending measurements and residuals, keeping the filter state and
   -- covariance. The filter's time base restarts at the next measurement. The assembly
   -- fires this on every transition between pointing states.
   overriding procedure Reset_Measurements_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
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
   --    Parameters for the Sunline Filter component. The process noise and the initial
   --    covariance are given by their diagonals, since the full matrices do not fit in
   --    a parameter.

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
      Alpha : in Packed_F64.U;
      Beta : in Packed_F64.U;
      Process_Noise_Diagonal : in Packed_F64x7.U;
      Initial_State : in Packed_F64x7.U;
      Initial_Covariance_Diagonal : in Packed_F64x7.U;
      Bias_Lower_Bound : in Packed_F64.U;
      Bias_Upper_Bound : in Packed_F64.U;
      Css_N_Hat_B : in Packed_F32x24.U;
      Css_Scale_Factor : in Packed_F64x8.U;
      Number_Of_Css : in Packed_U32.U;
      Sensor_Threshold : in Packed_F64.U;
      Css_Measurement_Noise_Std : in Packed_F64.U;
      Gyro_Measurement_Noise_Std : in Packed_F64.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Sunline Filter component. Each product is fed to the
   --    filter as a measurement when its timestamp has advanced since the last one
   --    consumed, so the timestamp is the measurement time.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Sunline_Filter.Implementation;
