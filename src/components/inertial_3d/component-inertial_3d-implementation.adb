--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref.C;
with Packed_F32x3_Record;
with Packed_F32x3_Record.C;

package body Component.Inertial_3d.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
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
      Sigma : Packed_F32x3_Record.T;
      Sigma_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sigma_Reference (Value => Sigma, Stale_Reference => Arg.Time);
      pragma Assert (Sigma_Status = Success);
   begin
      Set_Sigma_Rn (
         Self.Alg,
         Packed_F32x3_Record.C.To_C (Packed_F32x3_Record.Unpack (Sigma))
      );

      declare
         Attitude_Reference_C : constant Att_Ref.C.U_C := Update (Self.Alg);
      begin
         -- Send out data product:
         Self.Data_Product_T_Send (Self.Data_Products.Attitude_Reference (
            Arg.Time,
            Att_Ref.Pack (Att_Ref.C.To_Ada (Attitude_Reference_C))
         ));
      end;
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Inertial 3D component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Inertial_3d.Implementation;
