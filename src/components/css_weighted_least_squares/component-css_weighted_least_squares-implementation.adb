--------------------------------------------------------------------------------
-- Css_Weighted_Least_Squares Component Implementation Body
--------------------------------------------------------------------------------

with Css_Availability_Array.C;
with Css_Boresight_Array.C;
with Css_Reading_Array.C;
with Css_Sensor_Values;
with Css_Weighted_Least_Squares_Output.C;
with Interfaces.C;
with Packed_F32x3.C;
with Packed_F32x8.C;

package body Component.Css_Weighted_Least_Squares.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Boresights : aliased Css_Boresight_Array.C.U_C;
      Availability : aliased Css_Availability_Array.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration. The availability enumeration
   -- is pinned to the C values and one byte wide, so it crosses without conversion.
   function To_Pointer_Config (
      Css_N_Hat_B : in Packed_F32x24.U;
      Css_Availability : in Css_Availability_X8.U
   ) return Pointer_Config is
      (Boresights => Css_Boresight_Array.C.To_C ((Data => Css_N_Hat_B)),
       Availability => Css_Availability_Array.C.To_C ((Value => Css_Availability)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the estimator with the control period and the default parameter
   -- values.
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Css_N_Hat_B, Self.Css_Availability);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (
         Css_N_Hat_B                 => Cfg.Boresights'Access,
         Css_Availability            => Cfg.Availability'Access,
         Use_Measurements_As_Weights => Interfaces.C.C_bool (Self.Use_Measurements_As_Weights.Value),
         Sensor_Use_Thresh           => Self.Sensor_Use_Thresh.Value,
         Control_Period              => Self.Control_Period);
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

      -- Grab the data dependency:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale. The
      -- css_comm component publishes the corrected readings stamped with the time of
      -- the sensor sample rather than the tick, so a reading can come back Stale. It is
      -- fitted like a fresh one; the estimate carries the tick time, and the age of the
      -- underlying sample is visible on the css_comm product. Not_Available and Error
      -- mean this component is not wired up correctly, so we assert.
      Readings : Css_Sensor_Values.T;
      Readings_Status : constant Data_Dependency_Status.E :=
         Self.Get_Css_Sensor_Input (Value => Readings, Stale_Reference => Arg.Time);
      pragma Assert (Readings_Status = Success or else Readings_Status = Stale);

      -- Convert to the C type. The corrected readings are doubles and the estimator
      -- works in single precision, so each cosine narrows here. The array crosses by
      -- pointer, so it needs an object to point at.
      Readings_C : aliased constant Css_Reading_Array.C.U_C :=
         (Cos_Values => [for I in Packed_F32x8.C.U_C'Range => Short_Float (Readings.Data (I))]);
   begin
      -- Apply any pending parameter update (e.g. a changed threshold or availability):
      Self.Update_Parameters;

      -- Call the C algorithm and publish each part of the estimate as its own
      -- product, so the guidance downstream can depend on the heading and the
      -- sensor count separately. Update is qualified because Parameter_Enums also
      -- declares one.
      declare
         Output : constant Css_Weighted_Least_Squares_Output.C.U_C :=
            Css_Weighted_Least_Squares_Algorithm_C.Update (Self.Alg, Cos_Values => Readings_C'Access);
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Sun_Heading_B (Arg.Time, Packed_F32x3.C.Pack (Output.Sun_Heading_B)));
         Self.Data_Product_T_Send (Self.Data_Products.Omega_Bn_B (Arg.Time, Packed_F32x3.C.Pack (Output.Omega_Bn_B)));
         Self.Data_Product_T_Send (Self.Data_Products.Post_Fit_Residuals (Arg.Time, Packed_F32x8.C.Pack (Output.Post_Fit_Residuals)));
         Self.Data_Product_T_Send (Self.Data_Products.Num_Css_Viewing_Sun (Arg.Time, (Value => Output.Num_Css_Viewing_Sun)));
      end;
   end Tick_T_Recv_Sync;

   -- Discard the prior heading so no rate is produced until two headings have been
   -- observed again. Called on GNC state change so a heading from the previous state
   -- is not differenced into a rate.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clears the runtime state only; the configuration is untouched.
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
   --    Parameters for the Css Weighted Least Squares component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new geometry,
   -- availability, weighting, and threshold. The control period is fixed at initialization and the
   -- prior heading is kept.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Css_N_Hat_B, Self.Css_Availability);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Css_N_Hat_B                 => Cfg.Boresights'Access,
         Css_Availability            => Cfg.Availability'Access,
         Use_Measurements_As_Weights => Interfaces.C.C_bool (Self.Use_Measurements_As_Weights.Value),
         Sensor_Use_Thresh           => Self.Sensor_Use_Thresh.Value,
         Control_Period              => Self.Control_Period);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Css_N_Hat_B : in Packed_F32x24.U;
      Css_Availability : in Css_Availability_X8.U;
      Use_Measurements_As_Weights : in Packed_Boolean.U;
      Sensor_Use_Thresh : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Css_N_Hat_B, Css_Availability);
      if Validate_Config (
         Css_N_Hat_B                 => Cfg.Boresights'Access,
         Css_Availability            => Cfg.Availability'Access,
         Use_Measurements_As_Weights => Interfaces.C.C_bool (Use_Measurements_As_Weights.Value),
         Sensor_Use_Thresh           => Sensor_Use_Thresh.Value,
         Control_Period              => Self.Control_Period)
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
   --    Data dependencies for the Css Weighted Least Squares component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Css_Weighted_Least_Squares.Implementation;
