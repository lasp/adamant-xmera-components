--------------------------------------------------------------------------------
-- Sunline_Ephem Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att_Output;
with Nav_Att_Output.C;
with Cartesian_State;
with Cartesian_State.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_F64x3_Record.C;

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
      Sc_Att : Nav_Att_Output.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);

      -- Convert to the narrow C vectors the algorithm consumes: the sun and
      -- spacecraft inertial positions (r_SN_N, r_BN_N) and the attitude MRP
      -- (sigma_BN). Nothing else is needed.
      Sun_State_C : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Sun_State));
      Sc_Pos_C_Cartesian : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Sc_Pos));
      Sc_Att_C : constant Nav_Att_Output.C.U_C := Nav_Att_Output.C.To_C (Nav_Att_Output.Unpack (Sc_Att));

      Sun_R    : aliased Packed_F64x3_Record.C.U_C := (Value => Sun_State_C.Position);
      Sc_R     : aliased Packed_F64x3_Record.C.U_C := (Value => Sc_Pos_C_Cartesian.Position);
      Sigma_C  : aliased Packed_F32x3_Record.C.U_C := (Value => Sc_Att_C.Sigma_Bn);
      Sunline  : aliased Packed_F32x3_Record.C.U_C;
   begin
      -- Call algorithm update: all vectors passed by reference, result written
      -- into Sunline (avoids by-value struct passing across the C boundary).
      Update (
         Self.Alg,
         Sun_Pos  => Sun_R'Unchecked_Access,
         Sc_Pos   => Sc_R'Unchecked_Access,
         Sigma_Bn => Sigma_C'Unchecked_Access,
         Result   => Sunline'Unchecked_Access
      );
      -- Send out data product:
      Self.Data_Product_T_Send (Self.Data_Products.Sunline_Body_Frame (
         Arg.Time,
         Packed_F32x3.C.Pack (Sunline.Value)
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
