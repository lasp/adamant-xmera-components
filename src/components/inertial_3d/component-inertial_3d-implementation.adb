--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Inertial_3d.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
   overriding procedure Init (Self : in out Instance) is
      -- The reference attitude arrives as a data dependency, which cannot be
      -- fetched until the assembly is running. Construct the algorithm with the
      -- zero MRP so a tick landing before the first fetch still produces
      -- deterministic output. Applied_Sigma_Reference carries the same value, so
      -- the first fetch of a non-zero attitude is correctly seen as a change.
      Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.Unpack (Self.Applied_Sigma_Reference);
   begin
      -- Create throws on an invalid configuration. The zero MRP is a valid one, so
      -- this asserts a property of the default rather than checking runtime input.
      pragma Assert (Validate_Config (Sigma_Rn => Sigma_Rn_C));
      Self.Alg := Create (Sigma_Rn => Sigma_Rn_C);
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
      -- Change detection below compares the packed representations directly, which
      -- is bitwise identity of the MRP -- exactly the question being asked.
      use type Packed_F32x3_Record.T;

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
      -- The algorithm holds the reference attitude as immutable configuration, so
      -- reconfigure only when the fetched value has actually moved. Re-pushing an
      -- unchanged attitude would be a pointless trip across the FFI boundary.
      if Sigma /= Self.Applied_Sigma_Reference then
         declare
            Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C := Packed_F32x3_Record.C.Unpack (Sigma);
         begin
            -- Set_Config throws on an invalid configuration, so gate it on the
            -- algorithm's own non-throwing predicate. This has to be an "if" rather
            -- than an assertion: a non-finite MRP is not expressible as a
            -- packed-record field range, so it survives the generated
            -- data-dependency validation, and a build with assertions disabled must
            -- still keep it away from the throwing Set_Config.
            if Validate_Config (Sigma_Rn => Sigma_Rn_C) then
               Set_Config (Self.Alg, Sigma_Rn => Sigma_Rn_C);
               Self.Applied_Sigma_Reference := Sigma;
            else
               -- Keep running on the last accepted attitude. The dependency is
               -- published inside the FSW, so a configuration the algorithm rejects
               -- is a defect rather than ground input -- assert so it surfaces in
               -- test instead of being silently absorbed.
               pragma Assert (False, "Inertial_3d: algorithm rejected the fetched reference attitude");
            end if;
         end;
      end if;

      declare
         -- The algorithm holds the reference attitude as configuration and returns
         -- it unchanged, so Update takes no per-tick input.
         Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C := Update (Self.Alg);
      begin
         -- Build the attitude reference message around the MRP. The algorithm
         -- produces the MRP alone; the reference rates are zero for a fixed
         -- inertial attitude, matching the C++ adapter, which zero-initializes the
         -- payload and writes only sigma_RN.
         Self.Data_Product_T_Send (Self.Data_Products.Attitude_Reference (
            Arg.Time,
            Att_Ref.Pack ((
               Sigma_Rn => Packed_F32x3.C.To_Ada (Sigma_Rn_C.Value),
               Omega_Rn_N => [others => 0.0],
               Domega_Rn_N => [others => 0.0]
            ))
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
