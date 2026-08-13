--------------------------------------------------------------------------------
-- Thr_Firing_Remainder Component Implementation Body
--------------------------------------------------------------------------------

with Thr_Force_Cmd;
with Thr_On_Time_Cmd;
with Thr_Firing_Remainder_Force_Cmd.C;
with Thr_Firing_Remainder_On_Time_Cmd.C;

package body Component.Thr_Firing_Remainder.Implementation is

   -- Number of thrusters carried by the 8-element data products, which the
   -- component zero-pads into (and truncates back out of) the 36-element C API.
   Num_Dp_Thrusters : constant := 8;

   -- Push the component's current configuration -- the applied parameters plus
   -- the thruster array held as instance state -- into the C++ algorithm. Every
   -- reconfiguration path goes through here so the configuration is assembled in
   -- exactly one place.
   procedure Apply_Config (Self : in out Instance) is
   begin
      Set_Config (
         Self.Alg,
         Num_Thrusters             => Self.Num_Thrusters,
         Max_Thrust                => Self.Max_Thrust'Access,
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time.Value,
         Control_Period            => Self.Control_Period.Value,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor.Value,
         Pulsing_Regime            => To_C (Self.Thrust_Pulsing_Regime.Value));
   end Apply_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster firing remainder algorithm.
   overriding procedure Init (Self : in out Instance) is
      use Parameter_Validation_Status;
   begin
      pragma Assert (Self.Validate_Parameters (
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time,
         Control_Period            => Self.Control_Period,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor,
         Thrust_Pulsing_Regime     => Self.Thrust_Pulsing_Regime) = Valid);
      Self.Alg := Create (
         Num_Thrusters             => Self.Num_Thrusters,
         Max_Thrust                => Self.Max_Thrust'Access,
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time.Value,
         Control_Period            => Self.Control_Period.Value,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor.Value,
         Pulsing_Regime            => To_C (Self.Thrust_Pulsing_Regime.Value));
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   not overriding procedure Configure_Thrusters (
      Self          : in out Instance;
      Num_Thrusters : in Unsigned_32;
      Max_Thrust    : in Packed_F32x36.U)
   is
      use Parameter_Validation_Status;
   begin
      -- Record the thruster array as the Ada-side source of truth, then swap the
      -- full configuration into the algorithm.
      Self.Num_Thrusters := Num_Thrusters;
      Self.Max_Thrust := Packed_F32x36.C.To_C (Max_Thrust);
      -- The assembly owns this call, so an out-of-range thruster count or a
      -- non-finite maximum thrust is a wiring error rather than ground input:
      -- assert instead of reporting, and keep it out of the throwing Set_Config.
      -- Validate_Parameters reads the thruster array assigned just above, so this
      -- checks the whole configuration through the component's single gate.
      pragma Assert (Self.Validate_Parameters (
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time,
         Control_Period            => Self.Control_Period,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor,
         Thrust_Pulsing_Regime     => Self.Thrust_Pulsing_Regime) = Valid);
      Apply_Config (Self);
   end Configure_Thrusters;

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
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      declare
         -- Unpack 8-element dependency
         Force_Dep_U : constant Thr_Force_Cmd.U := Thr_Force_Cmd.Unpack (Force_Dep);

         -- Build 36-element C input (zeroed, then copy 8 thruster values)
         Force_36 : aliased Thr_Firing_Remainder_Force_Cmd.C.U_C := (Thr_Force => [others => 0.0]);
      begin
         for I in 0 .. Num_Dp_Thrusters - 1 loop
            Force_36.Thr_Force (I) := Force_Dep_U.Thr_Force (I);
         end loop;

         declare
            -- Call the C algorithm
            On_Time_36 : constant Thr_Firing_Remainder_On_Time_Cmd.C.U_C :=
               Update (Self.Alg, Force_36'Access);

            -- Extract first 8 elements for output
            On_Time_Result : Thr_On_Time_Cmd.T := (On_Time_Request => [others => 0.0]);
         begin
            for I in 0 .. Num_Dp_Thrusters - 1 loop
               On_Time_Result.On_Time_Request (I) := On_Time_36.On_Time_Request (I);
            end loop;

            Self.Data_Product_T_Send (Self.Data_Products.On_Time_Cmd (Arg.Time, On_Time_Result));
            -- Send the on-time command directly to the actuation interface:
            Self.Thr_On_Time_Cmd_T_Send_If_Connected (On_Time_Result);
         end;
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
   begin
      -- Rebuild the algorithm configuration from the updated parameters. The values
      -- were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them. The accumulated pulse remainder state is preserved.
      Apply_Config (Self);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's
   -- own non-throwing Validate_Config predicate, so the configuration rules live
   -- solely in the algorithm. Rejecting an invalid update here at staging keeps it
   -- from reaching the throwing Create/Set_Config across the FFI boundary. The
   -- thruster array is not staged, so the candidate configuration pairs the staged
   -- parameters with the currently configured thruster array.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Thr_Min_Fire_Time : in Packed_F32.U;
      Control_Period : in Packed_F32.U;
      On_Time_Saturation_Factor : in Packed_F32.U;
      Thrust_Pulsing_Regime : in Packed_Pulsing_Regime.U
   ) return Parameter_Validation_Status.E is
   begin
      if Validate_Config (
            Num_Thrusters             => Self.Num_Thrusters,
            Max_Thrust                => Self.Max_Thrust'Access,
            Thr_Min_Fire_Time         => Thr_Min_Fire_Time.Value,
            Control_Period            => Control_Period.Value,
            On_Time_Saturation_Factor => On_Time_Saturation_Factor.Value,
            Pulsing_Regime            => To_C (Thrust_Pulsing_Regime.Value))
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
