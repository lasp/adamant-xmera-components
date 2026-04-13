--------------------------------------------------------------------------------
-- Sunline_Srukf Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att.C;
with Packed_F32x8;
with Sunline_Srukf_Input.C;
with Sunline_Srukf_Output.C;
with Sunline_Srukf_Algorithm_C; use Sunline_Srukf_Algorithm_C;

package body Component.Sunline_Srukf.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sunline SRuKF algorithm.
   overriding procedure Init (Self : in out Instance) is
      pragma Unreferenced (Self);
   begin
      -- Stateless algorithm, nothing to initialize.
      null;
   end Init;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      Sc_Att : Nav_Att.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);

      -- Coarse sun sensor cosine measurements (already converted upstream):
      Css_Cos_A : Packed_F32x8.T;
      Css_Cos_A_Status : constant Data_Dependency_Status.E :=
         Self.Get_Css_Cos_Values_A (Value => Css_Cos_A, Stale_Reference => Arg.Time);
      pragma Assert (Css_Cos_A_Status = Success);

      -- TODO: Css_Cos_Values_B is fetched but not yet forwarded to the
      -- algorithm. The A/B selection/merge policy will be added once the
      -- sunline SRuKF algorithm grows a CSS configuration interface.
      Css_Cos_B : Packed_F32x8.T;
      Css_Cos_B_Status : constant Data_Dependency_Status.E :=
         Self.Get_Css_Cos_Values_B (Value => Css_Cos_B, Stale_Reference => Arg.Time);
      pragma Assert (Css_Cos_B_Status = Success);
      pragma Unreferenced (Css_Cos_B);

      -- Convert to C types:
      Sc_Att_C : constant Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Sc_Att));

      -- Build algorithm input from nav att and CSS cosine data. The first
      -- 8 entries of Cos_Values hold the A-side CSS measurements; remaining
      -- entries are zero.
      Input_C : aliased Sunline_Srukf_Input.C.U_C := (
         Time_Tag        => Sc_Att_C.Time_Tag,
         Sigma_Bn        => Sc_Att_C.Sigma_Bn,
         Omega_Bn_B      => Sc_Att_C.Omega_Bn_B,
         Veh_Sun_Pnt_Bdy => Sc_Att_C.Veh_Sun_Pnt_Bdy,
         N_Css           => Css_Cos_A'Length,
         Cos_Values      => [
            0 => Css_Cos_A (0),
            1 => Css_Cos_A (1),
            2 => Css_Cos_A (2),
            3 => Css_Cos_A (3),
            4 => Css_Cos_A (4),
            5 => Css_Cos_A (5),
            6 => Css_Cos_A (6),
            7 => Css_Cos_A (7),
            others => 0.0
         ]
      );

      -- Call the C algorithm:
      Output_C : constant Sunline_Srukf_Output.C.U_C := Update_State (
         Input => Input_C'Unchecked_Access
      );
   begin
      -- Send out data product:
      Self.Data_Product_T_Send (Self.Data_Products.Sunline_Srukf_State (
         Arg.Time,
         Sunline_Srukf_Output.Pack (Sunline_Srukf_Output.C.To_Ada (Output_C))
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
