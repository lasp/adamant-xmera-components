--------------------------------------------------------------------------------
-- Rw_Motor_Torque Component Implementation Body
--------------------------------------------------------------------------------

with Cmd_Torque_Body;
with Mrp_Feedback_Rw_Availability.C;
with Mrp_Feedback_Rw_Spin_Axes.C;
with Packed_F32x3.C;
with Packed_F32x3_X4.C;
with Rw_Motor_Torque_Control_Axes.C;
with Rw_Motor_Torque_Output.C;
with Rw_Speeds_Input.C;
with Rwa_Speeds;
with Wheel_Availability_X4.C;

package body Component.Rw_Motor_Torque.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Control_Axes : aliased Rw_Motor_Torque_Control_Axes.C.U_C;
      Rw_Spin_Axes : aliased Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Wheel_Availability : aliased Mrp_Feedback_Rw_Availability.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration. Every wheel slot is
   -- configured: the wheel count is a hardware fact fixed by the width of the wheel
   -- types, and a slot without a wheel is marked unavailable.
   function To_Pointer_Config (
      Control_Axes : in Rw_Motor_Torque_Control_Axes.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Wheel_Availability : in Wheel_Availability_X4.U
   ) return Pointer_Config is
      (Control_Axes => Rw_Motor_Torque_Control_Axes.C.To_C (Control_Axes),
       Rw_Spin_Axes => (Value => Packed_F32x3_X4.C.To_C (Rw_Spin_Axes)),
       Wheel_Availability => (Value => Wheel_Availability_X4.C.To_C (Wheel_Availability)));

   -- Gather the wheel speeds into the per-wheel array the shim expects.
   function To_C (Speeds : in Rwa_Speeds.T) return Rw_Speeds_Input.C.U_C is
      (Wheel_Speeds => [Speeds.Rwa_1, Speeds.Rwa_2, Speeds.Rwa_3, Speeds.Rwa_4]);

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the reaction wheel motor torque algorithm with the default parameter
   -- values.
   overriding procedure Init (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Control_Axes, Self.Rw_Spin_Axes, Self.Wheel_Availability);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Desired_Control_Axes_B => Cfg.Control_Axes'Access,
         Gs_Matrix_B            => Cfg.Rw_Spin_Axes'Access,
         Wheel_Availability     => Cfg.Wheel_Availability'Access,
         Omega_Gain             => Self.Omega_Gain.Value);
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
      -- The control torque is produced by the attitude control component earlier in
      -- the same tick, the wheel speeds are published fresh every tick by the wheel
      -- interface, and the desired speeds by the momentum management algorithm ahead
      -- of this component, so any other status indicates that this component is not
      -- wired up correctly in the algorithm execution order. That should never happen,
      -- so we assert.
      Torque : Cmd_Torque_Body.T;
      Torque_Status : constant Data_Dependency_Status.E :=
         Self.Get_Control_Torque (Value => Torque, Stale_Reference => Arg.Time);
      pragma Assert (Torque_Status = Success);
      Speeds : Rwa_Speeds.T;
      Speeds_Status : constant Data_Dependency_Status.E :=
         Self.Get_Wheel_Speeds (Value => Speeds, Stale_Reference => Arg.Time);
      pragma Assert (Speeds_Status = Success);
      Desired_Speeds : Rwa_Speeds.T;
      Desired_Speeds_Status : constant Data_Dependency_Status.E :=
         Self.Get_Desired_Wheel_Speeds (Value => Desired_Speeds, Stale_Reference => Arg.Time);
      pragma Assert (Desired_Speeds_Status = Success);

      -- Convert to C types. The wheel speeds cross by pointer, so they need objects to
      -- point at.
      Speeds_C : aliased constant Rw_Speeds_Input.C.U_C := To_C (Speeds);
      Desired_Speeds_C : aliased constant Rw_Speeds_Input.C.U_C := To_C (Desired_Speeds);
   begin
      -- Apply any pending parameter update (e.g. new wheel availability):
      Self.Update_Parameters;

      -- Call the C algorithm and send the per-wheel torques straight to the wheel
      -- interface. Update is qualified because Parameter_Enums also declares one.
      declare
         Output : constant Rw_Motor_Torque_Output.C.U_C := Rw_Motor_Torque_Algorithm_C.Update (
            Self.Alg,
            Lr_B              => (Value => Packed_F32x3.C.Unpack (Torque.Torque_Request_Body)),
            Rw_Speeds         => Speeds_C'Access,
            Rw_Desired_Speeds => Desired_Speeds_C'Access);
      begin
         Self.Rwa_Torques_T_Send_If_Connected ((
            Rwa_1 => Output.Motor_Torque (0),
            Rwa_2 => Output.Motor_Torque (1),
            Rwa_3 => Output.Motor_Torque (2),
            Rwa_4 => Output.Motor_Torque (3)));
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
   -- Description:
   --    Parameters for the Rw Motor Torque component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm, which recomputes the mapping for the new
   -- control axes, wheel geometry, availability, and gain.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Control_Axes, Self.Rw_Spin_Axes, Self.Wheel_Availability);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Desired_Control_Axes_B => Cfg.Control_Axes'Access,
         Gs_Matrix_B            => Cfg.Rw_Spin_Axes'Access,
         Wheel_Availability     => Cfg.Wheel_Availability'Access,
         Omega_Gain             => Self.Omega_Gain.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Control_Axes : in Rw_Motor_Torque_Control_Axes.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Wheel_Availability : in Wheel_Availability_X4.U;
      Omega_Gain : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Control_Axes, Rw_Spin_Axes, Wheel_Availability);
      if Validate_Config (
         Desired_Control_Axes_B => Cfg.Control_Axes'Access,
         Gs_Matrix_B            => Cfg.Rw_Spin_Axes'Access,
         Wheel_Availability     => Cfg.Wheel_Availability'Access,
         Omega_Gain             => Omega_Gain.Value)
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
   --    Data dependencies for the Rw Motor Torque component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Rw_Motor_Torque.Implementation;
