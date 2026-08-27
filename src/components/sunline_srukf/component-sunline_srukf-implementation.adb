--------------------------------------------------------------------------------
-- Sunline_Srukf Component Implementation Body
--------------------------------------------------------------------------------

with Css_Sensor_Values;
with Sunline_Srukf_Output;

package body Component.Sunline_Srukf.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sunline SRuKF component.
   overriding procedure Init (Self : in out Instance) is
      pragma Unreferenced (Self);
   begin
      -- Stateless pass-through, nothing to initialize.
      null;
   end Init;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the pass-through up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      Zero_Vector : constant Packed_F32x3.U := [0.0, 0.0, 0.0];

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      -- Body angular velocity (omega_BN_B) from body_rate_miscompare.
      Sc_Att : Packed_F32x3.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);

      -- Coarse sun sensor cosine measurements, fetched so that a wiring defect
      -- is still caught, but not used: the state this component publishes has
      -- no CSS-derived field.
      Css_Input : Css_Sensor_Values.T;
      Css_Input_Status : constant Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Css_Input, Stale_Reference => Arg.Time);
      pragma Assert (Css_Input_Status = Success);
      pragma Unreferenced (Css_Input);
   begin
      -- Publish the state. Only Omega_Bn_B has an upstream producer; Sigma_Bn,
      -- Veh_Sun_Pnt_Bdy and Time_Tag have none and are zeroed.
      Self.Data_Product_T_Send (Self.Data_Products.Sunline_Srukf_State (
         Arg.Time,
         Sunline_Srukf_Output.Pack ((
            Time_Tag        => 0.0,
            Sigma_Bn        => Zero_Vector,
            Omega_Bn_B      => Packed_F32x3.Unpack (Sc_Att),
            Veh_Sun_Pnt_Bdy => Zero_Vector
         ))
      ));
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Sunline SRuKF component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Sunline_Srukf.Implementation;
