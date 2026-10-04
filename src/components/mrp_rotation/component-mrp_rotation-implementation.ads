--------------------------------------------------------------------------------
-- Mrp_Rotation Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Att_Ref;
with Att_Ref_Tick;
with Parameter_Update;
with Mrp_Rotation_Algorithm_C; use Mrp_Rotation_Algorithm_C;

-- MRP rotation attitude guidance. Superimposes a constant rate rotation on an
-- input attitude reference frame, advancing the rotation by one control period
-- each tick, and returns the resulting reference attitude, rate, and
-- acceleration. Wraps the MrpRotationAlgorithm C++ algorithm via its C shim.
package Component.Mrp_Rotation.Implementation is

   -- The component class instance record:
   type Instance is new Mrp_Rotation.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the MRP rotation algorithm with the control period and the default
   -- parameter values.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates. The rotation advances by this much per tick, so it must
   -- equal the rate at which the component is scheduled. Fixed by the assembly, so
   -- it is not a runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Mrp_Rotation.Base_Instance with record
      Alg : Mrp_Rotation_Algorithm_Access := null;
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
   -- Rotate the attitude reference in the argument by the configured rotation,
   -- advanced to the tick in the argument, and return the result.
   overriding function Att_Ref_Tick_T_Service (Self : in out Instance; Arg : in Att_Ref_Tick.T) return Att_Ref.T;
   -- Restart the rotation from the configured initial attitude. Called on GNC state
   -- change so the rotation does not carry over from the previous state.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Mrp Rotation component.

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
      Initial_Sigma_Rr0 : in Packed_F32x3.U;
      Omega_Rr0_R : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E;

end Component.Mrp_Rotation.Implementation;
