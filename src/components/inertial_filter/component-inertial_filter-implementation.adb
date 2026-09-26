--------------------------------------------------------------------------------
-- Inertial_Filter Component Implementation Body
--------------------------------------------------------------------------------

with Inertial_Filter_Fit_Residuals;
with Inertial_Filter_Output.C;
with Inertial_Filter_Rate_Data.C;
with Inertial_Filter_Residuals.C;
with Inertial_Filter_St_Att_Data.C;
with Inertial_Filter_State;
with Inertial_Filter_State_Matrix.C;
with Inertial_Filter_State_Vector.C;
with Nav_Att_Output;
with Packed_F32x3;
with Packed_F64x3.C;
with Packed_F64x6.C;
with Packed_F64x36.C;
with St_Att;

package body Component.Inertial_Filter.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action and
   -- Validate_Parameters all marshal the same values, so it is assembled in one
   -- place.
   type Pointer_Config is record
      Process_Noise : aliased Inertial_Filter_State_Matrix.C.U_C;
      Initial_State : aliased Inertial_Filter_State_Vector.C.U_C;
      Initial_Covariance : aliased Inertial_Filter_State_Matrix.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration.
   function To_Pointer_Config (
      Process_Noise_Diagonal : in Packed_F64x6.U;
      Initial_State : in Packed_F64x6.U;
      Initial_Covariance_Diagonal : in Packed_F64x6.U
   ) return Pointer_Config is
      -- Expand a diagonal into the row major N x N matrix the shim takes. The
      -- parameters carry only the diagonals, since the full matrices do not fit in a
      -- parameter.
      function Diagonal_Matrix (Diagonal : in Packed_F64x6.U) return Packed_F64x36.U is
         Matrix : Packed_F64x36.U := [others => 0.0];
      begin
         for I in Diagonal'Range loop
            Matrix (I * Packed_F64x6.Length + I) := Diagonal (I);
         end loop;
         return Matrix;
      end Diagonal_Matrix;
   begin
      return
         (Process_Noise => (Value => Packed_F64x36.C.To_C (Diagonal_Matrix (Process_Noise_Diagonal))),
          Initial_State => (Value => Packed_F64x6.C.To_C (Initial_State)),
          Initial_Covariance => (Value => Packed_F64x36.C.To_C (Diagonal_Matrix (Initial_Covariance_Diagonal))));
   end To_Pointer_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial filter with the default parameter values, which seed
   -- the filter state and covariance.
   overriding procedure Init (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Process_Noise_Diagonal, Self.Initial_State, Self.Initial_Covariance_Diagonal);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Alpha                      => Self.Alpha.Value,
         Beta                       => Self.Beta.Value,
         Process_Noise              => Cfg.Process_Noise'Access,
         Initial_State              => Cfg.Initial_State'Access,
         Initial_Covariance         => Cfg.Initial_Covariance'Access,
         St_Measurement_Noise_Std   => Self.St_Measurement_Noise_Std.Value,
         Rate_Measurement_Noise_Std => Self.Rate_Measurement_Noise_Std.Value);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the filter up to the tick's call time, folding in a fresh star tracker
   -- reading when there is one.
   overriding procedure Algorithm_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Algorithm_Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The star tracker attitude is produced earlier in the same tick, so any other
      -- status indicates that this component is not wired up correctly in the
      -- algorithm execution order. That should never happen, so we assert.
      Star_Tracker : St_Att.T;
      Star_Tracker_Status : constant Data_Dependency_Status.E :=
         Self.Get_Star_Tracker_Attitude (Value => Star_Tracker, Stale_Reference => Arg.Current_Tick.Time);
      pragma Assert (Star_Tracker_Status = Success);

      Tick_Ns : Unsigned_64 renames Arg.Call_Time;

      -- Widen a single precision star tracker vector to the double precision the shim
      -- takes. The vector is unpacked first, so each element is read whole before it
      -- is converted.
      -- TODO: The producer publishes single precision and the algorithm takes double.
      -- One side should change so the conversion goes away.
      function To_C (Vector : in Packed_F32x3.T) return Packed_F64x3.C.U_C is
         Unpacked : constant Packed_F32x3.U := Packed_F32x3.Unpack (Vector);
      begin
         return Packed_F64x3.C.To_C ([for I in Unpacked'Range => Long_Float (Unpacked (I))]);
      end To_C;

      -- Seconds since the filter's time base. A time before the base comes out negative,
      -- which the filter takes as no reading.
      function Filter_Seconds (Ns : in Unsigned_64) return Long_Float is
         (Long_Float (Integer_64 (Ns) - Integer_64 (Self.Epoch_Ns)) * 1.0E-9);

      -- The residuals of one measurement kind as published. The measured value is left
      -- out, since the star tracker product already carries it.
      function To_Fit_Residuals (Residuals : in Inertial_Filter_Residuals.C.U_C) return Inertial_Filter_Fit_Residuals.T is
         (Inertial_Filter_Fit_Residuals.Pack ((
            Valid    => Boolean (Residuals.Valid),
            Pre_Fit  => Packed_F64x3.C.To_Ada (Residuals.Pre_Fit),
            Post_Fit => Packed_F64x3.C.To_Ada (Residuals.Post_Fit))));
   begin
      -- Apply any pending parameter update:
      Self.Update_Parameters;

      -- A clock that stepped back cannot be followed: the pending measurements are
      -- dropped and the time base restarts at the next reading, which is new to the
      -- filter again. This repeats until the readings are stamped on the new clock.
      if Tick_Ns < Self.Epoch_Ns then
         Re_Initialize_Except_Persistent_States (Self.Alg);
         Self.Awaiting_First_Reading := True;
         Self.Last_St_Time_Tag := 0;
      end if;

      declare
         -- The product is refreshed only when the star tracker delivers, so it is a new
         -- reading only when its time tag has advanced since the last one consumed. The
         -- filter processes a measurement with the same time tag as its last one again,
         -- so an unrefreshed product must not be handed back to it. Nothing else is
         -- checked here: the filter drops a measurement older than its last one and
         -- propagates to one stamped after the call time on its own.
         -- TODO: This belongs in the algorithm. Once the filter ignores a measurement
         -- whose time tag has not advanced, every product is handed over each tick and
         -- this check goes away.
         Fresh : constant Boolean := Star_Tracker.Time_Tag > Self.Last_St_Time_Tag;
         -- A time tag of zero tells the filter there is no new reading; a fresh one is
         -- fed as both the attitude and the rate measurement, as the algorithm's own
         -- adapter does. Until the first reading sets the time base, below, the filter
         -- is held at time zero and fed nothing.
         -- TODO: The hold emulates the planned algorithm change, see the spec.
         Time_Tag : constant Long_Float := (if Fresh and then not Self.Awaiting_First_Reading then Filter_Seconds (Star_Tracker.Time_Tag) else 0.0);
         St_Att_Data : aliased constant Inertial_Filter_St_Att_Data.C.U_C :=
            (Time_Tag => Time_Tag, Sigma_Bn => To_C (Star_Tracker.Sigma_Bn));
         Rate_Data : aliased constant Inertial_Filter_Rate_Data.C.U_C :=
            (Time_Tag => Time_Tag, Rate => To_C (Star_Tracker.Omega_Bn_B));

         -- Advance the filter and take its snapshot. The estimate is the first three
         -- states, the attitude MRP, and the next three, the body rate.
         Output : constant Inertial_Filter_Output.C.U_C := Update (
            Self.Alg,
            Current_Seconds => (if Self.Awaiting_First_Reading then 0.0 else Filter_Seconds (Tick_Ns)),
            St_Att          => St_Att_Data'Access,
            Rate            => Rate_Data'Access);
      begin
         if Fresh then
            Self.Last_St_Time_Tag := Star_Tracker.Time_Tag;
            -- The first reading after a restart sets the time base at its time tag. It
            -- was not fed above, so the filter propagates from the base from the next
            -- tick on.
            -- TODO: Emulates the planned algorithm change, see the spec. Goes away with it.
            if Self.Awaiting_First_Reading then
               Self.Epoch_Ns := Star_Tracker.Time_Tag;
               Self.Awaiting_First_Reading := False;
            end if;
         end if;

         -- Publish the estimate for the downstream algorithms, narrowed to the single
         -- precision they consume, and stamped in system seconds.
         Self.Data_Product_T_Send (Self.Data_Products.Attitude_Estimate (
            Arg.Current_Tick.Time,
            Nav_Att_Output.Pack ((
               Time_Tag        => Long_Float (Tick_Ns) * 1.0E-9,
               Sigma_Bn        => [for I in 0 .. 2 => Short_Float (Output.State (I))],
               Omega_Bn_B      => [for I in 0 .. 2 => Short_Float (Output.State (I + 3))],
               -- The estimate shares the navigation attitude output type with the
               -- sunline filter, but this filter estimates only the attitude and the
               -- body rate. It has no sun direction state, so the sun direction field
               -- is always zero and consumers must not read it from this product.
               Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0]))
         ));

         -- Publish the rest of the snapshot for the ground. The covariance is reduced to
         -- its diagonal, which is all that is needed, and the time of the last reading
         -- consumed goes along so the time of the last measurement is known once the
         -- product is sampled into a packet. The residuals carry whether their
         -- measurement fired this tick for the same reason.
         Self.Data_Product_T_Send (Self.Data_Products.Filter_State (Arg.Current_Tick.Time, Inertial_Filter_State.Pack ((
            State                 => Packed_F64x6.C.To_Ada (Output.State),
            Covariance_Diagonal   => [for I in 0 .. Packed_F64x6.Length - 1 => Output.Covariance (I * Packed_F64x6.Length + I)],
            Last_Measurement_Time => Self.Last_St_Time_Tag))));
         Self.Data_Product_T_Send (Self.Data_Products.St_Att_Residuals (Arg.Current_Tick.Time, To_Fit_Residuals (Output.St_Att_Residuals)));
         Self.Data_Product_T_Send (Self.Data_Products.Rate_Residuals (Arg.Current_Tick.Time, To_Fit_Residuals (Output.Rate_Residuals)));
      end;
   end Algorithm_Tick_T_Recv_Sync;

   -- Re-seed the filter state and covariance from the configured initial values and
   -- clear the pending measurements and residuals. The filter's time base restarts at
   -- the next star tracker reading. The assembly fires this on every entry to the
   -- navigation state, where the filter is first put into use.
   overriding procedure Reset_Estimate_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      Re_Initialize (Self.Alg);
      Self.Awaiting_First_Reading := True;
   end Reset_Estimate_Tick_T_Recv_Sync;

   -- Clear the pending measurements and residuals, keeping the filter state and
   -- covariance. The filter's time base restarts at the next star tracker reading. The
   -- assembly fires this on every transition between pointing states.
   overriding procedure Reset_Measurements_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clearing the pending measurements also drops the filter's time anchor, so its
      -- time base restarts as well.
      Re_Initialize_Except_Persistent_States (Self.Alg);
      Self.Awaiting_First_Reading := True;
   end Reset_Measurements_Tick_T_Recv_Sync;

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
   --    Parameters for the Inertial Filter component.
   -- This procedure is called when the parameters of a component have been updated. In this
   -- case we push the whole configuration into the C algorithm, which keeps the current
   -- estimate. The values were checked at staging by Validate_Parameters, so Set_Config
   -- does not throw.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Process_Noise_Diagonal, Self.Initial_State, Self.Initial_Covariance_Diagonal);
   begin
      Set_Config (
         Self.Alg,
         Alpha                      => Self.Alpha.Value,
         Beta                       => Self.Beta.Value,
         Process_Noise              => Cfg.Process_Noise'Access,
         Initial_State              => Cfg.Initial_State'Access,
         Initial_Covariance         => Cfg.Initial_Covariance'Access,
         St_Measurement_Noise_Std   => Self.St_Measurement_Noise_Std.Value,
         Rate_Measurement_Noise_Std => Self.Rate_Measurement_Noise_Std.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create and Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Alpha : in Packed_F64.U;
      Beta : in Packed_F64.U;
      Process_Noise_Diagonal : in Packed_F64x6.U;
      Initial_State : in Packed_F64x6.U;
      Initial_Covariance_Diagonal : in Packed_F64x6.U;
      St_Measurement_Noise_Std : in Packed_F64.U;
      Rate_Measurement_Noise_Std : in Packed_F64.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Process_Noise_Diagonal, Initial_State, Initial_Covariance_Diagonal);
      if Validate_Config (
         Alpha                      => Alpha.Value,
         Beta                       => Beta.Value,
         Process_Noise              => Cfg.Process_Noise'Access,
         Initial_State              => Cfg.Initial_State'Access,
         Initial_Covariance         => Cfg.Initial_Covariance'Access,
         St_Measurement_Noise_Std   => St_Measurement_Noise_Std.Value,
         Rate_Measurement_Noise_Std => Rate_Measurement_Noise_Std.Value)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: float staging accepts a
      -- non-finite value, and marshalling it above raises. Rejecting the set here keeps
      -- that from unwinding into the Parameters component.
      when Constraint_Error =>
         return Parameter_Validation_Status.Invalid;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Inertial Filter component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Inertial_Filter.Implementation;
