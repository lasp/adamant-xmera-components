--------------------------------------------------------------------------------
-- Inertial_3d Component Tester Spec
--------------------------------------------------------------------------------

-- Includes:
with Component.Inertial_3d_Reciprocal;

-- Inertial 3D algorithm produces a fixed inertial attitude reference message. The
-- algorithm holds the reference attitude as configuration and returns it
-- unchanged on every tick. The attitude arrives through a connector from the
-- component that commands the inertial-hold state, and reconfigures the algorithm
-- on receipt.
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

end Component.Inertial_3d.Implementation.Tester;
