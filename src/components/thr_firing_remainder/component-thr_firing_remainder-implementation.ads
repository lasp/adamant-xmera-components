--------------------------------------------------------------------------------
-- Thr_Firing_Remainder Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Packed_F32x36;
with Packed_F32x36.C;
with Tick;
with Thr_Firing_Remainder_Algorithm_C; use Thr_Firing_Remainder_Algorithm_C;

-- Thruster firing remainder algorithm converts thruster force commands to on-time
-- commands using pulse-width modulation with remainder tracking.
package Component.Thr_Firing_Remainder.Implementation is

   -- The component class instance record:
   type Instance is new Thr_Firing_Remainder.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster firing remainder algorithm.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);
   -- Configures the thruster geometry and maximum thrusts. MUST be called
   -- before the first tick: with unconfigured (zero) maximum thrusts the C
   -- algorithm's on-time division produces Inf (commanding a thruster
   -- full-on) or NaN. No parameter or data dependency supplies this
   -- configuration; the caller integrating this component into an assembly
   -- owns invoking it.
   not overriding procedure Configure_Thrusters (
      Self          : in out Instance;
      Num_Thrusters : in Unsigned_32;
      Max_Thrust    : in Packed_F32x36.U);

private

   -- The component class instance record:
   type Instance is new Thr_Firing_Remainder.Base_Instance with record
      Alg : Thr_Firing_Remainder_Algorithm_Access := null;
      -- The thruster array half of the algorithm configuration, held here as the
      -- Ada-side source of truth because the flattened shim exposes no getters.
      -- The defaults keep the initial configuration valid -- Num_Thrusters => 0
      -- skips the per-thruster maximum-thrust validation -- but the algorithm
      -- cannot produce usable on-times until Configure_Thrusters supplies the
      -- real maximum thrusts.
      Num_Thrusters : Unsigned_32 := 0;
      Max_Thrust : aliased Packed_F32x36.C.U_C := [others => 0.0];
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
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;
   -- This procedure is called when a Thr_On_Time_Cmd_T_Send message is dropped due to a full queue.
   overriding procedure Thr_On_Time_Cmd_T_Send_Dropped (Self : in out Instance; Arg : in Thr_On_Time_Cmd.T) is null;

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Thr Firing Remainder component

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
      Thr_Min_Fire_Time : in Packed_F32.U;
      Control_Period : in Packed_F32.U;
      On_Time_Saturation_Factor : in Packed_F32.U;
      Thrust_Pulsing_Regime : in Packed_Pulsing_Regime.U
   ) return Parameter_Validation_Status.E;

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Thr Firing Remainder component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Thr_Firing_Remainder.Implementation;
