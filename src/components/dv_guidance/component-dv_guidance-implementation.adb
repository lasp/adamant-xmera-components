--------------------------------------------------------------------------------
-- Dv_Guidance Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Dv_Guidance.Implementation is

   -- The burn frame as the shim takes it. Init, the parameter update and the
   -- validation all marshal the same two parameters, so it is assembled in one place.
   type Frame_Config is record
      Cmd_Dv_N : Packed_F32x3_Record.C.U_C;
      R_Hat_Pref_N : Packed_F32x3_Record.C.U_C;
   end record;

   function To_Frame_Config (Cmd_Dv_N : in Packed_F32x3.U; R_Hat_Pref_N : in Packed_F32x3.U) return Frame_Config is
      ((Cmd_Dv_N => (Value => Packed_F32x3.C.To_C (Cmd_Dv_N)),
        R_Hat_Pref_N => (Value => Packed_F32x3.C.To_C (R_Hat_Pref_N))));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V guidance algorithm with the default parameter values, a
   -- stand-in burn frame which the first burn command replaces.
   overriding procedure Init (Self : in out Instance) is
      Cfg : constant Frame_Config := To_Frame_Config (Self.Cmd_Dv_N, Self.R_Hat_Pref_N);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid frame. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (Cmd_Dv_N => Cfg.Cmd_Dv_N, R_Hat_Pref_N => Cfg.R_Hat_Pref_N);
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
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update, so a new burn frame takes effect on the
      -- tick after its update:
      Self.Update_Parameters;

      -- The burn frame is inertially fixed, so the algorithm takes no per-tick input
      -- and returns the reference with its rate and acceleration zero.
      return Att_Ref.C.Pack (Update (Self.Alg));
   end Tick_T_Service;

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
   --    Parameters for the Dv Guidance component. Together they define the burn
   --    frame, so they are set when a burn is commanded. The defaults form a valid
   --    frame and stand in until then.

   -- This procedure is called when the parameters of a component have been updated. In this
   -- case we push the burn frame into the C algorithm so subsequent updates return it.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : constant Frame_Config := To_Frame_Config (Self.Cmd_Dv_N, Self.R_Hat_Pref_N);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will
      -- not reject them.
      Set_Config (Self.Alg, Cmd_Dv_N => Cfg.Cmd_Dv_N, R_Hat_Pref_N => Cfg.R_Hat_Pref_N);
   end Update_Parameters_Action;

   -- Validate a staged burn frame before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the frame rules live solely in the
   -- algorithm. Rejecting an invalid frame here at staging keeps it from reaching the
   -- throwing Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Cmd_Dv_N : in Packed_F32x3.U;
      R_Hat_Pref_N : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : Frame_Config;
   begin
      Cfg := To_Frame_Config (Cmd_Dv_N, R_Hat_Pref_N);
      if Validate_Config (Cmd_Dv_N => Cfg.Cmd_Dv_N, R_Hat_Pref_N => Cfg.R_Hat_Pref_N) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the frame here
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

end Component.Dv_Guidance.Implementation;
