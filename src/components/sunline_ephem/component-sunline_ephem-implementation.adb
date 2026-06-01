--------------------------------------------------------------------------------
-- Sunline_Ephem Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att.C;
with Nav_Trans.C;
with Ephemeris.C;
with Cartesian_State;
with Cartesian_State.C;

package body Component.Sunline_Ephem.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sunline ephemeris algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

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
      Sun_State : Cartesian_State.T;
      Sun_State_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sun_Ephemeris (Value => Sun_State, Stale_Reference => Arg.Time);
      pragma Assert (Sun_State_Status = Success);
      Sc_Pos : Cartesian_State.T;
      Sc_Pos_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Position (Value => Sc_Pos, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Pos_Status = Success);
      Sc_Att : Nav_Att.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);

      -- Convert to C types:
      -- The C algorithm only reads the sun's position (r_BdyZero_N). Build an
      -- Ephemeris payload with position populated from the Cartesian state and
      -- the unused fields zeroed.
      Sun_State_C : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Sun_State));
      Sun_Eph_C : aliased Ephemeris.C.U_C := (
         R_Bdy_Zero_N => Sun_State_C.Position,
         V_Bdy_Zero_N => [others => 0.0],
         Sigma_Bn => [others => 0.0],
         Omega_Bn_B => [others => 0.0],
         Time_Tag => 0.0);
      -- Lift Cartesian_State to Nav_Trans for the C algorithm. Time_Tag is
      -- the current tick time (Cartesian_State has no Time_Tag of its own).
      Sc_Pos_C_Cartesian : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Sc_Pos));
      Sc_Pos_C : aliased Nav_Trans.C.U_C := (
         Time_Tag => Long_Float (Arg.Time.Seconds) + Long_Float (Arg.Time.Subseconds) / 65536.0,
         R_Bn_N => Sc_Pos_C_Cartesian.Position,
         V_Bn_N => Sc_Pos_C_Cartesian.Velocity,
         Vehaccumdv => [others => 0.0]);
      Sc_Att_C : aliased Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Sc_Att));

      -- Call algorithm update.
      Sunline : constant Nav_Att.C.U_C := Update (
         Self.Alg,
         Sun_Pos => Sun_Eph_C'Unchecked_Access,
         Sc_Pos => Sc_Pos_C'Unchecked_Access,
         Sc_Att => Sc_Att_C'Unchecked_Access
      );
   begin
      -- Send out data product:
      Self.Data_Product_T_Send (Self.Data_Products.Sunline_Body_Frame (
         Arg.Time,
         Nav_Att.Pack (Nav_Att.C.To_Ada (Sunline))
      ));
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Sunline Ephem component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Sunline_Ephem.Implementation;
