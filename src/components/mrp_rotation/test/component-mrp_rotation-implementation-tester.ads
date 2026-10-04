--------------------------------------------------------------------------------
-- Mrp_Rotation Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Mrp_Rotation_Reciprocal;

-- MRP rotation attitude guidance. Superimposes a constant rate rotation on an
-- input attitude reference frame, advancing the rotation by one control period
-- each tick, and returns the resulting reference attitude, rate, and
-- acceleration. Wraps the MrpRotationAlgorithm C++ algorithm via its C shim.
package Component.Mrp_Rotation.Implementation.Tester is

   use Component.Mrp_Rotation_Reciprocal;
   -- Component class instance:
   type Instance is new Component.Mrp_Rotation_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Mrp_Rotation.Implementation.Instance;
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

end Component.Mrp_Rotation.Implementation.Tester;
