--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Component Implementation Body
--------------------------------------------------------------------------------

with Stepper_Enums;

package body Component.Stepper_Motor_Controller.Implementation is

   -- Push the component's current parameter values into the C++ algorithm.
   -- Every reconfiguration path goes through here so the configuration is
   -- assembled in exactly one place.
   procedure Apply_Config (Self : in out Instance) is
   begin
      Set_Config (
         Self.Alg,
         Step_Angle       => Self.Step_Angle.Value,
         Min_Angle        => Self.Motor_Min_Angle.Value,
         Max_Angle        => Self.Motor_Max_Angle.Value,
         Settle_Count_Max => Self.Settle_Count_Max.Value,
         Min_Step_Command => Self.Min_Step_Command.Value);
   end Apply_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the stepper motor controller algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      Self.Alg := Create (
         Step_Angle       => Self.Step_Angle.Value,
         Min_Angle        => Self.Motor_Min_Angle.Value,
         Max_Angle        => Self.Motor_Max_Angle.Value,
         Settle_Count_Max => Self.Settle_Count_Max.Value,
         Min_Step_Command => Self.Min_Step_Command.Value);
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
      -- The motor interface publishes the motor state when the device answers a
      -- status copy, and seeds an initial value at Set_Up -- the timestamp ages
      -- while the device is quiet, so Stale is a legitimate runtime state, not
      -- a defect. The last stored position remains the best estimate: a step
      -- commanded against slightly-old state self-corrects on later cycles, and
      -- the motor interface rejects commands its axis cannot accept.
      -- Not_Available or Error indicates the component is not wired up
      -- correctly in the algorithm execution order. This should never happen,
      -- so we assert.
      Motor_State : Stepper_Motor_State.T;
      Motor_State_Status : constant Data_Dependency_Status.E :=
         Self.Get_Motor_State (Value => Motor_State, Stale_Reference => Arg.Time);
      pragma Assert (Motor_State_Status in Success | Stale);

      -- The reference angle is a goal from the upstream pointing algorithm and
      -- persists until replaced, so tracking the last commanded value while the
      -- product is stale is the intended behavior. The producer seeds an
      -- initial value at Set_Up; only Not_Available or Error indicates a
      -- wiring defect.
      Reference_Angle : Packed_F32.T;
      Reference_Angle_Status : constant Data_Dependency_Status.E :=
         Self.Get_Reference_Angle (Value => Reference_Angle, Stale_Reference => Arg.Time);
      pragma Assert (Reference_Angle_Status in Success | Stale);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call algorithm:
      declare
         use type Stepper_Enums.Motion_Status.E;

         -- Run one tick of the controller state machine against the fetched
         -- motor state and reference angle:
         Output : constant Update_Result := Stepper_Motor_Controller_Algorithm_C.Update (
            Self.Alg,
            Current_Position => Motor_State.Current_Position,
            Reference_Angle => Reference_Angle.Value,
            Is_Motor_Moving => Motor_State.Is_Moving = Stepper_Enums.Motion_Status.Moving
         );
      begin
         -- Map the algorithm output onto the step command interface. A positive
         -- step delta maps to a clockwise step command and a negative delta to
         -- a counter-clockwise one; a STOP maps to Halt; a NONE takes no
         -- action. A zero-step move is absorbed as a no-op rather than sent as
         -- an empty command.
         case Output.Command is
            when None =>
               null;
            when Stop =>
               Self.Stepper_Controller_Step_T_Send_If_Connected ((
                  Command => Stepper_Enums.Command_Type.Halt,
                  Num_Steps => 0
               ));
            when Move =>
               if Output.Steps_To_Move /= 0 then
                  declare
                     -- Compute the step magnitude in a wider type so that the
                     -- most negative 32-bit delta cannot overflow, and saturate
                     -- it to the range of the step command's Num_Steps field. A
                     -- saturated move self-corrects: once the motor settles, the
                     -- controller commands the remaining delta on a later cycle.
                     Magnitude : constant Integer_64 := abs Integer_64 (Output.Steps_To_Move);
                     Saturated : constant Boolean := Magnitude > Integer_64 (Unsigned_16'Last);
                     Num_Steps : constant Unsigned_16 :=
                        (if Saturated then Unsigned_16'Last else Unsigned_16 (Magnitude));
                     Step_Command : constant Stepper_Controller_Step.T := (
                        Command => (if Output.Steps_To_Move >= 0
                                    then Stepper_Enums.Command_Type.Step_Cw
                                    else Stepper_Enums.Command_Type.Step_Ccw),
                        Num_Steps => Num_Steps
                     );
                  begin
                     if Saturated then
                        Self.Event_T_Send_If_Connected (Self.Events.Step_Command_Saturated (
                           Arg.Time, (Commanded_Delta => Output.Steps_To_Move, Sent_Command => Step_Command)));
                     end if;
                     Self.Stepper_Controller_Step_T_Send_If_Connected (Step_Command);
                  end;
               end if;
         end case;
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
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      Apply_Config (Self);
   end Update_Parameters_Action;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Stepper Motor Controller component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Stepper_Motor_Controller.Implementation;
