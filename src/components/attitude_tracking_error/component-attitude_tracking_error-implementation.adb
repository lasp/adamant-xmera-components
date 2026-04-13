--------------------------------------------------------------------------------
-- Attitude_Tracking_Error Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att.C;
with Att_Ref.C;
with Att_Guid.C;
with Packed_F32x3_Record.C;

package body Component.Attitude_Tracking_Error.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes static configuration for algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;

      -- TODO how should sigma_R0R actually be set?
      declare
         Sigma_Set : constant Packed_F32x3_Record.C.U_C := (Value => [0.01, 0.05, -0.55]);
      begin
         Set_Sigma_R0R (Self.Alg, Sigma_Set);
      end;
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
      use Nav_Att.C;
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      Ref : Att_Ref.T;
      Ref_Status : constant Data_Dependency_Status.E :=
         Self.Get_Attitude_Reference (Value => Ref, Stale_Reference => Arg.Time);
      pragma Assert (Ref_Status = Success);
      Nav : Nav_Att.T;
      Nav_Status : constant Data_Dependency_Status.E :=
         Self.Get_Navigation_Attitude (Value => Nav, Stale_Reference => Arg.Time);
      pragma Assert (Nav_Status = Success);

      -- Convert to C types and call algorithm:
      Ref_C : aliased Att_Ref.C.U_C := Att_Ref.C.To_C (Att_Ref.Unpack (Ref));
      Nav_C : aliased Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Nav));
      Guid : constant Att_Guid.C.U_C := Update (
         Self.Alg,
         Att_Ref_In => Ref_C'Unchecked_Access,
         Att_Nav_In => Nav_C'Unchecked_Access
      );
   begin
      -- Send out data product:
      Self.Data_Product_T_Send (Self.Data_Products.Attitude_Guidance (
         Arg.Time,
         Att_Guid.Pack (Att_Guid.C.To_Ada (Guid))
      ));
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Attitude Tracking Error component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Attitude_Tracking_Error.Implementation;
