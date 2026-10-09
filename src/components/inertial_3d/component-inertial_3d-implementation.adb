--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Inertial_3d.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
   overriding procedure Init (Self : in out Instance) is
      -- The attitude to hold arrives through a connector once the assembly is
      -- running. Construct the algorithm with the zero MRP so a tick landing before
      -- the first command still produces deterministic output.
      Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.Unpack ((Value => [0.0, 0.0, 0.0]));
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
   -- Run the algorithm up to the current time and return the attitude reference it
   -- produces.
   overriding function Tick_T_Service (Self : in out Instance; Arg : in Tick.T) return Att_Ref.T is
      pragma Unreferenced (Arg);
   begin
      -- The algorithm holds the reference attitude as configuration and returns it
      -- unchanged, so Update takes no per-tick input. It produces the MRP alone; the
      -- reference rates are zero for a fixed inertial attitude, matching the C++
      -- adapter, which zero-initializes the payload and writes only sigma_RN.
      return Att_Ref.Pack ((
         Sigma_Rn => Packed_F32x3.C.To_Ada (Update (Self.Alg).Value),
         Omega_Rn_N => [others => 0.0],
         Domega_Rn_N => [others => 0.0]
      ));
   end Tick_T_Service;

   -- Set the inertial attitude the reference holds, as the MRP from the inertial
   -- frame N to the reference frame R. The sender is required to send a finite
   -- vector, and a new attitude reconfigures the algorithm on receipt.
   overriding procedure Attitude_T_Recv_Sync (Self : in out Instance; Arg : in Packed_F32x3_Record.T) is
      Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C := Packed_F32x3_Record.C.Unpack (Arg);
   begin
      -- Set_Config throws on an invalid configuration. The attitude comes from
      -- inside the flight software, which is required to send a finite vector, so
      -- the algorithm's own predicate is asserted rather than checked.
      pragma Assert (Validate_Config (Sigma_Rn => Sigma_Rn_C));
      Set_Config (Self.Alg, Sigma_Rn => Sigma_Rn_C);
   end Attitude_T_Recv_Sync;

end Component.Inertial_3d.Implementation;
