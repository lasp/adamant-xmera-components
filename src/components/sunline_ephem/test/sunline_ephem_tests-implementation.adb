--------------------------------------------------------------------------------
-- Sunline_Ephem Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Nav_Att;
with Packed_F64x3;
with Packed_F32x3.Assertion; use Packed_F32x3.Assertion;

package body Sunline_Ephem_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Call component init here.
      Self.Tester.Component_Instance.Init;

      -- Call the component set up method that the assembly would normally call.
      Self.Tester.Component_Instance.Set_Up;
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
      T : Component.Sunline_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Test data based on Python test:
      -- Sun at origin, spacecraft at various positions, identity attitude
      type Test_Vector is record
         Sc_Position : Packed_F64x3.T;  -- Spacecraft position
         Expected_Sunline : Packed_F32x3.T;  -- Expected sunline direction (float)
      end record;

      Test_Cases : constant array (1 .. 7) of Test_Vector := [
         (Sc_Position => [-1.0, 0.0, 0.0], Expected_Sunline => [1.0, 0.0, 0.0]),
         (Sc_Position => [0.0, -1.0, 0.0], Expected_Sunline => [0.0, 1.0, 0.0]),
         (Sc_Position => [0.0, 0.0, -1.0], Expected_Sunline => [0.0, 0.0, 1.0]),
         (Sc_Position => [1.0, 0.0, 0.0], Expected_Sunline => [-1.0, 0.0, 0.0]),
         (Sc_Position => [0.0, 1.0, 0.0], Expected_Sunline => [0.0, -1.0, 0.0]),
         (Sc_Position => [0.0, 0.0, 1.0], Expected_Sunline => [0.0, 0.0, -1.0]),
         (Sc_Position => [0.0, 0.0, 0.0], Expected_Sunline => [0.0, 0.0, 0.0])  -- Degenerate case
      ];
   begin
      -- Run each test case
      for I in Test_Cases'Range loop
         -- Set sun ephemeris at origin
         T.Sun_Ephemeris := (
            R_Bdy_Zero_N => [0.0, 0.0, 0.0],
            V_Bdy_Zero_N => [0.0, 0.0, 0.0],
            Sigma_Bn => [0.0, 0.0, 0.0],
            Omega_Bn_B => [0.0, 0.0, 0.0],
            Time_Tag => 0.0
         );

         -- Set spacecraft position to test vector (Ephemeris type, wrapper converts to Nav_Trans)
         T.Spacecraft_Position := (
            R_Bdy_Zero_N => Test_Cases (I).Sc_Position,
            V_Bdy_Zero_N => [0.0, 0.0, 0.0],
            Sigma_Bn => [0.0, 0.0, 0.0],
            Omega_Bn_B => [0.0, 0.0, 0.0],
            Time_Tag => 0.0
         );

         -- Set spacecraft attitude to identity (no rotation)
         T.Spacecraft_Attitude := (
            Time_Tag => 0.0,
            Sigma_Bn => [0.0, 0.0, 0.0],
            Omega_Bn_B => [0.0, 0.0, 0.0],
            Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]
         );

         -- Call algorithm:
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));

         -- Make sure data product produced:
         Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, I);
         Natural_Assert.Eq (T.Sunline_Body_Frame_History.Get_Count, I);

         -- Check the sunline output (stored in vehSunPntBdy field)
         declare
            Output : constant Nav_Att.T := T.Sunline_Body_Frame_History.Get (I);
         begin
            Packed_F32x3_Assert.Eq (
               Output.Veh_Sun_Pnt_Bdy,
               Test_Cases (I).Expected_Sunline,
               Epsilon => 0.0001
            );
         end;
      end loop;
   end Test;

end Sunline_Ephem_Tests.Implementation;
