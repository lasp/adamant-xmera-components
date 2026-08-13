--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Packed_F32x3;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Inertial_3d.Implementation is

   ------------------------------------------------------------------------
   -- Local Helpers
   ------------------------------------------------------------------------

   -- Marshal an unpacked MRP parameter value into the Vector3f_c mirror the
   -- flattened shim expects as its single configuration argument.
   function To_Config (Sigma_Rn : in Packed_F32x3.U) return Packed_F32x3_Record.C.U_C
   is ((Value => Packed_F32x3.C.To_C (Sigma_Rn)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
   overriding procedure Init (Self : in out Instance) is
      use Parameter_Validation_Status;
   begin
      -- Create throws on an invalid configuration, so the parameter default must form a
      -- valid one. Assert through Validate_Parameters, the component's single validation
      -- gate, rather than calling Validate_Config a second time here.
      pragma Assert (Self.Validate_Parameters (Sigma_Rn => Self.Sigma_Rn) = Valid);
      Self.Alg := Create (Sigma_Rn => To_Config (Self.Sigma_Rn));
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
   begin
      -- Update the parameters:
      Self.Update_Parameters;

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

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Rebuild the algorithm configuration from the updated parameter. The value was
      -- checked by Validate_Parameters at staging, so Set_Config will not reject it.
      Set_Config (Self.Alg, Sigma_Rn => To_Config (Self.Sigma_Rn));
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Sigma_Rn : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
   begin
      if Validate_Config (Sigma_Rn => To_Config (Sigma_Rn)) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Packed_F32x3.C.To_C range-checks each element, so a non-finite MRP raises
      -- here rather than reaching Validate_Config. Either way the value is invalid
      -- configuration: reject it instead of letting the exception propagate out of
      -- the parameter staging path. This is also what keeps Update_Parameters_Action,
      -- which marshals through the same helper, from ever seeing a non-finite value.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

end Component.Inertial_3d.Implementation;
