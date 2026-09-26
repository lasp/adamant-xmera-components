--------------------------------------------------------------------------------
-- Inertial_Filter Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Algorithm_Tick;
with Tick;
with Parameter_Update;
with Inertial_Filter_Algorithm_C; use Inertial_Filter_Algorithm_C;

-- Inertial attitude filter. Estimates the body attitude and body rate from the
-- star tracker attitude and rate with a square root unscented Kalman filter, and
-- publishes the estimate for the guidance and control algorithms. The filter
-- state, the variance of each state, and the residuals of each measurement are
-- published as data products. The filter keeps its own time base, which starts
-- at the first star tracker reading after it is built or reset, so the star
-- tracker time tag and the tick's call time must be on the same clock. Wraps the
-- InertialFilterAlgorithm C++ algorithm via its C shim.
package Component.Inertial_Filter.Implementation is

   -- The component class instance record:
   type Instance is new Inertial_Filter.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial filter with the default parameter values, which seed
   -- the filter state and covariance.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Inertial_Filter.Base_Instance with record
      Alg : Inertial_Filter_Algorithm_Access := null;
      -- The filter keeps time in seconds from an origin at zero: it anchors there when
      -- built or reset and propagates from the anchor to the current time. Handing it
      -- system time would make that first propagation span the whole mission, so the
      -- component gives it a time base of its own, in nanoseconds of system time: the
      -- time tag of the first star tracker reading after the filter is built or reset.
      -- That reading only sets the base, its data is not fed, and the filter propagates
      -- from it. Until it arrives the filter is held at time zero.
      -- TODO: This emulates a planned change to the algorithm, which will record the
      -- time of its first measurement, drop that measurement, and propagate from there
      -- on its own. Once the C++ filter does so, the epoch and first reading handling
      -- here goes away and the filter is handed system time directly.
      Epoch_Ns : Unsigned_64 := 0;
      Awaiting_First_Reading : Boolean := True;
      -- Time tag of the last star tracker reading consumed by the filter. A reading is
      -- consumed only when its time tag has advanced past this one, so a product that
      -- has not been refreshed since the last tick, or since before a reset, is not
      -- consumed twice. It is also reported in the filter state product as the time of
      -- the last measurement.
      Last_St_Time_Tag : Unsigned_64 := 0;
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
   -- Run the filter up to the tick's call time, folding in a fresh star tracker
   -- reading when there is one.
   overriding procedure Algorithm_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Algorithm_Tick.T);
   -- Re-seed the filter state and covariance from the configured initial values and
   -- clear the pending measurements and residuals. The filter's time base restarts at
   -- the next star tracker reading. The assembly fires this on every entry to the
   -- navigation state, where the filter is first put into use.
   overriding procedure Reset_Estimate_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- Clear the pending measurements and residuals, keeping the filter state and
   -- covariance. The filter's time base restarts at the next star tracker reading. The
   -- assembly fires this on every transition between pointing states.
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
   --    Parameters for the Inertial Filter component. The process noise and the initial
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
      Process_Noise_Diagonal : in Packed_F64x6.U;
      Initial_State : in Packed_F64x6.U;
      Initial_Covariance_Diagonal : in Packed_F64x6.U;
      St_Measurement_Noise_Std : in Packed_F64.U;
      Rate_Measurement_Noise_Std : in Packed_F64.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Inertial Filter component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Inertial_Filter.Implementation;
