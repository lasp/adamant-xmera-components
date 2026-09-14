--------------------------------------------------------------------------------
-- Force_Torque_Thr_Force_Mapping Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Force Torque Thr Force Mapping component
package Force_Torque_Thr_Force_Mapping_Tests.Implementation is

   -- Test data and state:
   type Instance is new Force_Torque_Thr_Force_Mapping_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- A commanded torque about each body axis is reproduced by the mapped thruster
   -- forces.
   overriding procedure Test_Pure_Torque (Self : in out Instance);
   -- A commanded force along each body axis is reproduced by the mapped thruster
   -- forces.
   overriding procedure Test_Pure_Force (Self : in out Instance);
   -- A simultaneous force and torque command is reproduced by the mapped thruster
   -- forces.
   overriding procedure Test_Combined_Force_And_Torque (Self : in out Instance);
   -- A zero force and torque command produces zero thruster force on every thruster.
   overriding procedure Test_Zero_Command (Self : in out Instance);
   -- Every mapped thruster force is non negative and at least one is zero.
   overriding procedure Test_Min_Shift (Self : in out Instance);
   -- Applying a new thruster geometry changes the mapping used on the next tick.
   overriding procedure Test_Parameter_Update (Self : in out Instance);
   -- A configuration the algorithm rejects is refused at parameter staging.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Force_Torque_Thr_Force_Mapping_Tests.Base_Instance with record
      null;
   end record;
end Force_Torque_Thr_Force_Mapping_Tests.Implementation;
