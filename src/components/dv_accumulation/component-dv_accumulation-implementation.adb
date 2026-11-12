--------------------------------------------------------------------------------
-- Dv_Accumulation Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Dv_Accumulation.Implementation is

   -- The accelerometer bias as the shim takes it. Init, the parameter update and the
   -- validation all marshal the same parameter, so it is converted in one place.
   function To_C (Accel_Bias_B : in Packed_F32x3.U) return Packed_F32x3_Record.C.U_C is
      ((Value => Packed_F32x3.C.To_C (Accel_Bias_B)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V accumulation algorithm with the control period and the
   -- default parameter values.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates, the integration step of each sample, so it must equal the
   -- rate at which the component is scheduled. Fixed by the assembly, so it is not a
   -- runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (Control_Period => Self.Control_Period, Accel_Bias_B => To_C (Self.Accel_Bias_B));
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Integrate the acceleration of this tick and publish the accumulated delta-V.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The voted acceleration is produced every tick, earlier in the same tick, so
      -- any other status indicates that this component is not wired up
      -- correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Accel : Packed_F32x3.T;
      Accel_Status : constant Data_Dependency_Status.E :=
         Self.Get_Accel_Average (Value => Accel, Stale_Reference => Arg.Time);
      pragma Assert (Accel_Status = Success);
   begin
      -- Apply any pending parameter update, so a new bias is subtracted from the sample
      -- of this tick:
      Self.Update_Parameters;

      -- Integrate the sample, less the configured bias, and publish the accumulated
      -- delta-V. Update is qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Accumulated_Delta_V (
         Arg.Time,
         Packed_F32x3.C.Pack (Dv_Accumulation_Algorithm_C.Update (
            Self.Alg,
            R_Ddot_No_Gravity_Bn_B => (Value => Packed_F32x3.C.Unpack (Accel))).Value)
      ));
   end Tick_T_Recv_Sync;

   -- Zero the accumulated delta-V and start a new accumulation window at the next
   -- tick. The assembly fires this when a burn is set up, before the burn executor is
   -- started.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update first, so the reset starts from the
      -- configuration the component runs with next:
      Self.Update_Parameters;
      -- Zeroes the accumulator and restarts the window only; the configuration is
      -- untouched.
      Re_Initialize (Self.Alg);
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
   --    Parameters for the Dv Accumulation component. The accelerometer bias is set
   --    when a burn is commanded. The default makes no correction and stands in until
   --    then.

   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the configuration into the C algorithm so subsequent samples have the new bias subtracted.
   -- The accumulated delta-V is kept. The control period is fixed at initialization.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The value was checked by Validate_Parameters at staging, so Set_Config will not
      -- reject it.
      Set_Config (Self.Alg, Control_Period => Self.Control_Period, Accel_Bias_B => To_C (Self.Accel_Bias_B));
   end Update_Parameters_Action;

   -- Validate a staged bias before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid bias here at staging keeps it from reaching the
   -- throwing Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Accel_Bias_B : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Bias : Packed_F32x3_Record.C.U_C;
   begin
      Bias := To_C (Accel_Bias_B);
      -- The algorithm only requires a finite bias, and marshalling a non-finite one
      -- raises above, so the predicate cannot fail here today. It is still the guard
      -- should the algorithm's rules grow.
      return (if Validate_Config (Control_Period => Self.Control_Period, Accel_Bias_B => Bias)
              then Parameter_Validation_Status.Valid else Parameter_Validation_Status.Invalid);
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the bias here keeps
      -- that from unwinding into the Parameters component.
      -- TODO: The generated validation of the staged bytes should reject a non-finite
      -- value, but GNAT Pro 25.2 evaluates 'Valid on an element of a packed float array
      -- with a non native Scalar_Storage_Order on the unswapped bytes, so at staging a
      -- NaN or infinity passes. FSF GCC fixed this in 60f5887173a4. Once the compiler
      -- fix arrives this handler is unreachable and can go, along with the injection in
      -- the parameter rejection test.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Dv Accumulation component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Dv_Accumulation.Implementation;
