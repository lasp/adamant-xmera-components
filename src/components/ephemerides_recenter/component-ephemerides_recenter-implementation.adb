--------------------------------------------------------------------------------
-- Ephemerides_Recenter Component Implementation Body
--------------------------------------------------------------------------------

with Body_Ephemeris_Payload.C;
with Body_Ephemeris_Payload_X20_Record.C;
with Body_To_Recenter;
with Body_To_Recenter.C;
with Ephemeris;
with Ephemeris.C;

package body Component.Ephemerides_Recenter.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   overriding procedure Init (Self : in out Instance; New_Zero_Base_Id : in Interfaces.Integer_32; Previous_Common_Zero_Base_Id : in Interfaces.Integer_32; Body_Count : in Interfaces.Unsigned_32; Body_0_Spice_Id : in Interfaces.Integer_32; Body_0_Original_Central_Body_Id : in Interfaces.Integer_32; Body_1_Spice_Id : in Interfaces.Integer_32; Body_1_Original_Central_Body_Id : in Interfaces.Integer_32; Body_2_Spice_Id : in Interfaces.Integer_32; Body_2_Original_Central_Body_Id : in Interfaces.Integer_32; Body_3_Spice_Id : in Interfaces.Integer_32; Body_3_Original_Central_Body_Id : in Interfaces.Integer_32) is
      Body_0 : aliased Body_To_Recenter.C.U_C := (
         Body_Spice_Id => Body_0_Spice_Id,
         Original_Central_Body_Id => Body_0_Original_Central_Body_Id);
      Body_1 : aliased Body_To_Recenter.C.U_C := (
         Body_Spice_Id => Body_1_Spice_Id,
         Original_Central_Body_Id => Body_1_Original_Central_Body_Id);
      Body_2 : aliased Body_To_Recenter.C.U_C := (
         Body_Spice_Id => Body_2_Spice_Id,
         Original_Central_Body_Id => Body_2_Original_Central_Body_Id);
      Body_3 : aliased Body_To_Recenter.C.U_C := (
         Body_Spice_Id => Body_3_Spice_Id,
         Original_Central_Body_Id => Body_3_Original_Central_Body_Id);
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
      Self.Body_Count := Body_Count;

      -- Add each configured body in order. Bodies must be added before
      -- Set_Previous_Common_Zero_Base, which validates its argument against
      -- the populated body list immediately (it does NOT defer validation
      -- to Reset). The C++ algorithm orders bodies by insertion; the data
      -- dependency index matches that ordering.
      if Body_Count >= 1 then
         Add_Body_Ephemeris_To_Recenter (Self.Alg, Body_0'Unchecked_Access);
      end if;
      if Body_Count >= 2 then
         Add_Body_Ephemeris_To_Recenter (Self.Alg, Body_1'Unchecked_Access);
      end if;
      if Body_Count >= 3 then
         Add_Body_Ephemeris_To_Recenter (Self.Alg, Body_2'Unchecked_Access);
      end if;
      if Body_Count >= 4 then
         Add_Body_Ephemeris_To_Recenter (Self.Alg, Body_3'Unchecked_Access);
      end if;

      -- Configure central bodies. Set_Previous_Common_Zero_Base validates
      -- the given SPICE ID exists in the body list and throws otherwise.
      Set_Previous_Common_Zero_Base (Self.Alg, Previous_Common_Zero_Base_Id);
      Set_New_Zero_Base_Id (Self.Alg, New_Zero_Base_Id);

      -- Validate the topology and pre-compute moon hierarchy.
      Reset (Self.Alg);
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

      -- Body input ephemerides. Initialized to zero in case Body_Count
      -- gates a fetch off; the algorithm will see zero r/v for those slots.
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert after each fetch.
      Body_0_Eph : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Body_0_Status : Data_Dependency_Status.E := Success;
      Body_1_Eph : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Body_1_Status : Data_Dependency_Status.E := Success;
      Body_2_Eph : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Body_2_Status : Data_Dependency_Status.E := Success;
      Body_3_Eph : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Body_3_Status : Data_Dependency_Status.E := Success;
   begin
      -- Fetch each configured body's input ephemeris.
      if Self.Body_Count >= 1 then
         Body_0_Status := Self.Get_Body_0_Ephemeris (Value => Body_0_Eph, Stale_Reference => Arg.Time);
         pragma Assert (Body_0_Status = Success);
      end if;
      if Self.Body_Count >= 2 then
         Body_1_Status := Self.Get_Body_1_Ephemeris (Value => Body_1_Eph, Stale_Reference => Arg.Time);
         pragma Assert (Body_1_Status = Success);
      end if;
      if Self.Body_Count >= 3 then
         Body_2_Status := Self.Get_Body_2_Ephemeris (Value => Body_2_Eph, Stale_Reference => Arg.Time);
         pragma Assert (Body_2_Status = Success);
      end if;
      if Self.Body_Count >= 4 then
         Body_3_Status := Self.Get_Body_3_Ephemeris (Value => Body_3_Eph, Stale_Reference => Arg.Time);
         pragma Assert (Body_3_Status = Success);
      end if;

      declare
         -- Convert Ada Ephemeris.T to its C-compatible form for each body.
         Body_0_C : constant Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Body_0_Eph));
         Body_1_C : constant Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Body_1_Eph));
         Body_2_C : constant Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Body_2_Eph));
         Body_3_C : constant Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Body_3_Eph));

         -- Zero-initialized payload for unused array slots.
         Zero_Payload : constant Body_Ephemeris_Payload.C.U_C := (
            Body_Spice_Id => 0,
            Original_Central_Body_Id => 0,
            Is_Moon => 0,
            Input_R => [others => 0.0],
            Input_V => [others => 0.0],
            Output_R => [others => 0.0],
            Output_V => [others => 0.0]
         );

         -- Helper to produce a payload from one fetched ephemeris. Spice IDs
         -- and isMoon are zero — the algorithm indexes by position on update,
         -- the IDs were already supplied at Init via Add_Body_Ephemeris_To_Recenter.
         function Make_Payload (Eph_C : Ephemeris.C.U_C) return Body_Ephemeris_Payload.C.U_C is
         begin
            return (
               Body_Spice_Id => 0,
               Original_Central_Body_Id => 0,
               Is_Moon => 0,
               Input_R => Eph_C.R_Bdy_Zero_N,
               Input_V => Eph_C.V_Bdy_Zero_N,
               Output_R => [others => 0.0],
               Output_V => [others => 0.0]
            );
         end Make_Payload;

         -- Build the bounded-array input record. The C shim reads all 20
         -- entries; trailing entries are zero-padded.
         Input : aliased Body_Ephemeris_Payload_X20_Record.C.U_C := (
            Bodies => [
               0 => Make_Payload (Body_0_C),
               1 => Make_Payload (Body_1_C),
               2 => Make_Payload (Body_2_C),
               3 => Make_Payload (Body_3_C),
               others => Zero_Payload
            ]
         );

         -- Run the C algorithm.
         Output : constant Body_Ephemeris_Payload_X20_Record.C.U_C :=
            Update_State (Self.Alg, Input'Unchecked_Access);

         -- Helper to construct an output Ephemeris.T from one body's algorithm
         -- output (r/v) plus the fetched input's sigma/omega/time pass-through.
         function Build_Output_Ephemeris
            (Out_Body : Body_Ephemeris_Payload.C.U_C;
             In_Eph_C : Ephemeris.C.U_C) return Ephemeris.T
         is
            Out_Eph_C : constant Ephemeris.C.U_C := (
               R_Bdy_Zero_N => Out_Body.Output_R,
               V_Bdy_Zero_N => Out_Body.Output_V,
               Sigma_Bn => In_Eph_C.Sigma_Bn,
               Omega_Bn_B => In_Eph_C.Omega_Bn_B,
               Time_Tag => In_Eph_C.Time_Tag
            );
         begin
            return Ephemeris.Pack (Ephemeris.C.To_Ada (Out_Eph_C));
         end Build_Output_Ephemeris;
      begin
         -- Send out a recentered ephemeris data product for every body slot.
         -- Slots beyond Body_Count receive a zero-valued ephemeris because
         -- the algorithm leaves those output slots untouched.
         Self.Data_Product_T_Send (Self.Data_Products.Body_0_Recentered (
            Arg.Time, Build_Output_Ephemeris (Output.Bodies (0), Body_0_C)
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Body_1_Recentered (
            Arg.Time, Build_Output_Ephemeris (Output.Bodies (1), Body_1_C)
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Body_2_Recentered (
            Arg.Time, Build_Output_Ephemeris (Output.Bodies (2), Body_2_C)
         ));
         Self.Data_Product_T_Send (Self.Data_Products.Body_3_Recentered (
            Arg.Time, Build_Output_Ephemeris (Output.Bodies (3), Body_3_C)
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
