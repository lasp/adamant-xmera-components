--------------------------------------------------------------------------------
-- Torque_Thr_Force_Mapping Component Implementation Body
--------------------------------------------------------------------------------

with Cmd_Torque_Body;
with Desired_Control_Axes.C;
with Packed_F32x3_Record.C;
with Thr_Force_Cmd.C;
with Thruster_Availability_Array.C;
with Thruster_Geometry_Array.C;

package body Component.Torque_Thr_Force_Mapping.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Update_Parameters_Action, and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      R_Thruster : aliased Thruster_Geometry_Array.C.U_C;
      T_Hat_Thruster : aliased Thruster_Geometry_Array.C.U_C;
      Center_Of_Mass : aliased Packed_F32x3_Record.C.U_C;
      Control_Axes : aliased Desired_Control_Axes.C.U_C;
      Availability : aliased Thruster_Availability_Array.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration.
   function To_Pointer_Config (
      R_Thruster_B : in Packed_F32x24.U;
      T_Hat_Thruster_B : in Packed_F32x24.U;
      Center_Of_Mass_B : in Packed_F32x3.U;
      Desired_Control_Axes_B : in Desired_Control_Axes.U;
      Thruster_Availability : in Thruster_Availability_X8.U
   ) return Pointer_Config is
      (R_Thruster => Thruster_Geometry_Array.C.To_C ((Value => R_Thruster_B)),
       T_Hat_Thruster => Thruster_Geometry_Array.C.To_C ((Value => T_Hat_Thruster_B)),
       Center_Of_Mass => Packed_F32x3_Record.C.To_C ((Value => Center_Of_Mass_B)),
       Control_Axes => Desired_Control_Axes.C.To_C (Desired_Control_Axes_B),
       Availability => Thruster_Availability_Array.C.To_C ((Value => Thruster_Availability)));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster force mapping algorithm with the default parameter
   -- values.
   overriding procedure Init (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (
         Self.R_Thruster_B, Self.T_Hat_Thruster_B, Self.Center_Of_Mass_B, Self.Desired_Control_Axes_B, Self.Thruster_Availability);
   begin
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up.
      Self.Alg := Create (
         Num_Thrusters          => Self.Num_Thrusters.Value,
         R_Thruster_B           => Cfg.R_Thruster'Access,
         T_Hat_Thruster_B       => Cfg.T_Hat_Thruster'Access,
         Center_Of_Mass_B       => Cfg.Center_Of_Mass'Access,
         Desired_Control_Axes_B => Cfg.Control_Axes'Access,
         Thruster_Availability  => Cfg.Availability'Access);
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
      use Data_Product_Enums.Data_Dependency_Status;

      -- The controller republishes the torque command on every tick of this
      -- synchronous call chain, upstream of this component. Any other status indicates
      -- a wiring or execution-order defect, so we assert; the stale check is the
      -- integration-order alarm.
      Torque_Dep : Cmd_Torque_Body.T;
      Torque_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Commanded_Torque (Value => Torque_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Torque_Status = Success);

      -- The command crosses by reference, so it needs an aliased object.
      Torque_C : aliased constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.Unpack ((Value => Torque_Dep.Torque_Request_Body));
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- The commanded force is a parameter, zero for the states this component serves.
      -- The algorithm takes it by pointer, so it is marshalled after the parameter
      -- update into an aliased object.
      declare
         Force_C : aliased constant Packed_F32x3_Record.C.U_C := Packed_F32x3_Record.C.To_C ((Value => Self.Cmd_Force_B));
      begin
         -- Map the torque and force onto the thrusters and publish the result:
         Self.Data_Product_T_Send (Self.Data_Products.Thruster_Force_Cmd (
            Arg.Time,
            Thr_Force_Cmd.C.Pack (Update (Self.Alg, Cmd_Torque_B => Torque_C'Access, Cmd_Force_B => Force_C'Access))
         ));
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
   --    Parameters for the Torque Thr Force Mapping component. The geometry parameters
   --    are the same as the force torque thruster force mapping parameters, since both
   --    components configure the same algorithm. The commanded force is a parameter here
   --    rather than a data dependency.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm, which recomputes the thruster mapping
   -- matrix. The commanded force is not part of the configuration; each tick reads it from the
   -- parameter store. The algorithm carries no other runtime state.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (
         Self.R_Thruster_B, Self.T_Hat_Thruster_B, Self.Center_Of_Mass_B, Self.Desired_Control_Axes_B, Self.Thruster_Availability);
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will not
      -- reject them.
      Set_Config (
         Self.Alg,
         Num_Thrusters          => Self.Num_Thrusters.Value,
         R_Thruster_B           => Cfg.R_Thruster'Access,
         T_Hat_Thruster_B       => Cfg.T_Hat_Thruster'Access,
         Center_Of_Mass_B       => Cfg.Center_Of_Mass'Access,
         Desired_Control_Axes_B => Cfg.Control_Axes'Access,
         Thruster_Availability  => Cfg.Availability'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Num_Thrusters : in Packed_U32.U;
      R_Thruster_B : in Packed_F32x24.U;
      T_Hat_Thruster_B : in Packed_F32x24.U;
      Center_Of_Mass_B : in Packed_F32x3.U;
      Desired_Control_Axes_B : in Desired_Control_Axes.U;
      Thruster_Availability : in Thruster_Availability_X8.U;
      Cmd_Force_B : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
      -- Filled in below, inside the handled part of the function, so that a conversion
      -- that raises is caught here.
      Cfg : aliased Pointer_Config;
      Force_C : Packed_F32x3_Record.C.U_C;
   begin
      Cfg := To_Pointer_Config (R_Thruster_B, T_Hat_Thruster_B, Center_Of_Mass_B, Desired_Control_Axes_B, Thruster_Availability);
      -- The force is not part of the algorithm configuration, so the only check it needs
      -- is the one this conversion performs: a non-finite component raises.
      Force_C := Packed_F32x3_Record.C.To_C ((Value => Cmd_Force_B));
      pragma Unreferenced (Force_C);
      if Validate_Config (
         Num_Thrusters          => Num_Thrusters.Value,
         R_Thruster_B           => Cfg.R_Thruster'Access,
         T_Hat_Thruster_B       => Cfg.T_Hat_Thruster'Access,
         Center_Of_Mass_B       => Cfg.Center_Of_Mass'Access,
         Desired_Control_Axes_B => Cfg.Control_Axes'Access,
         Thruster_Availability  => Cfg.Availability'Access)
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
   --    Data dependencies for the Torque Thr Force Mapping component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Torque_Thr_Force_Mapping.Implementation;
