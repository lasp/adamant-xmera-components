--------------------------------------------------------------------------------
-- Dv_Guidance Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Att_Ref;
with Tick;
with Parameter_Update;
with Packed_F32x3;
with Dv_Guidance_Algorithm_C; use Dv_Guidance_Algorithm_C;

-- Delta-V guidance. Produces the inertially fixed attitude reference for a
-- delta-V burn. The burn frame has its third axis along the commanded delta-V and
-- its second axis as close as possible to a preferred direction. Both are
-- parameters, set by the state manager when a burn is commanded, so the reference
-- attitude is a constant between burn commands and the reference rate and
-- acceleration are zero. The algorithm validates the frame before it is applied.
-- A rotation about the burn axis, when wanted, is applied by a downstream
-- reference rotation taking this reference as its base. Wraps the
-- DvGuidanceAlgorithm C++ algorithm via its C shim.
package Component.Dv_Guidance.Implementation is

   -- The component class instance record:
   type Instance is new Dv_Guidance.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V guidance algorithm with the default parameter values, a
   -- stand-in burn frame which the first burn command replaces.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Dv_Guidance.Base_Instance with record
      Alg : Dv_Guidance_Algorithm_Access := null;
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
   -- Run the algorithm up to the current time and return the attitude reference it
   -- produces.
   overriding function Tick_T_Service (Self : in out Instance; Arg : in Tick.T) return Att_Ref.T;
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Dv Guidance component. Together they define the burn
   --    frame, so they are set when a burn is commanded. The defaults form a valid
   --    frame and stand in until then.

   -- Invalid parameter handler. This procedure is called when a parameter's type is found to be invalid:
   -- Null: the staging code rejects the value and returns an error status to the
   -- requester, which reports the offending parameter ID to the ground. That is sufficient, and
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
      Cmd_Dv_N : in Packed_F32x3.U;
      R_Hat_Pref_N : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E;

end Component.Dv_Guidance.Implementation;
