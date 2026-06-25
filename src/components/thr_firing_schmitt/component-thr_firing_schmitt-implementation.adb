--------------------------------------------------------------------------------
-- Thr_Firing_Schmitt Component Implementation Body
--------------------------------------------------------------------------------

package body Component.Thr_Firing_Schmitt.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the thruster firing Schmitt algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
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
      Set_Thrusters (Self.Alg, Config);
   end Configure_Thrusters;

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
   -- Parameter handlers:
   -----------------------------------------------
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
