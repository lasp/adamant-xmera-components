--------------------------------------------------------------------------------
-- Dv_Maneuver Component Implementation Body
--------------------------------------------------------------------------------

with Dv_Maneuver_Enums;
with Dv_Maneuver_Output.C;
with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Dv_Maneuver.Implementation is

   -- The parts of the configuration the shim takes by pointer, held together so a
   -- caller can pass 'Access of each field. Init, Apply_Config and
   -- Validate_Parameters all marshal the same values, so it is assembled in one place.
   type Pointer_Config is record
      Cmd_Force_B : aliased Packed_F32x3_Record.C.U_C;
      Cmd_Dv_N : aliased Packed_F32x3_Record.C.U_C;
   end record;

   -- Marshal the pointer arguments of the configuration: the body force and the
   -- commanded delta-V.
   function To_Pointer_Config (Cmd_Force_B : in Packed_F32x3.U; Cmd_Dv_N : in Packed_F32x3.U) return Pointer_Config is
      ((Cmd_Force_B => (Value => Packed_F32x3.C.To_C (Cmd_Force_B)),
        Cmd_Dv_N => (Value => Packed_F32x3.C.To_C (Cmd_Dv_N))));

   -- Push the component's current parameters into the algorithm. They were validated
   -- by the algorithm's predicate at staging, so Set_Config will not reject them. The
   -- burn state is kept, so a complete burn stays complete.
   procedure Apply_Config (Self : in out Instance) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Cmd_Force_B, Self.Cmd_Dv_N);
   begin
      Set_Config (
         Self.Alg,
         Min_Time       => Self.Min_Time.Value,
         Max_Time       => Self.Max_Time.Value,
         Control_Period => Self.Control_Period,
         Cmd_Force_B    => Cfg.Cmd_Force_B'Access,
         Cmd_Dv_N       => Cfg.Cmd_Dv_N'Access);
   end Apply_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V burn executor with the control period and the default
   -- parameter values, a stand-in burn which the first burn command replaces.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Long_Float - [s] Time between two
   -- algorithm updates. The burn time advances by this much per tick, so it must
   -- equal the rate at which the component is scheduled. Fixed by the assembly, so it
   -- is not a runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Long_Float) is
      Cfg : aliased constant Pointer_Config := To_Pointer_Config (Self.Cmd_Force_B, Self.Cmd_Dv_N);
   begin
      Self.Control_Period := Control_Period;
      -- Create throws on an invalid configuration, so the parameter defaults must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks them at startup
      -- and in unit test set up. The control period's type keeps it positive.
      Self.Alg := Create (
         Min_Time       => Self.Min_Time.Value,
         Max_Time       => Self.Max_Time.Value,
         Control_Period => Self.Control_Period,
         Cmd_Force_B    => Cfg.Cmd_Force_B'Access,
         Cmd_Dv_N       => Cfg.Cmd_Dv_N'Access);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Advance the burn one step and publish the force command and the burn state.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The accumulated delta-V is produced every tick, earlier in the same tick, so
      -- any other status indicates that this component is not wired up correctly in
      -- the algorithm execution order. That should never happen, so we assert.
      Delta_V : Packed_F32x3.T;
      Delta_V_Status : constant Data_Dependency_Status.E :=
         Self.Get_Accumulated_Delta_V (Value => Delta_V, Stale_Reference => Arg.Time);
      pragma Assert (Delta_V_Status = Success);

      -- The delta-V crosses by pointer, so it needs an object to point at.
      Delta_V_C : aliased constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Delta_V));
   begin
      -- Apply any pending parameter update, so a new burn takes effect on the tick
      -- after its update, the first tick after the reset that starts it:
      Self.Update_Parameters;

      -- Advance the burn and publish the force command and the burn state. Update is
      -- qualified because Parameter_Enums also declares one.
      declare
         Output : constant Dv_Maneuver_Output.C.U_C := Dv_Maneuver_Algorithm_C.Update (Self.Alg, Dv_Accumulated_B => Delta_V_C'Access);
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Commanded_Force (
            Arg.Time,
            (Force_Request_Body => Packed_F32x3.C.Pack (Output.Cmd_Force_B))
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Burn_State (
            Arg.Time,
            (Value => Dv_Maneuver_Enums.Burn_State.C.To_Ada (Output.State))
         ));
      end;
   end Tick_T_Recv_Sync;

   -- Restart the burn at the next tick. The assembly fires this when the burn is to
   -- start.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Apply any pending parameter update first, so the reset starts from the
      -- configuration the component runs with next:
      Self.Update_Parameters;
      -- Resets the burn state machine only; the configuration is untouched.
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
   --    Parameters for the Dv Maneuver component. The body force depends on the
   --    thrusters in use, so it is set for a mission phase rather than per burn. The
   --    burn times and the commanded delta-V define a burn, so they are set when a
   --    burn is commanded, before the burn is started with the reset. The defaults
   --    form a valid configuration and stand in until then.
   -- This procedure is called when the parameters of a component have been updated. In this
   -- case we push the whole configuration into the C algorithm. The control period is fixed
   -- at initialization and the burn state is kept, so a complete burn stays complete.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The values were checked by Validate_Parameters at staging, so Set_Config will
      -- not reject them.
      Apply_Config (Self);
   end Update_Parameters_Action;

   -- Validate a staged configuration before it is applied by asking the algorithm's
   -- own non-throwing Validate_Config predicate, so the config rules live solely in
   -- the algorithm. Rejecting an invalid update here at staging keeps it from reaching
   -- the throwing Create and Set_Config across the FFI boundary.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Cmd_Force_B : in Packed_F32x3.U;
      Min_Time : in Packed_F64.U;
      Max_Time : in Packed_F64.U;
      Cmd_Dv_N : in Packed_F32x3.U
   ) return Parameter_Validation_Status.E is
      -- Filled in below, inside the handled part of the function, so that a copy that
      -- raises is caught here.
      Cfg : aliased Pointer_Config;
   begin
      Cfg := To_Pointer_Config (Cmd_Force_B, Cmd_Dv_N);
      if Validate_Config (
         Min_Time       => Min_Time.Value,
         Max_Time       => Max_Time.Value,
         Control_Period => Self.Control_Period,
         Cmd_Force_B    => Cfg.Cmd_Force_B'Access,
         Cmd_Dv_N       => Cfg.Cmd_Dv_N'Access)
      then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   exception
      -- Reachable, and the parameter rejection test covers it: the staging type check
      -- of an array accepts a non-finite element, and copying it above raises.
      -- Rejecting the set here keeps that from unwinding into the requester.
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
   --    Data dependencies for the Dv Maneuver component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Dv_Maneuver.Implementation;
