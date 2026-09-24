--------------------------------------------------------------------------------
-- Mrp_Steering Component Implementation Body
--------------------------------------------------------------------------------

with Att_Guid;
with Att_Guid.C;
with Interfaces.C;
with Mrp_Feedback_Rw_Availability.C;
with Mrp_Feedback_Rw_Inertias.C;
with Mrp_Feedback_Rw_Spin_Axes.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_F32x3_X4.C;
with Packed_F32x4.C;
with Packed_F32x9.C;
with Packed_F32x9_Record.C;
with Rw_Speeds_Input.C;
with Rwa_Speeds;
with Wheel_Availability_X4.C;

package body Component.Mrp_Steering.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Known_Torque : aliased Packed_F32x3_Record.C.U_C;
      Inertia : aliased Packed_F32x9_Record.C.U_C;
      Rw_Spin_Axes : aliased Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Rw_Inertias : aliased Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability : aliased Mrp_Feedback_Rw_Availability.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration. Every wheel slot is
   -- configured: the wheel count is a hardware fact fixed by the width of the wheel
   -- types, and a slot without a wheel is marked unavailable.
   function To_Pointer_Config (
      Known_Torque_Pnt_B_B : in Packed_F32x3.U;
      Inertia : in Packed_F32x9.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Rw_Inertias : in Packed_F32x4.U;
      Wheel_Availability : in Wheel_Availability_X4.U
   ) return Pointer_Config is
      (Known_Torque => (Value => Packed_F32x3.C.To_C (Known_Torque_Pnt_B_B)),
       Inertia => (Value => Packed_F32x9.C.To_C (Inertia)),
       Rw_Spin_Axes => (Value => Packed_F32x3_X4.C.To_C (Rw_Spin_Axes)),
       Rw_Inertias => (Value => Packed_F32x4.C.To_C (Rw_Inertias)),
       Wheel_Availability => (Value => Wheel_Availability_X4.C.To_C (Wheel_Availability)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the MRP steering algorithm with the control period and the default
   -- parameter values.
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (
         Self.Known_Torque_Pnt_B_B, Self.Inertia, Self.Rw_Spin_Axes, Self.Rw_Inertias, Self.Wheel_Availability);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (
         K1                            => Self.Proportional_Gain_K1.Value,
         K3                            => Self.Cubic_Gain_K3.Value,
         Omega_Max                     => Self.Omega_Max.Value,
         Ignore_Outer_Loop_Feedforward => Interfaces.C.C_bool (Self.Ignore_Outer_Loop_Feedforward.Value),
         P                             => Self.Derivative_Gain_P.Value,
         Ki                            => Self.Integral_Gain_Ki.Value,
         Integral_Limit                => Self.Integral_Limit.Value,
         Control_Period                => Self.Control_Period,
         Known_Torque_Pnt_B_B          => Cfg.Known_Torque'Access,
         Iscpnt_B_B                    => Cfg.Inertia'Access,
         Gs_Matrix_B                   => Cfg.Rw_Spin_Axes'Access,
         Js_List                       => Cfg.Rw_Inertias'Access,
         Wheel_Availability            => Cfg.Wheel_Availability'Access);
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
      -- The guidance solution is produced by the attitude tracking error component
      -- earlier in the same tick, and the wheel speeds are published fresh every tick
      -- by the wheel interface, so any other status indicates that this component is
      -- not wired up correctly in the algorithm execution order. That should never
      -- happen, so we assert.
      Guidance : Att_Guid.T;
      Guidance_Status : constant Data_Dependency_Status.E :=
         Self.Get_Attitude_Guidance (Value => Guidance, Stale_Reference => Arg.Time);
      pragma Assert (Guidance_Status = Success);
      Speeds : Rwa_Speeds.T;
      Speeds_Status : constant Data_Dependency_Status.E :=
         Self.Get_Wheel_Speeds (Value => Speeds, Stale_Reference => Arg.Time);
      pragma Assert (Speeds_Status = Success);

      -- Convert to C types. The guidance message and the algorithm's guidance input
      -- share one layout, so the dependency crosses with no intermediate record. The
      -- wheel speeds are gathered into the per-wheel array the shim expects. Both
      -- cross by pointer, so they need objects to point at.
      Guidance_C : aliased constant Att_Guid.C.U_C := Att_Guid.C.Unpack (Guidance);
      Speeds_C : aliased constant Rw_Speeds_Input.C.U_C :=
         (Wheel_Speeds => [Speeds.Rwa_1, Speeds.Rwa_2, Speeds.Rwa_3, Speeds.Rwa_4]);
   begin
      -- Apply any pending parameter update (e.g. new gains or wheel availability):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the torque. Update is qualified because
      -- Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Control_Torque (
         Arg.Time,
         (Torque_Request_Body => Packed_F32x3.C.Pack (Mrp_Steering_Algorithm_C.Update (
            Self.Alg,
            Att_Guid_Input => Guidance_C'Access,
            Wheel_Speeds   => Speeds_C'Access).Value))
      ));
   end Tick_T_Recv_Sync;

   -- Zero the integral of the rate tracking error. Called on GNC state change so the
   -- integral does not carry over from the previous state.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clears the integral state only; the configuration is untouched.
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
   --    Parameters for the Mrp Steering component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new gains,
   -- known torque, inertia, and wheel configuration. The control period is fixed at
   -- initialization and the integral state is kept.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (
         Self.Known_Torque_Pnt_B_B, Self.Inertia, Self.Rw_Spin_Axes, Self.Rw_Inertias, Self.Wheel_Availability);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         K1                            => Self.Proportional_Gain_K1.Value,
         K3                            => Self.Cubic_Gain_K3.Value,
         Omega_Max                     => Self.Omega_Max.Value,
         Ignore_Outer_Loop_Feedforward => Interfaces.C.C_bool (Self.Ignore_Outer_Loop_Feedforward.Value),
         P                             => Self.Derivative_Gain_P.Value,
         Ki                            => Self.Integral_Gain_Ki.Value,
         Integral_Limit                => Self.Integral_Limit.Value,
         Control_Period                => Self.Control_Period,
         Known_Torque_Pnt_B_B          => Cfg.Known_Torque'Access,
         Iscpnt_B_B                    => Cfg.Inertia'Access,
         Gs_Matrix_B                   => Cfg.Rw_Spin_Axes'Access,
         Js_List                       => Cfg.Rw_Inertias'Access,
         Wheel_Availability            => Cfg.Wheel_Availability'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Proportional_Gain_K1 : in Packed_F32.U;
      Cubic_Gain_K3 : in Packed_F32.U;
      Omega_Max : in Packed_F32.U;
      Ignore_Outer_Loop_Feedforward : in Packed_Boolean.U;
      Derivative_Gain_P : in Packed_F32.U;
      Integral_Gain_Ki : in Packed_F32.U;
      Integral_Limit : in Packed_F32.U;
      Known_Torque_Pnt_B_B : in Packed_F32x3.U;
      Inertia : in Packed_F32x9.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Rw_Inertias : in Packed_F32x4.U;
      Wheel_Availability : in Wheel_Availability_X4.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Known_Torque_Pnt_B_B, Inertia, Rw_Spin_Axes, Rw_Inertias, Wheel_Availability);
      if Validate_Config (
         K1                            => Proportional_Gain_K1.Value,
         K3                            => Cubic_Gain_K3.Value,
         Omega_Max                     => Omega_Max.Value,
         Ignore_Outer_Loop_Feedforward => Interfaces.C.C_bool (Ignore_Outer_Loop_Feedforward.Value),
         P                             => Derivative_Gain_P.Value,
         Ki                            => Integral_Gain_Ki.Value,
         Integral_Limit                => Integral_Limit.Value,
         Control_Period                => Self.Control_Period,
         Known_Torque_Pnt_B_B          => Cfg.Known_Torque'Access,
         Iscpnt_B_B                    => Cfg.Inertia'Access,
         Gs_Matrix_B                   => Cfg.Rw_Spin_Axes'Access,
         Js_List                       => Cfg.Rw_Inertias'Access,
         Wheel_Availability            => Cfg.Wheel_Availability'Access)
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
   --    Data dependencies for the Mrp Steering component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Mrp_Steering.Implementation;
