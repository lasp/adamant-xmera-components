--------------------------------------------------------------------------------
-- Momentum_Management Component Implementation Body
--------------------------------------------------------------------------------

with Mrp_Feedback_Rw_Availability.C;
with Mrp_Feedback_Rw_Inertias.C;
with Mrp_Feedback_Rw_Spin_Axes.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Packed_F32x3_X4.C;
with Packed_F32x4;
with Packed_F32x9;
with Packed_F32x9_Record.C;
with Rw_Speeds_Input.C;
with Rwa_Speeds;
with Wheel_Availability_X4.C;

package body Component.Momentum_Management.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Dumpable_Projection : aliased Packed_F32x9_Record.C.U_C;
      Hs_Desired : aliased Packed_F32x3_Record.C.U_C;
      Rw_Spin_Axes : aliased Mrp_Feedback_Rw_Spin_Axes.C.U_C;
      Rw_Inertias : aliased Mrp_Feedback_Rw_Inertias.C.U_C;
      Wheel_Availability : aliased Mrp_Feedback_Rw_Availability.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration. Every wheel slot is
   -- configured: the wheel count is a hardware fact fixed by the width of the wheel
   -- types, and a slot without a wheel is marked unavailable.
   function To_Pointer_Config (
      Dumpable_Projection : in Packed_F32x9.U;
      Hs_Desired : in Packed_F32x3.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Rw_Inertias : in Packed_F32x4.U;
      Wheel_Availability : in Wheel_Availability_X4.U
   ) return Pointer_Config is
      (Dumpable_Projection => (Value => [for I in Dumpable_Projection'Range => Dumpable_Projection (I)]),
       Hs_Desired => (Value => [for I in Hs_Desired'Range => Hs_Desired (I)]),
       Rw_Spin_Axes => (Value => Packed_F32x3_X4.C.To_C (Rw_Spin_Axes)),
       Rw_Inertias => (Value => [for I in Rw_Inertias'Range => Rw_Inertias (I)]),
       Wheel_Availability => (Value => Wheel_Availability_X4.C.To_C (Wheel_Availability)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the momentum management algorithm with the control period and the
   -- default parameter values.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates. The momentum integral advances by this much per tick, so it
   -- must equal the rate at which the component is scheduled. Fixed by the assembly,
   -- so it is not a runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (
         Self.Dumpable_Projection, Self.Hs_Desired, Self.Rw_Spin_Axes, Self.Rw_Inertias, Self.Wheel_Availability);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (
         Hs_Min                => Self.Hs_Min.Value,
         K                     => Self.Proportional_Gain_K.Value,
         Ki                    => Self.Integral_Gain_Ki.Value,
         Integral_Limit        => Self.Integral_Limit.Value,
         Control_Period        => Self.Control_Period,
         Dumpable_Projection_B => Cfg.Dumpable_Projection'Access,
         Hs_Desired_B          => Cfg.Hs_Desired'Access,
         Gs_Matrix_B           => Cfg.Rw_Spin_Axes'Access,
         Js_List               => Cfg.Rw_Inertias'Access,
         Wheel_Availability    => Cfg.Wheel_Availability'Access);
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
      -- The wheel speeds are published every tick upstream of this component, so any
      -- other status indicates that this component is not wired up correctly in the
      -- algorithm execution order. That should never happen, so we assert.
      Speeds : Rwa_Speeds.T;
      Speeds_Status : constant Data_Dependency_Status.E :=
         Self.Get_Wheel_Speeds (Value => Speeds, Stale_Reference => Arg.Time);
      pragma Assert (Speeds_Status = Success);

      -- Gather the wheel speeds into the per-wheel array the shim expects. It crosses
      -- by pointer, so it needs an object to point at.
      Speeds_C : aliased constant Rw_Speeds_Input.C.U_C :=
         (Wheel_Speeds => [Speeds.Rwa_1, Speeds.Rwa_2, Speeds.Rwa_3, Speeds.Rwa_4]);
   begin
      -- Apply any pending parameter update (e.g. new gains or wheel availability):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the requested torque. Update is qualified
      -- because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Commanded_Torque (
         Arg.Time,
         (Torque_Request_Body => Packed_F32x3.C.Pack (Momentum_Management_Algorithm_C.Update (
            Self.Alg, Wheel_Speeds => Speeds_C'Access).Value))
      ));
   end Tick_T_Recv_Sync;

   -- Zero the integral of the momentum difference. Called on GNC state change so the
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
   --    Parameters for the Momentum Management component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm so subsequent updates use the new threshold,
   -- gains, projection, desired momentum, and wheel configuration. The control period is fixed at
   -- initialization and the integral state is kept.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (
         Self.Dumpable_Projection, Self.Hs_Desired, Self.Rw_Spin_Axes, Self.Rw_Inertias, Self.Wheel_Availability);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Hs_Min                => Self.Hs_Min.Value,
         K                     => Self.Proportional_Gain_K.Value,
         Ki                    => Self.Integral_Gain_Ki.Value,
         Integral_Limit        => Self.Integral_Limit.Value,
         Control_Period        => Self.Control_Period,
         Dumpable_Projection_B => Cfg.Dumpable_Projection'Access,
         Hs_Desired_B          => Cfg.Hs_Desired'Access,
         Gs_Matrix_B           => Cfg.Rw_Spin_Axes'Access,
         Js_List               => Cfg.Rw_Inertias'Access,
         Wheel_Availability    => Cfg.Wheel_Availability'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Hs_Min : in Packed_F32.U;
      Proportional_Gain_K : in Packed_F32.U;
      Integral_Gain_Ki : in Packed_F32.U;
      Integral_Limit : in Packed_F32.U;
      Dumpable_Projection : in Packed_F32x9.U;
      Hs_Desired : in Packed_F32x3.U;
      Rw_Spin_Axes : in Packed_F32x3_X4.U;
      Rw_Inertias : in Packed_F32x4.U;
      Wheel_Availability : in Wheel_Availability_X4.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Dumpable_Projection, Hs_Desired, Rw_Spin_Axes, Rw_Inertias, Wheel_Availability);
      if Validate_Config (
         Hs_Min                => Hs_Min.Value,
         K                     => Proportional_Gain_K.Value,
         Ki                    => Integral_Gain_Ki.Value,
         Integral_Limit        => Integral_Limit.Value,
         Control_Period        => Self.Control_Period,
         Dumpable_Projection_B => Cfg.Dumpable_Projection'Access,
         Hs_Desired_B          => Cfg.Hs_Desired'Access,
         Gs_Matrix_B           => Cfg.Rw_Spin_Axes'Access,
         Js_List               => Cfg.Rw_Inertias'Access,
         Wheel_Availability    => Cfg.Wheel_Availability'Access)
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
   --    Data dependencies for the Momentum Management component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Momentum_Management.Implementation;
