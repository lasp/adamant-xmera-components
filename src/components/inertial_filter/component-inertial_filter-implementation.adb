--------------------------------------------------------------------------------
-- Inertial_Filter Component Implementation Body
--------------------------------------------------------------------------------

with Inertial_Filter_Fit_Residuals;
with Inertial_Filter_Output.C;
with Inertial_Filter_Rate_Data.C;
with Inertial_Filter_Residuals.C;
with Inertial_Filter_St_Att_Data.C;
with Inertial_Filter_State_Matrix.C;
with Inertial_Filter_State_Vector.C;
with Packed_F32x3.C;
with Packed_F64x3.C;
with Packed_F64x6;
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
      function Diagonal_Matrix (Diagonal : in Packed_F64x6.U) return Packed_F64x36.C.U_C is
         Matrix : Packed_F64x36.C.U_C := [others => 0.0];
      begin
         for I in Diagonal'Range loop
            Matrix (I * Packed_F64x6.Length + I) := Diagonal (I);
         end loop;
         return Matrix;
      end Diagonal_Matrix;
   begin
      return
         (Process_Noise => (Value => Diagonal_Matrix (Process_Noise_Diagonal)),
          Initial_State => (Value => [for I in Initial_State'Range => Initial_State (I)]),
          Initial_Covariance => (Value => Diagonal_Matrix (Initial_Covariance_Diagonal)));
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
      -- The star tracker attitude is published earlier in the same tick but stamped
      -- with the time of its solution, so it is Stale between solutions. That is
      -- expected and the value is populated: whether the reading is new is decided
      -- below from its time tag. Not_Available and Error indicate that this component
      -- is not wired up correctly in the algorithm execution order. That should never
      -- happen, so we assert.
      Star_Tracker : St_Att.T;
      Star_Tracker_Status : constant Data_Dependency_Status.E :=
         Self.Get_Star_Tracker_Attitude (Value => Star_Tracker, Stale_Reference => Arg.Current_Tick.Time);
      pragma Assert (Star_Tracker_Status = Success or else Star_Tracker_Status = Stale);

      -- Widen a single precision star tracker vector to the double precision the shim
      -- takes. The elements are read through the generated Unpack: GNAT Pro 25.2
      -- evaluates the validity check of a big endian packed float element on the
      -- unswapped bytes, so a direct read raises invalid data for some valid values.
      -- FSF GCC fixed this in 60f5887173a4.
      -- TODO: Read the elements directly once the compiler fix arrives. The producer
      -- publishes single precision and the algorithm takes double, so one side should
      -- change and the widening go away as well.
      function To_C (Vector : in Packed_F32x3.T) return Packed_F64x3.C.U_C is
         Unpacked : constant Packed_F32x3.C.U_C := Packed_F32x3.C.Unpack (Vector);
      begin
         return [for I in Unpacked'Range => Long_Float (Unpacked (I))];
      end To_C;

      -- System time in the seconds the filter takes.
      function Seconds (Ns : in Unsigned_64) return Long_Float is
         (Long_Float (Ns) * 1.0E-9);

      -- The residuals of one measurement kind as published. The measured value is left
      -- out, since the star tracker product already carries it.
      function To_Fit_Residuals (Residuals : in Inertial_Filter_Residuals.C.U_C) return Inertial_Filter_Fit_Residuals.T is
         ((Valid    => Boolean (Residuals.Valid),
           Pre_Fit  => [for I in Residuals.Pre_Fit'Range => Residuals.Pre_Fit (I)],
           Post_Fit => [for I in Residuals.Post_Fit'Range => Residuals.Post_Fit (I)]));

      -- Whether a reading stamped at Ns is new to the filter: its time tag differs from
      -- the one it was last consumed with, which Last records. The filter cannot tell a
      -- repeat from a second sensor sharing a time tag, so it processes a measurement
      -- with the same time tag as its last one again, and a product that has not been
      -- refreshed since the last tick must not be handed back to it. Nothing else is
      -- checked here: the filter drops a measurement older than its anchor and
      -- propagates to one stamped after the call time on its own.
      function Is_Fresh (Ns : in Unsigned_64; Last : in out Unsigned_64) return Boolean is
      begin
         if Ns /= Last then
            Last := Ns;
            return True;
         end if;
         return False;
      end Is_Fresh;
   begin
      -- Apply any pending parameter update:
      Self.Update_Parameters;

      declare
         -- The product is refreshed only when the star tracker delivers, so it is
         -- consumed once, when its time tag has changed since the last time.
         Fresh : constant Boolean := Is_Fresh (Star_Tracker.Time_Tag, Self.Last_St_Time_Tag);
         -- A time tag of zero tells the filter there is no new reading; a fresh one is
         -- fed as both the attitude and the rate measurement, as the algorithm's own
         -- adapter does.
         Time_Tag : constant Long_Float := (if Fresh then Seconds (Star_Tracker.Time_Tag) else 0.0);
         St_Att_Data : aliased constant Inertial_Filter_St_Att_Data.C.U_C :=
            (Time_Tag => Time_Tag, Sigma_Bn => To_C (Star_Tracker.Sigma_Bn));
         Rate_Data : aliased constant Inertial_Filter_Rate_Data.C.U_C :=
            (Time_Tag => Time_Tag, Rate => To_C (Star_Tracker.Omega_Bn_B));

         -- Advance the filter and take its snapshot. The estimate is the first three
         -- states, the attitude MRP, and the next three, the body rate.
         Output : constant Inertial_Filter_Output.C.U_C := Update (
            Self.Alg,
            Current_Seconds => Seconds (Arg.Call_Time),
            St_Att          => St_Att_Data'Access,
            Rate            => Rate_Data'Access);
      begin
         -- Publish the estimate for the downstream algorithms, narrowed to the single
         -- precision they consume, and stamped in system seconds.
         Self.Data_Product_T_Send (Self.Data_Products.Attitude_Estimate (
            Arg.Current_Tick.Time,
            (Time_Tag        => Seconds (Arg.Call_Time),
             Sigma_Bn        => [for I in 0 .. 2 => Short_Float (Output.State (I))],
             Omega_Bn_B      => [for I in 0 .. 2 => Short_Float (Output.State (I + 3))],
             -- The estimate shares the navigation attitude output type with the
             -- sunline filter, but this filter estimates only the attitude and the
             -- body rate. It has no sun direction state, so the sun direction field
             -- is always zero and consumers must not read it from this product.
             Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0])
         ));

         -- Publish the rest of the snapshot for the ground. The covariance is reduced to
         -- its diagonal, which is all that is needed, and the time of the last reading
         -- consumed goes along so the time of the last measurement is known once the
         -- product is sampled into a packet. The residuals carry whether their
         -- measurement fired this tick for the same reason.
         Self.Data_Product_T_Send (Self.Data_Products.Filter_State (Arg.Current_Tick.Time, (
            State                 => [for I in 0 .. Packed_F64x6.Length - 1 => Output.State (I)],
            Covariance_Diagonal   => [for I in 0 .. Packed_F64x6.Length - 1 => Output.Covariance (I * Packed_F64x6.Length + I)],
            Last_Measurement_Time => Self.Last_St_Time_Tag)));
         Self.Data_Product_T_Send (Self.Data_Products.St_Att_Residuals (Arg.Current_Tick.Time, To_Fit_Residuals (Output.St_Att_Residuals)));
         Self.Data_Product_T_Send (Self.Data_Products.Rate_Residuals (Arg.Current_Tick.Time, To_Fit_Residuals (Output.Rate_Residuals)));
      end;
   end Algorithm_Tick_T_Recv_Sync;

   -- Re-seed the filter state and covariance from the configured initial values and
   -- clear the pending measurements and residuals. The filter synchronizes its time
   -- again at the next tick. The assembly fires this on every entry to the navigation
   -- state, where the filter is first put into use.
   overriding procedure Reset_Estimate_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      Re_Initialize (Self.Alg);
   end Reset_Estimate_Tick_T_Recv_Sync;

   -- Clear the pending measurements and residuals, keeping the filter state and
   -- covariance. The filter synchronizes its time again at the next tick. The assembly
   -- fires this on every transition between pointing states.
   overriding procedure Reset_Measurements_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clearing the pending measurements also drops the filter's time anchor, so it
      -- synchronizes again at the next tick.
      Re_Initialize_Except_Persistent_States (Self.Alg);
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
   --    Data dependencies for the Inertial Filter component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Inertial_Filter.Implementation;
