--------------------------------------------------------------------------------
-- Sunline_Ephem Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att.C;
with Nav_Trans.C;
with Ephemeris;
with Ephemeris.C;

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
      Sun_Eph : Ephemeris.T;
      Sun_Eph_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sun_Ephemeris (Value => Sun_Eph, Stale_Reference => Arg.Time);
      pragma Assert (Sun_Eph_Status = Success);
      Sc_Pos_Eph : Ephemeris.T;
      Sc_Pos_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Position (Value => Sc_Pos_Eph, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Pos_Status = Success);
      Sc_Att : Nav_Att.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);

      -- Convert to C types:
      Sun_Eph_C : aliased Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Sun_Eph));
      -- Convert Ephemeris to Nav_Trans for the C algorithm:
      Sc_Pos_Eph_C : constant Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Sc_Pos_Eph));
      Sc_Pos_C : aliased Nav_Trans.C.U_C := (
         Time_Tag => Sc_Pos_Eph_C.Time_Tag,
         R_Bn_N => Sc_Pos_Eph_C.R_Bdy_Zero_N,
         V_Bn_N => Sc_Pos_Eph_C.V_Bdy_Zero_N,
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
