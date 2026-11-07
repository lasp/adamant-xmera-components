--------------------------------------------------------------------------------
-- Dv_Guidance Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Dv Guidance component
package Dv_Guidance_Tests.Implementation is
   -- Test data and state:
   type Instance is new Dv_Guidance_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Check the reference returned for the burn frame of the algorithm's Python
   -- reference test, with zero reference rates, to ensure the Ada to C to C++
   -- integration is sound, and that the stand-in frame serves before a burn frame
   -- is set.
   overriding procedure Test (Self : in out Instance);
   -- Ensure a newly set delta-V and preferred direction reach the reference on the
   -- next tick.
   overriding procedure Test_Burn_Frame_Update (Self : in out Instance);
   -- Ensure a staged burn frame the algorithm would reject is refused at validation
   -- and leaves the reference unchanged.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Dv_Guidance_Tests.Base_Instance with record
      null;
   end record;
end Dv_Guidance_Tests.Implementation;
