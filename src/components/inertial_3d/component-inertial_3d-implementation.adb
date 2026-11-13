--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Inertial_3d.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance with the default parameter
   -- value.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Create throws on an invalid configuration, so the parameter default must be a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks it at startup
      -- and in unit test set up.
      Self.Alg := Create (Sigma_Rn => (Value => Packed_F32x3.C.To_C (Self.Sigma_Rn)));
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

   -- Apply any pending parameter update. Called on GNC state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      Self.Update_Parameters;
   end Reset_Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Inertial 3D component.

   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the attitude into the C algorithm so subsequent updates return it.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The value was checked by Validate_Parameters at staging, so Set_Config will not
      -- reject it.
      Set_Config (Self.Alg, Sigma_Rn => (Value => Packed_F32x3.C.To_C (Self.Sigma_Rn)));
   end Update_Parameters_Action;

   -- Validate a staged attitude before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid attitude here at staging keeps it from reaching
   -- the throwing Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sigma_Rn : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Sigma_Rn_C : Packed_F32x3_Record.C.U_C;
   begin
      Sigma_Rn_C := (Value => Packed_F32x3.C.To_C (Sigma_Rn));
      if Validate_Config (Sigma_Rn => Sigma_Rn_C) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the attitude here
      -- keeps that from unwinding into the caller.
      -- TODO: The generated validation of the staged bytes should reject a non-finite
      -- value, but GNAT Pro 25.2 evaluates 'Valid on an element of a packed float array
      -- with a non native Scalar_Storage_Order on the unswapped bytes, so at staging a
      -- NaN or infinity passes. FSF GCC fixed this in 60f5887173a4. Once the compiler
      -- fix arrives this handler is unreachable and can go, along with the injection in
      -- the parameter rejection test.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

end Component.Inertial_3d.Implementation;
