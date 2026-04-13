--------------------------------------------------------------------------------
-- Sun_Search Component Implementation Body
--------------------------------------------------------------------------------

with Interfaces;
with Nav_Att.C;
with Att_Guid.C;
with Principal_Inertias.C;
with Slew_Properties.C;

package body Component.Sun_Search.Implementation is

   Nanoseconds_Per_Second : constant Interfaces.Unsigned_64 := 1_000_000_000;
   Subsecond_Divisor      : constant Interfaces.Unsigned_64 := 2 ** 16;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the sun search algorithm.
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
      Sc_Att : Nav_Att.T;
      Sc_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_Attitude (Value => Sc_Att, Stale_Reference => Arg.Time);
      pragma Assert (Sc_Att_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call algorithm:
      declare
         -- Convert Ada types to C types:
         Sc_Att_C : aliased Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Sc_Att));

         -- Call the C algorithm:
         Att_Guid_Output : constant Att_Guid.C.U_C := Update (
            Self.Alg,
            Current_Sim_Nanos =>
              Interfaces.Unsigned_64 (Arg.Time.Seconds) * Nanoseconds_Per_Second +
              Interfaces.Unsigned_64 (Arg.Time.Subseconds) * Nanoseconds_Per_Second / Subsecond_Divisor,
            Nav_Att_In => Sc_Att_C'Unchecked_Access
         );
      begin
         -- Send out data product:
         Self.Data_Product_T_Send (Self.Data_Products.Attitude_Guidance (
            Arg.Time,
            Att_Guid.Pack (Att_Guid.C.To_Ada (Att_Guid_Output))
         ));
      end;
   end Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- This procedure is called when the parameters of a component have been updated. The default implementation of this
   -- subprogram in the implementation package is a null procedure. However, this procedure can, and should be implemented if
   -- something special needs to happen after a parameter update. Examples of this might be copying certain parameters to
   -- hardware registers, or performing other special functionality that only needs to be performed after parameters have
   -- been updated.
   --
   -- In this case we need to reset the algorithm with the inertia and configure the slew maneuvers.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- Convert principal inertia parameter to C type for the algorithm:
      Principal_Inertia_C : aliased Principal_Inertias.C.U_C :=
         Principal_Inertias.C.To_C (Self.Spacecraft_Inertia);
   begin
      -- Configure the three slew maneuvers first (required before reset):
      if not Self.Slews_Configured then
         -- First time: use Set_Slew_Properties to add slews
         -- Parameters are stored as unpacked type U, convert to C type and pass by reference
         declare
            Slew_1_C : aliased Slew_Properties.C.U_C := Slew_Properties.C.To_C (Self.Slew_1_Properties);
            Slew_2_C : aliased Slew_Properties.C.U_C := Slew_Properties.C.To_C (Self.Slew_2_Properties);
            Slew_3_C : aliased Slew_Properties.C.U_C := Slew_Properties.C.To_C (Self.Slew_3_Properties);
         begin
            Set_Slew_Properties (Self.Alg, Slew_1_C'Access);
            Set_Slew_Properties (Self.Alg, Slew_2_C'Access);
            Set_Slew_Properties (Self.Alg, Slew_3_C'Access);
         end;
         Self.Slews_Configured := True;
      else
         -- Subsequent times: use Modify_Slew_Properties to update existing slews
         declare
            Slew_1_C : aliased Slew_Properties.C.U_C := Slew_Properties.C.To_C (Self.Slew_1_Properties);
            Slew_2_C : aliased Slew_Properties.C.U_C := Slew_Properties.C.To_C (Self.Slew_2_Properties);
            Slew_3_C : aliased Slew_Properties.C.U_C := Slew_Properties.C.To_C (Self.Slew_3_Properties);
         begin
            Modify_Slew_Properties (Self.Alg, Slew_1_C'Access, 0);
            Modify_Slew_Properties (Self.Alg, Slew_2_C'Access, 1);
            Modify_Slew_Properties (Self.Alg, Slew_3_C'Access, 2);
         end;
      end if;

      -- Reset algorithm with principal inertia terms:
      Reset (Self.Alg, Current_Sim_Nanos => 0, Principle_Inertia => Principal_Inertia_C'Unchecked_Access);
   end Update_Parameters_Action;

   -- Description:
   --    Parameters for the Sun Search component
   -- Invalid Parameter handler. This procedure is called when a parameter's type is found to be invalid:
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the parameters should be invalid in this case.
      pragma Assert (False);
   end Invalid_Parameter;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Sun Search component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Sun_Search.Implementation;
