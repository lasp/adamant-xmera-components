--------------------------------------------------------------------------------
-- Inertial_3d Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Inertial_3d_Reciprocal;

-- Inertial 3D algorithm produces a fixed inertial attitude reference message. The
-- algorithm holds the reference attitude as configuration and returns it
-- unchanged on every tick. The attitude is a parameter, and the algorithm
-- validates it before it is applied.
package Component.Inertial_3d.Implementation.Tester is

   use Component.Inertial_3d_Reciprocal;
   -- Component class instance:
   type Instance is new Component.Inertial_3d_Reciprocal.Base_Instance with record
      -- The component instance under test:
      Component_Instance : aliased Component.Inertial_3d.Implementation.Instance;
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

end Component.Inertial_3d.Implementation.Tester;
