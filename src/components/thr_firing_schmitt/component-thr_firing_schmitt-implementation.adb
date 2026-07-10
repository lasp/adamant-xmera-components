--------------------------------------------------------------------------------
-- Thr_Firing_Schmitt Component Implementation Body
--------------------------------------------------------------------------------

with Thr_Force_Cmd;
with Thr_On_Time_Cmd;
with Thr_Firing_Schmitt_Force_Cmd.C;
with Thr_Firing_Schmitt_On_Time_Cmd.C;

package body Component.Thr_Firing_Schmitt.Implementation is

   -- Number of thrusters in the system (8-element data products vs 36-element C API)
   Num_Thrusters : constant := 8;

   -- Build the C config POD from the current component parameters and the
   -- Ada-side thruster array. The control values come from the component
   -- parameters; the thruster array is set by Configure_Thrusters and tracked
   -- on the instance.
   function Make_Config (Self : Instance) return Thr_Firing_Schmitt_Config_C is
     (Thruster_Array     => Self.Thruster_Array,
      Control_Parameters =>
        (Level_On                  => Self.Levels.Level_On,
         Level_Off                 => Self.Levels.Level_Off,
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time.Value,
         Control_Period            => Self.Control_Period.Value,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor.Value,
         Pulsing_Regime            =>
           Thr_Firing_Schmitt_Pulsing_Regime'Val (Natural (Self.Thrust_Pulsing_Regime.Value))));

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster firing Schmitt algorithm.
   overriding procedure Init (Self : in out Instance) is
      -- Build the initial configuration from the parameter defaults and the
      -- empty (zero-thruster) array. Both are valid, so Create will not reject
      -- them.
      Config : aliased Thr_Firing_Schmitt_Config_C := Make_Config (Self);
   begin
      -- Allocate the C++ algorithm on the heap with the initial configuration.
      Self.Alg := Create (Config'Access);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   not overriding procedure Configure_Thrusters (
      Self   : in out Instance;
      Config : access constant Thr_Firing_Schmitt_Array_Config)
   is
   begin
      -- Extract the per-thruster maximum thrust (the only field the Schmitt
      -- algorithm consumes) into the Ada-side thruster array.
      Self.Thruster_Array.Num_Thrusters := Config.Num_Thrusters;
      Self.Thruster_Array.Max_Thrust := [others => 0.0];
      for I in Config.Thrusters'Range loop
         Self.Thruster_Array.Max_Thrust (I) := Config.Thrusters (I).Max_Thrust;
      end loop;

      -- Push the updated thruster array into the algorithm via a config swap.
      declare
         Cfg : aliased Thr_Firing_Schmitt_Config_C := Make_Config (Self);
      begin
         Set_Config (Self.Alg, Cfg'Access);
      end;
   end Configure_Thrusters;

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
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      Force_Dep : Thr_Force_Cmd.T;
      Force_Status : constant Data_Dependency_Status.E :=
         Self.Get_Thruster_Force_Cmd (Value => Force_Dep, Stale_Reference => Arg.Time);
      pragma Assert (Force_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      declare
         -- Unpack 8-element dependency
         Force_Dep_U : constant Thr_Force_Cmd.U := Thr_Force_Cmd.Unpack (Force_Dep);

         -- Build 36-element C input (zeroed, then copy 8 thruster values)
         Force_36 : aliased Thr_Firing_Schmitt_Force_Cmd.C.U_C := (Thr_Force => [others => 0.0]);
      begin
         for I in 0 .. Num_Thrusters - 1 loop
            Force_36.Thr_Force (I) := Force_Dep_U.Thr_Force (I);
         end loop;

         declare
            -- Call the C algorithm
            On_Time_36 : constant Thr_Firing_Schmitt_On_Time_Cmd.C.U_C :=
               Update (Self.Alg, Force_36'Unchecked_Access);

            -- Extract first 8 elements for output
            On_Time_Result : Thr_On_Time_Cmd.U := (On_Time_Request => [others => 0.0]);
         begin
            for I in 0 .. Num_Thrusters - 1 loop
               On_Time_Result.On_Time_Request (I) := On_Time_36.On_Time_Request (I);
            end loop;

            Self.Data_Product_T_Send (Self.Data_Products.On_Time_Cmd (
               Arg.Time,
               Thr_On_Time_Cmd.Pack (On_Time_Result)
            ));
         end;
      end;
   end Tick_T_Recv_Sync;

   -- Reset the algorithm's Schmitt-trigger hysteresis state. Called on GNC state
   -- change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
   begin
      -- Clear the algorithm's previous-state thruster history.
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
   -- This procedure is called when the parameters of a component have been updated.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
      -- Rebuild the algorithm configuration from the updated parameters. The
      -- values were checked by Validate_Parameters at staging, so Set_Config
      -- will not reject them.
      Config : aliased Thr_Firing_Schmitt_Config_C := Make_Config (Self);
   begin
      Set_Config (Self.Alg, Config'Access);
   end Update_Parameters_Action;

   -- Invalid Parameter handler. This procedure is called when a parameter's type is found to be invalid:
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the parameters should be invalid in this case.
      pragma Assert (False);
   end Invalid_Parameter;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Thr_Firing_Schmitt.Implementation;
