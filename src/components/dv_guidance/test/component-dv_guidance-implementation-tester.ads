--------------------------------------------------------------------------------
-- Dv_Guidance Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Dv_Guidance_Reciprocal;

-- Delta-V guidance. Produces the inertially fixed attitude reference for a
-- delta-V burn. The burn frame has its third axis along the commanded delta-V and
-- its second axis as close as possible to a preferred direction. Both are
-- parameters, set by the state manager when a burn is commanded, so the reference
-- attitude is a constant between burn commands and the reference rate and
-- acceleration are zero. The algorithm validates the frame before it is applied.
-- A rotation about the burn axis, when wanted, is applied by a downstream
-- reference rotation taking this reference as its base. Wraps the
-- DvGuidanceAlgorithm C++ algorithm via its C shim.
package Component.Dv_Guidance.Implementation.Tester is

   use Component.Dv_Guidance_Reciprocal;
   -- Component class instance:
   type Instance is new Component.Dv_Guidance_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Dv_Guidance.Implementation.Instance;
   end record;
   type Instance_Access is access all Instance;

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance);

   -----------------------------------------------
   -- Special primitives for aiding in the staging,
   -- fetching, and updating of parameters
   -----------------------------------------------
   -- Stage a parameter value within the component
   not overriding function Stage_Parameter (Self : in out Instance; Par : in Parameter.T) return Parameter_Update_Status.E;
   -- Fetch the value of a parameter with the component
   not overriding function Fetch_Parameter (Self : in out Instance; Id : in Parameter_Types.Parameter_Id; Par : out Parameter.T) return Parameter_Update_Status.E;
   -- Ask the component to validate all parameters. This will call the
   -- Validate_Parameters subprogram within the component implementation,
   -- which allows custom checking of the parameter set prior to updating.
   not overriding function Validate_Parameters (Self : in out Instance) return Parameter_Update_Status.E;
   -- Tell the component it is OK to atomically update all of its
   -- working parameter values with the staged values.
   not overriding function Update_Parameters (Self : in out Instance) return Parameter_Update_Status.E;

end Component.Dv_Guidance.Implementation.Tester;
