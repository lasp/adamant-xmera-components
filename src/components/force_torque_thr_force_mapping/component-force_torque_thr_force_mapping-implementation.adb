--------------------------------------------------------------------------------
-- Force_Torque_Thr_Force_Mapping Component Implementation Body
--------------------------------------------------------------------------------

with Cmd_Force_Body;
with Cmd_Torque_Body;
with Desired_Control_Axes.C;
with Packed_F32x3_Record.C;
with Thr_Force_Cmd.C;
with Thruster_Availability_Array.C;
with Thruster_Geometry_Array.C;

package body Component.Force_Torque_Thr_Force_Mapping.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the force torque thruster force mapping algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- The configuration crosses by reference, so each argument needs an aliased
      -- object to point at and cannot be marshalled inline.
      R_Thruster_C : aliased constant Thruster_Geometry_Array.C.U_C :=
         Thruster_Geometry_Array.C.To_C ((Value => Self.R_Thruster_B));
      T_Hat_Thruster_C : aliased constant Thruster_Geometry_Array.C.U_C :=
         Thruster_Geometry_Array.C.To_C ((Value => Self.T_Hat_Thruster_B));
      Center_Of_Mass_C : aliased constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.To_C ((Value => Self.Center_Of_Mass_B));
      Control_Axes_C : aliased constant Desired_Control_Axes.C.U_C :=
         Desired_Control_Axes.C.To_C (Self.Desired_Control_Axes_B);
      Availability_C : aliased constant Thruster_Availability_Array.C.U_C :=
         Thruster_Availability_Array.C.To_C ((Value => Self.Thruster_Availability));
   begin
      Self.Alg := Create (
         Num_Thrusters          => Self.Num_Thrusters.Value,
         R_Thruster_B           => R_Thruster_C'Access,
         T_Hat_Thruster_B       => T_Hat_Thruster_C'Access,
         Center_Of_Mass_B       => Center_Of_Mass_C'Access,
         Desired_Control_Axes_B => Control_Axes_C'Access,
         Thruster_Availability  => Availability_C'Access);
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

      -- The controller republishes both commands on every tick of this synchronous
      -- call chain, upstream of this component. Any other status indicates a wiring
      -- or execution-order defect, so we assert; the stale check is the
      -- integration-order alarm.
      Torque_Dep : Cmd_Torque_Body.T;
      Torque_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Commanded_Torque (Value => Torque_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Torque_Status = Success);

      Force_Dep : Cmd_Force_Body.T;
      Force_Status : constant Data_Product_Enums.Data_Dependency_Status.E :=
         Self.Get_Commanded_Force (Value => Force_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Force_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call the algorithm:
      declare
         -- Both commands cross by reference, so each needs an aliased object.
         Torque_C : aliased constant Packed_F32x3_Record.C.U_C :=
            Packed_F32x3_Record.C.Unpack ((Value => Torque_Dep.Torque_Request_Body));
         Force_C : aliased constant Packed_F32x3_Record.C.U_C :=
            Packed_F32x3_Record.C.Unpack ((Value => Force_Dep.Force_Request_Body));
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Thruster_Force_Cmd (
            Arg.Time,
            Thr_Force_Cmd.C.Pack (Update (Self.Alg, Torque_C'Access, Force_C'Access))
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
   -- Apply parameters to the C algorithm when they are updated. The values were
   -- checked by Validate_Parameters at staging, so Set_Config will not reject them.
   -- Set_Config recomputes the thruster mapping matrix; the algorithm carries no
   -- other runtime state.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      R_Thruster_C : aliased constant Thruster_Geometry_Array.C.U_C :=
         Thruster_Geometry_Array.C.To_C ((Value => Self.R_Thruster_B));
      T_Hat_Thruster_C : aliased constant Thruster_Geometry_Array.C.U_C :=
         Thruster_Geometry_Array.C.To_C ((Value => Self.T_Hat_Thruster_B));
      Center_Of_Mass_C : aliased constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.To_C ((Value => Self.Center_Of_Mass_B));
      Control_Axes_C : aliased constant Desired_Control_Axes.C.U_C :=
         Desired_Control_Axes.C.To_C (Self.Desired_Control_Axes_B);
      Availability_C : aliased constant Thruster_Availability_Array.C.U_C :=
         Thruster_Availability_Array.C.To_C ((Value => Self.Thruster_Availability));
   begin
      Set_Config (
         Self.Alg,
         Num_Thrusters          => Self.Num_Thrusters.Value,
         R_Thruster_B           => R_Thruster_C'Access,
         T_Hat_Thruster_B       => T_Hat_Thruster_C'Access,
         Center_Of_Mass_B       => Center_Of_Mass_C'Access,
         Desired_Control_Axes_B => Control_Axes_C'Access,
         Thruster_Availability  => Availability_C'Access);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's
   -- own non-throwing Validate_Config predicate, so the config rules live solely in
   -- the algorithm. Rejecting an invalid update here at staging keeps it from reaching
   -- the throwing Create/Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Num_Thrusters : in Packed_U32.U;
      R_Thruster_B : in Packed_F32x24.U;
      T_Hat_Thruster_B : in Packed_F32x24.U;
      Center_Of_Mass_B : in Packed_F32x3.U;
      Desired_Control_Axes_B : in Desired_Control_Axes.U;
      Thruster_Availability : in Thruster_Availability_X8.U
   ) return Parameter_Validation_Status.E is
      pragma Unreferenced (Self);
      R_Thruster_C : aliased constant Thruster_Geometry_Array.C.U_C :=
         Thruster_Geometry_Array.C.To_C ((Value => R_Thruster_B));
      T_Hat_Thruster_C : aliased constant Thruster_Geometry_Array.C.U_C :=
         Thruster_Geometry_Array.C.To_C ((Value => T_Hat_Thruster_B));
      Center_Of_Mass_C : aliased constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.To_C ((Value => Center_Of_Mass_B));
      Control_Axes_C : aliased constant Desired_Control_Axes.C.U_C :=
         Desired_Control_Axes.C.To_C (Desired_Control_Axes_B);
      Availability_C : aliased constant Thruster_Availability_Array.C.U_C :=
         Thruster_Availability_Array.C.To_C ((Value => Thruster_Availability));
   begin
      if Validate_Config (
            Num_Thrusters          => Num_Thrusters.Value,
            R_Thruster_B           => R_Thruster_C'Access,
            T_Hat_Thruster_B       => T_Hat_Thruster_C'Access,
            Center_Of_Mass_B       => Center_Of_Mass_C'Access,
            Desired_Control_Axes_B => Control_Axes_C'Access,
            Thruster_Availability  => Availability_C'Access)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Force Torque Thr Force Mapping component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Force_Torque_Thr_Force_Mapping.Implementation;
