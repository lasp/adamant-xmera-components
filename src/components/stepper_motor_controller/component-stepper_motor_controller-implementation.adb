--------------------------------------------------------------------------------
-- Stepper_Motor_Controller Component Implementation Body
--------------------------------------------------------------------------------

with Data_Product_Enums;
with Interfaces; use Interfaces;
with Stepper_Enums;
with Stepper_Motor_Controller_Output;
with Stepper_Motor_Controller_Output.C;
with Stepper_Motor_State;

package body Component.Stepper_Motor_Controller.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the stepper motor controller algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate the C++ algorithm instance on the heap.
      Self.Alg := Create;
      -- Configure the algorithm with the staged parameters (the model defaults until a
      -- parameter table is loaded), so it is never left unconfigured.
      Self.Update_Parameters;
   end Init;

   -- Destroys the stepper motor controller algorithm.
   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ algorithm instance.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;
      use Stepper_Enums;
      use type Stepper_Enums.Motion_Status.E;

      -- Grab the motor state data dependency. The motor interface publishes an initial motor
      -- state at Set_Up, so a current (or stale) value is available from boot; Not_Available or
      -- Error indicates the component is not wired up correctly in the algorithm execution
      -- order. This should never happen, so we assert.
      Motor_State : Stepper_Motor_State.T;
      Motor_State_Status : constant Data_Dependency_Status.E :=
         Self.Get_Motor_State (Value => Motor_State, Stale_Reference => Arg.Time);
   begin
      pragma Assert (Motor_State_Status in Success | Stale);

      -- Apply any staged parameter updates to the algorithm before running it:
      Self.Update_Parameters;

      -- Run the algorithm against the motor state and the reference-angle parameter, then
      -- translate its command into a step or halt for the motor interface:
      declare
         Output : constant Stepper_Motor_Controller_Output.U := Stepper_Motor_Controller_Output.C.To_Ada (Update (
            Self.Alg,
            Current_Position => Motor_State.Current_Position,
            Reference_Angle => Self.Reference_Angle.Value,
            Is_Motor_Moving => Motor_State.Is_Moving = Motion_Status.Moving));
         -- Direction from the sign of Steps_To_Move: a positive delta drives the motor Position
         -- up, which is a Clockwise step per the CODE convention (the positive count maps to
         -- Clockwise -- see Set_Interface_Neg_Pos_Count and the device up/down step counter);
         -- a negative delta is Counterclockwise.
         Step_Direction : constant Stepper_Enums.Command_Type.E :=
            (if Output.Steps_To_Move >= 0 then Command_Type.Step_Cw else Command_Type.Step_Ccw);
      begin
         case Output.Command_Type is
            when Algorithm_Command.Move =>
               -- The algorithm cannot legitimately command more than a full rotation in one
               -- move, so a step delta wider than the Stepper_Controller_Step connector's
               -- Num_Steps (Unsigned_16) field indicates an algorithm defect. This should never
               -- happen, so we assert. A zero-step move is absorbed as a no-op rather than sent
               -- as an empty command:
               pragma Assert (abs Output.Steps_To_Move <= Integer_32 (Unsigned_16'Last));
               if Output.Steps_To_Move /= 0 then
                  Self.Stepper_Controller_Step_T_Send ((Command => Step_Direction, Num_Steps => Unsigned_16 (abs Output.Steps_To_Move)));
               end if;
            when Algorithm_Command.Stop =>
               -- A STOP halts the current motion (e.g. a mid-move retarget):
               Self.Stepper_Controller_Step_T_Send ((Command => Command_Type.Halt, Num_Steps => 0));
            when Algorithm_Command.None =>
               -- The algorithm wants no action; nothing is sent to the motor interface:
               null;
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
   -- Apply the algorithm configuration parameters to the C++ algorithm. Called after a parameter
   -- update and via Self.Update_Parameters each tick. Reference_Angle is excluded -- it is passed
   -- to the algorithm's update step each tick rather than set as configuration.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- The post-move enable hold keeps the motor reported as moving, providing that much of the
      -- desired settle duration before the settling wait begins. Apply the remainder, saturating
      -- at zero:
      Settle_Count : constant Unsigned_32 :=
         (if Self.Settle_Count_Max.Value > Self.Enable_Hold_Count.Value
          then Self.Settle_Count_Max.Value - Self.Enable_Hold_Count.Value
          else 0);
   begin
      Set_Step_Angle (Self.Alg, Self.Step_Angle.Value);
      Set_Motor_Angle_Range (Self.Alg, Self.Motor_Min_Angle.Value, Self.Motor_Max_Angle.Value);
      Set_Settle_Count_Max (Self.Alg, Settle_Count);
      Set_Min_Step_Command (Self.Alg, Self.Min_Step_Command.Value);
   end Update_Parameters_Action;

   -- Invalid Parameter handler. This procedure is called when a parameter's type is found to be invalid:
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
   begin
      -- A malformed parameter (bad type or length) can arrive from a ground upload, so report it as
      -- an event rather than asserting:
      Self.Event_T_Send_If_Connected (Self.Events.Invalid_Parameter_Received (Self.Sys_Time_T_Get, (
         Id => Par.Header.Id,
         Errant_Field_Number => Errant_Field_Number,
         Errant_Field => Errant_Field)
      ));
   end Invalid_Parameter;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- The motor state data dependency should never be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Stepper_Motor_Controller.Implementation;
