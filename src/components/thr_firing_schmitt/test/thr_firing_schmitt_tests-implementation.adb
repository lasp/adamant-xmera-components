--------------------------------------------------------------------------------
-- Thr_Firing_Schmitt Tests Body
--------------------------------------------------------------------------------

package body Thr_Firing_Schmitt_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Component Init will be called manually in test body
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      -- Free component heap:
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- Run algorithm to ensure integration is sound.
   overriding procedure Test (Self : in out Instance) is
      T : Component.Thr_Firing_Schmitt.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      -- Scaffolding smoke test: bring the component through its initialization
      -- lifecycle to verify the test harness, Ada-to-C bindings, and algorithm
      -- allocation are sound. Tear_Down_Test handles the matching Destroy.
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;
   end Test;

end Thr_Firing_Schmitt_Tests.Implementation;
