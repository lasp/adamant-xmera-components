--------------------------------------------------------------------------------
-- Thr_Firing_Schmitt Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x8.C;

package body Component.Thr_Firing_Schmitt.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster firing Schmitt algorithm.
   overriding procedure Init (Self : in out Instance) is
      Max_Thrust_C : aliased constant Packed_F32x8.C.U_C := Packed_F32x8.C.To_C (Self.Max_Thrust);
   begin
      Self.Alg := Create (
         Max_Thrust                => Max_Thrust_C'Access,
         Level_On                  => Self.Levels.Level_On,
         Level_Off                 => Self.Levels.Level_Off,
         Thr_Min_Fire_Time         => Self.Thr_Min_Fire_Time.Value,
         Control_Period            => Self.Control_Period.Value,
         On_Time_Saturation_Factor => Self.On_Time_Saturation_Factor.Value,
         Pulsing_Regime            => To_C (Self.Thrust_Pulsing_Regime.Value));
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
   begin
      -- TODO statements
      null;
   end Tick_T_Recv_Sync;

   -- Reset the algorithm's Schmitt-trigger hysteresis state. Called on GNC state
   -- change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
   begin
      -- TODO statements
      null;
   end Reset_Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

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
