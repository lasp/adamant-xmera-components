--------------------------------------------------------------------------------
-- Inertial_3d Component Tester Body
--------------------------------------------------------------------------------

package body Component.Inertial_3d.Implementation.Tester is

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance) is
   begin
      Self.Attach_Tick_T_Request (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Tick_T_Service_Access);
      Self.Attach_Attitude_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Attitude_T_Recv_Sync_Access);
   end Connect;

end Component.Inertial_3d.Implementation.Tester;
