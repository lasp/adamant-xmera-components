--------------------------------------------------------------------------------
-- Ephemerides_Recenter Component Implementation Body
--------------------------------------------------------------------------------

with Body_Ephemeris_Payload.C;
with Body_Ephemeris_Payload_X20_Record.C;
with Cartesian_State;
with Cartesian_State.C;
with Int32_X20_Record;
with Int32_X20_Record.C;

package body Component.Ephemerides_Recenter.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   overriding procedure Init (Self : in out Instance; New_Zero_Base_Id : in Interfaces.Integer_32; Previous_Common_Zero_Base_Id : in Interfaces.Integer_32; Body_0_Spice_Id : in Interfaces.Integer_32; Body_0_Original_Central_Body_Id : in Interfaces.Integer_32; Body_1_Spice_Id : in Interfaces.Integer_32; Body_1_Original_Central_Body_Id : in Interfaces.Integer_32; Body_2_Spice_Id : in Interfaces.Integer_32; Body_2_Original_Central_Body_Id : in Interfaces.Integer_32; Body_3_Spice_Id : in Interfaces.Integer_32; Body_3_Original_Central_Body_Id : in Interfaces.Integer_32) is
      -- Place the four configured bodies into the first slots of the C-boundary ID
      -- arrays (the algorithm indexes by position; trailing slots are unused). The
      -- component always configures exactly four bodies.
      Body_Ids : aliased Int32_X20_Record.C.U_C :=
         (Id => [0 => Body_0_Spice_Id,
                 1 => Body_1_Spice_Id,
                 2 => Body_2_Spice_Id,
                 3 => Body_3_Spice_Id,
                 others => 0]);
      Original_Central_Body_Ids : aliased Int32_X20_Record.C.U_C :=
         (Id => [0 => Body_0_Original_Central_Body_Id,
                 1 => Body_1_Original_Central_Body_Id,
                 2 => Body_2_Original_Central_Body_Id,
                 3 => Body_3_Original_Central_Body_Id,
                 others => 0]);
   begin
      -- Construct the C++ algorithm with the full configuration in one flattened call.
      -- Create validates the topology and pre-computes the moon hierarchy.
      --
      -- Gate the construction on the algorithm's own non-throwing predicate first.
      -- These values come from the assembly rather than the ground, so a
      -- configuration the algorithm would reject is a wiring error: assert instead
      -- of reporting, which turns a C++ exception escaping Init into a clean Ada
      -- assertion failure. The component has no parameters and no reconfiguration
      -- path, so Init is the only place this configuration can be refused.
      pragma Assert (Validate_Config (
         New_Central_Body_Id       => New_Zero_Base_Id,
         Previous_Central_Body_Id  => Previous_Common_Zero_Base_Id,
         Body_Ids                  => Body_Ids'Access,
         Original_Central_Body_Ids => Original_Central_Body_Ids'Access,
         Body_Count                => 4));
      Self.Alg := Create (
         New_Central_Body_Id       => New_Zero_Base_Id,
         Previous_Central_Body_Id  => Previous_Common_Zero_Base_Id,
         Body_Ids                  => Body_Ids'Access,
         Original_Central_Body_Ids => Original_Central_Body_Ids'Access,
         Body_Count                => 4);
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

      -- Fetch each body's input Cartesian state.
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert after each fetch.
      Body_0_State : Cartesian_State.T;
      Body_0_Status : constant Data_Dependency_Status.E :=
         Self.Get_Body_0_Ephemeris (Value => Body_0_State, Stale_Reference => Arg.Time);
      pragma Assert (Body_0_Status = Success);
      Body_1_State : Cartesian_State.T;
      Body_1_Status : constant Data_Dependency_Status.E :=
         Self.Get_Body_1_Ephemeris (Value => Body_1_State, Stale_Reference => Arg.Time);
      pragma Assert (Body_1_Status = Success);
      Body_2_State : Cartesian_State.T;
      Body_2_Status : constant Data_Dependency_Status.E :=
         Self.Get_Body_2_Ephemeris (Value => Body_2_State, Stale_Reference => Arg.Time);
      pragma Assert (Body_2_Status = Success);
      Body_3_State : Cartesian_State.T;
      Body_3_Status : constant Data_Dependency_Status.E :=
         Self.Get_Body_3_Ephemeris (Value => Body_3_State, Stale_Reference => Arg.Time);
      pragma Assert (Body_3_Status = Success);
   begin

      declare
         -- Convert Ada Cartesian_State.T to its C-compatible form for each body.
         Body_0_C : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Body_0_State));
         Body_1_C : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Body_1_State));
         Body_2_C : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Body_2_State));
         Body_3_C : constant Cartesian_State.C.U_C := Cartesian_State.C.To_C (Cartesian_State.Unpack (Body_3_State));

         -- Build the bounded-array input record in a single aggregate. The C
         -- shim reads all 20 entries; trailing entries are zero-padded. Spice
         -- IDs and isMoon are zero -- the algorithm indexes by position on
         -- update, the IDs were already supplied at Init via
         -- Add_Body_Ephemeris_To_Recenter.
         Input : aliased Body_Ephemeris_Payload_X20_Record.C.U_C := (
            Bodies => [
               0 => (
                  Body_Spice_Id => 0,
                  Original_Central_Body_Id => 0,
                  Is_Moon => 0,
                  Input_R => Body_0_C.Position,
                  Input_V => Body_0_C.Velocity,
                  Output_R => [others => 0.0],
                  Output_V => [others => 0.0]
               ),
               1 => (
                  Body_Spice_Id => 0,
                  Original_Central_Body_Id => 0,
                  Is_Moon => 0,
                  Input_R => Body_1_C.Position,
                  Input_V => Body_1_C.Velocity,
                  Output_R => [others => 0.0],
                  Output_V => [others => 0.0]
               ),
               2 => (
                  Body_Spice_Id => 0,
                  Original_Central_Body_Id => 0,
                  Is_Moon => 0,
                  Input_R => Body_2_C.Position,
                  Input_V => Body_2_C.Velocity,
                  Output_R => [others => 0.0],
                  Output_V => [others => 0.0]
               ),
               3 => (
                  Body_Spice_Id => 0,
                  Original_Central_Body_Id => 0,
                  Is_Moon => 0,
                  Input_R => Body_3_C.Position,
                  Input_V => Body_3_C.Velocity,
                  Output_R => [others => 0.0],
                  Output_V => [others => 0.0]
               ),
               others => (
                  Body_Spice_Id => 0,
                  Original_Central_Body_Id => 0,
                  Is_Moon => 0,
                  Input_R => [others => 0.0],
                  Input_V => [others => 0.0],
                  Output_R => [others => 0.0],
                  Output_V => [others => 0.0]
               )
            ]
         );

         -- Run the C algorithm.
         Output : constant Body_Ephemeris_Payload_X20_Record.C.U_C :=
            Update_State (Self.Alg, Input'Access);

         -- Helper to construct an output Cartesian_State.T from one body's
         -- algorithm output (r/v).
         function Build_Output_State
            (Out_Body : Body_Ephemeris_Payload.C.U_C) return Cartesian_State.T
         is
            Out_State_C : constant Cartesian_State.C.U_C := (
               Position => Out_Body.Output_R,
               Velocity => Out_Body.Output_V
            );
         begin
            return Cartesian_State.Pack (Cartesian_State.C.To_Ada (Out_State_C));
         end Build_Output_State;
      begin
         -- Send out a recentered Cartesian state data product for every body.
         Self.Data_Product_T_Send (Self.Data_Products.Body_0_Recentered (
            Arg.Time, Build_Output_State (Output.Bodies (0))
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Body_1_Recentered (
            Arg.Time, Build_Output_State (Output.Bodies (1))
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Body_2_Recentered (
            Arg.Time, Build_Output_State (Output.Bodies (2))
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Body_3_Recentered (
            Arg.Time, Build_Output_State (Output.Bodies (3))
         ));
      end;
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Ephemerides Recenter component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Ephemerides_Recenter.Implementation;
