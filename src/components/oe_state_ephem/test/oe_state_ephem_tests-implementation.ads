--------------------------------------------------------------------------------
-- Oe_State_Ephem Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the OE State Ephem component.
package Oe_State_Ephem_Tests.Implementation is

   -- Test data and state:
   type Instance is new Oe_State_Ephem_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Zero coefficients and zero gravitational parameter (Init default) must produce
   -- zero Cartesian state.
   overriding procedure Test_Zero_Inputs (Self : in out Instance);
   -- Upload a single-arc Chebyshev fit via Set; the next tick applies it and the
   -- algorithm reconstructs a known circular equatorial orbit within 0.1 percent.
   overriding procedure Test_Cheby_Fit_Via_Set (Self : in out Instance);
   -- A memory region with an out-of-range Anomaly_Type is rejected before
   -- deserialization; release returns Parameter_Error and an
   -- Invalid_Parameter_Table_Format event fires.
   overriding procedure Test_Set_Invalid_Format (Self : in out Instance);
   -- A format-valid table that the algorithm's configuration rules reject (bad
   -- scalar, oversized arc count, or invalid arc) is refused synchronously on the
   -- upload (Parameter_Error plus an Invalid_Parameter_Table_Config event, nothing
   -- staged); the previously applied configuration is retained.
   overriding procedure Test_Set_Invalid_Config (Self : in out Instance);
   -- Validate is unsupported; release returns Parameter_Error and a
   -- Validate_Not_Supported event is emitted. No table is staged or applied.
   overriding procedure Test_Validate_Returns_Parameter_Error (Self : in out Instance);
   -- After a successful Set and applying tick, a subsequent Get_Pointer returns a
   -- region pointing at the staged buffer containing the current algorithm state;
   -- the bytes round-trip to the uploaded table.
   overriding procedure Test_Get_Pointer_Returns_Current_Table (Self : in out Instance);
   -- Get_Copy is unsupported on Oe_State_Ephem; release returns Parameter_Error
   -- and a Get_Copy_Not_Supported event is emitted. Callers must use Get_Pointer.
   overriding procedure Test_Get_Copy_Returns_Parameter_Error (Self : in out Instance);
   -- Get_Pointer always succeeds, even while a Set is staged. The dump buffer
   -- reflects the algorithm's current state; the staged Set is preserved and
   -- applies on the next tick.
   overriding procedure Test_Get_Pointer_Succeeds_While_Staged (Self : in out Instance);
   -- Dump_Buffer is overwritten on each Get_Pointer; back-to-back calls each
   -- reflect the algorithm's current state at the time of the call.
   overriding procedure Test_Get_Pointer_Reflects_Current_State (Self : in out Instance);
   -- Two Set calls without an intervening tick: only the latest table is
   -- applied. Mirrors the Generic_Staged_Variable "latest wins" contract.
   overriding procedure Test_Repeated_Set_Without_Tick (Self : in out Instance);

   -- Test data and state:
   type Instance is new Oe_State_Ephem_Tests.Base_Instance with record
      null;
   end record;
end Oe_State_Ephem_Tests.Implementation;
