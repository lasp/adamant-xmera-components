--------------------------------------------------------------------------------
-- Thr_Firing_Remainder Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x8.C;
with Thr_Firing_Remainder_Enums;
with Thr_Force_Cmd.C;
with Thr_On_Time_Cmd.C;

package body Component.Thr_Firing_Remainder.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster firing remainder algorithm with the control period and the default parameter
   -- values.
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
      Max_Thrust_C : aliased constant Packed_F32x8.C.U_C := Packed_F32x8.C.To_C (Self.Max_Thrust);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Max_Thrust                => Max_Thrust_C'Access,
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time.Value,
         Control_Period            => Self.Control_Period,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor.Value,
         Pulsing_Regime            => Thr_Firing_Remainder_Enums.Pulsing_Regime.C.To_C (Self.Thrust_Pulsing_Regime.Value));
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
      Force_Dep : Thr_Force_Cmd.T;
      Force_Status : constant Data_Dependency_Status.E :=
         Self.Get_Thruster_Force_Cmd (Value => Force_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Force_Status = Success);

      -- The force command and the algorithm's input share the mission thruster
      -- count, so the dependency crosses the FFI boundary unpacked, with no
      -- intermediate array.
      Force_C : aliased constant Thr_Force_Cmd.C.U_C := Thr_Force_Cmd.C.Unpack (Force_Dep);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      declare
         On_Time_Result : constant Thr_On_Time_Cmd.T :=
            Thr_On_Time_Cmd.C.Pack (Update (Self.Alg, Force_C'Access));
      begin
         Self.Data_Product_T_Send (Self.Data_Products.On_Time_Cmd (Arg.Time, On_Time_Result));
         -- Send the on-time command directly to the actuation interface:
         Self.Thr_On_Time_Cmd_T_Send_If_Connected (On_Time_Result);
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
   -- This procedure is called when the parameters of a component have been updated.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Max_Thrust_C : aliased constant Packed_F32x8.C.U_C := Packed_F32x8.C.To_C (Self.Max_Thrust);
   begin
      -- Push the updated parameters into the C++ algorithm in a single call. The
      -- values were checked by Validate_Parameters at staging, so Set_Config will
      -- not reject them. The accumulated pulse remainder state is preserved.
      Set_Config (
         Self.Alg,
         Max_Thrust                => Max_Thrust_C'Access,
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time.Value,
         Control_Period            => Self.Control_Period,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor.Value,
         Pulsing_Regime            => Thr_Firing_Remainder_Enums.Pulsing_Regime.C.To_C (Self.Thrust_Pulsing_Regime.Value));
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's
   -- own non-throwing Validate_Config predicate, so the configuration rules live
   -- solely in the algorithm. Rejecting an invalid update here at staging keeps it
   -- from reaching the throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Max_Thrust : in Packed_F32x8.U;
      Thr_Min_Fire_Time : in Packed_F32.U;
      On_Time_Saturation_Factor : in Packed_F32.U;
      Thrust_Pulsing_Regime : in Packed_Pulsing_Regime.U
   ) return Parameter_Validation_Status.E is
      Max_Thrust_C : aliased constant Packed_F32x8.C.U_C := Packed_F32x8.C.To_C (Max_Thrust);
   begin
      if Validate_Config (
            Max_Thrust                => Max_Thrust_C'Access,
            Thr_Min_Fire_Time         => Thr_Min_Fire_Time.Value,
            Control_Period            => Self.Control_Period,
            On_Time_Saturation_Factor => On_Time_Saturation_Factor.Value,
            Pulsing_Regime            => Thr_Firing_Remainder_Enums.Pulsing_Regime.C.To_C (Thrust_Pulsing_Regime.Value))
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Thr_Firing_Remainder.Implementation;
