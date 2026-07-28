--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Component Implementation Body
--------------------------------------------------------------------------------

with Stepper_Enums;
with Stepper_Motor_Controller_Output.C;

package body Component.Stepper_Motor_Controller.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the stepper motor controller algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;

      -- Apply the Ada parameter defaults to the algorithm: the framework
      -- invokes Update_Parameters_Action only after a ground parameter
      -- update, and the C++ constructor defaults do not match the Ada
      -- defaults.
      Self.Update_Parameters_Action;
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
      -- The motor interface publishes an initial motor state at Set_Up, so a
      -- current or stale value is always available. Stale is acceptable: the
      -- state may simply not have been republished since the last tick.
      -- Not_Available or Error indicates the component is not wired up
      -- correctly in the algorithm execution order. This should never happen,
      -- so we assert.
      Motor_State : Stepper_Motor_State.T;
      Motor_State_Status : constant Data_Dependency_Status.E :=
         Self.Get_Motor_State (Value => Motor_State, Stale_Reference => Arg.Time);
      pragma Assert (Motor_State_Status in Success | Stale);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      -- Call algorithm:
      declare
         use type Stepper_Enums.Motion_Status.E;

         -- Run one tick of the controller state machine. The reference angle is
         -- a parameter passed through to the algorithm each tick:
         Output : constant Stepper_Motor_Controller_Output.C.U_C := Stepper_Motor_Controller_Algorithm_C.Update (
            Self.Alg,
            Current_Position => Motor_State.Current_Position,
            Reference_Angle => Self.Reference_Angle.Value,
            Is_Motor_Moving => Motor_State.Is_Moving = Stepper_Enums.Motion_Status.Moving
         );
      begin
         -- Map the algorithm output onto the step command interface. A positive
         -- step delta maps to a clockwise step command and a negative delta to a
         -- counter-clockwise one; a STOP maps to Halt. No command is sent when
         -- the algorithm output is NONE.
         if Output.Command_Type = Stepper_Motor_Command_Type'Pos (Move) then
            declare
               -- Compute the step magnitude in a wider type so that the most
               -- negative 32-bit delta cannot overflow, and saturate it to the
               -- range of the step command's Num_Steps field. A saturated move
               -- self-corrects: once the motor settles, the controller commands
               -- the remaining delta on a later cycle.
               Magnitude : constant Integer_64 := abs Integer_64 (Output.Steps_To_Move);
               Saturated : constant Boolean := Magnitude > Integer_64 (Unsigned_16'Last);
               Num_Steps : constant Unsigned_16 :=
                  (if Saturated then Unsigned_16'Last else Unsigned_16 (Magnitude));
            begin
               if Saturated then
                  Self.Event_T_Send_If_Connected (Self.Events.Step_Command_Saturated (
                     Arg.Time, (Value => Output.Steps_To_Move)));
               end if;
               Self.Stepper_Controller_Step_T_Send_If_Connected ((
                  Command => (if Output.Steps_To_Move >= 0
                              then Stepper_Enums.Command_Type.Step_Cw
                              else Stepper_Enums.Command_Type.Step_Ccw),
                  Num_Steps => Num_Steps
               ));
            end;
         elsif Output.Command_Type = Stepper_Motor_Command_Type'Pos (Stop) then
            Self.Stepper_Controller_Step_T_Send_If_Connected ((
               Command => Stepper_Enums.Command_Type.Halt,
               Num_Steps => 0
            ));
         end if;
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
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Set algorithm configuration from parameters. Reference_Angle is not
      -- applied here; it is passed to the algorithm update each tick.
      Set_Step_Angle (Self.Alg, Self.Step_Angle.Value);
      Set_Motor_Angle_Range (Self.Alg,
         Min_Angle => Self.Motor_Min_Angle.Value,
         Max_Angle => Self.Motor_Max_Angle.Value);
      Set_Settle_Count_Max (Self.Alg, Self.Settle_Count_Max.Value);
      Set_Min_Step_Command (Self.Alg, Self.Min_Step_Command.Value);
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
