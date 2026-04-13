--------------------------------------------------------------------------------
-- Nav_Aggregate Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att.C;
with Nav_Trans.C;
with Ephemeris;
with Ephemeris.C;

package body Component.Nav_Aggregate.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the navigation aggregation algorithm with configuration indices.
   --
   -- Init Parameters:
   -- Att_Time_Idx : Interfaces.Unsigned_32 - Index of message to use for attitude
   -- time tag
   -- Trans_Time_Idx : Interfaces.Unsigned_32 - Index of message to use for
   -- translation time tag
   -- Att_Idx : Interfaces.Unsigned_32 - Index of message to use for inertial MRP
   -- attitude
   -- Rate_Idx : Interfaces.Unsigned_32 - Index of message to use for attitude rate
   -- Pos_Idx : Interfaces.Unsigned_32 - Index of message to use for inertial
   -- position
   -- Vel_Idx : Interfaces.Unsigned_32 - Index of message to use for inertial
   -- velocity
   -- Dv_Idx : Interfaces.Unsigned_32 - Index of message to use for accumulated DV
   -- Sun_Idx : Interfaces.Unsigned_32 - Index of message to use for sun pointing
   -- vector
   -- Att_Msg_Count : Interfaces.Unsigned_32 - Total number of attitude messages
   -- available as inputs
   -- Trans_Msg_Count : Interfaces.Unsigned_32 - Total number of translation messages
   -- available as inputs
   --
   overriding procedure Init (Self : in out Instance; Att_Time_Idx : in Interfaces.Unsigned_32; Trans_Time_Idx : in Interfaces.Unsigned_32; Att_Idx : in Interfaces.Unsigned_32; Rate_Idx : in Interfaces.Unsigned_32; Pos_Idx : in Interfaces.Unsigned_32; Vel_Idx : in Interfaces.Unsigned_32; Dv_Idx : in Interfaces.Unsigned_32; Sun_Idx : in Interfaces.Unsigned_32; Att_Msg_Count : in Interfaces.Unsigned_32; Trans_Msg_Count : in Interfaces.Unsigned_32) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;

      -- Store message counts for later use
      Self.Att_Msg_Count := Att_Msg_Count;
      Self.Trans_Msg_Count := Trans_Msg_Count;

      -- Configure the algorithm with the provided indices
      Set_Att_Time_Idx (Self.Alg, Att_Time_Idx);
      Set_Trans_Time_Idx (Self.Alg, Trans_Time_Idx);
      Set_Att_Idx (Self.Alg, Att_Idx);
      Set_Rate_Idx (Self.Alg, Rate_Idx);
      Set_Pos_Idx (Self.Alg, Pos_Idx);
      Set_Vel_Idx (Self.Alg, Vel_Idx);
      Set_Dv_Idx (Self.Alg, Dv_Idx);
      Set_Sun_Idx (Self.Alg, Sun_Idx);
      Set_Att_Msg_Count (Self.Alg, Att_Msg_Count);
      Set_Trans_Msg_Count (Self.Alg, Trans_Msg_Count);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the aggregation algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Attitude messages (will be populated based on Att_Msg_Count)
      -- Initialized to zero for safety in case not fetched
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert after each fetch.
      Att_Msg_0 : Nav_Att.T := Nav_Att.Serialization.From_Byte_Array ([others => 0]);
      Att_Msg_0_Status : Data_Dependency_Status.E := Success;
      Att_Msg_1 : Nav_Att.T := Nav_Att.Serialization.From_Byte_Array ([others => 0]);
      Att_Msg_1_Status : Data_Dependency_Status.E := Success;
      Att_Msg_2 : Nav_Att.T := Nav_Att.Serialization.From_Byte_Array ([others => 0]);
      Att_Msg_2_Status : Data_Dependency_Status.E := Success;
      Att_Msg_3 : Nav_Att.T := Nav_Att.Serialization.From_Byte_Array ([others => 0]);
      Att_Msg_3_Status : Data_Dependency_Status.E := Success;

      -- Translation messages (Ephemeris deps, converted to Nav_Trans for C algorithm)
      -- Initialized to zero for safety in case not fetched
      Trans_Msg_0 : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Trans_Msg_0_Status : Data_Dependency_Status.E := Success;
      Trans_Msg_1 : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Trans_Msg_1_Status : Data_Dependency_Status.E := Success;
      Trans_Msg_2 : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Trans_Msg_2_Status : Data_Dependency_Status.E := Success;
      Trans_Msg_3 : Ephemeris.T := Ephemeris.Serialization.From_Byte_Array ([others => 0]);
      Trans_Msg_3_Status : Data_Dependency_Status.E := Success;

   begin
      -- Fetch attitude messages based on configured count
      if Self.Att_Msg_Count >= 1 then
         Att_Msg_0_Status := Self.Get_Att_Msg_0 (Value => Att_Msg_0, Stale_Reference => Arg.Time);
         pragma Assert (Att_Msg_0_Status = Success);
      end if;
      if Self.Att_Msg_Count >= 2 then
         Att_Msg_1_Status := Self.Get_Att_Msg_1 (Value => Att_Msg_1, Stale_Reference => Arg.Time);
         pragma Assert (Att_Msg_1_Status = Success);
      end if;
      if Self.Att_Msg_Count >= 3 then
         Att_Msg_2_Status := Self.Get_Att_Msg_2 (Value => Att_Msg_2, Stale_Reference => Arg.Time);
         pragma Assert (Att_Msg_2_Status = Success);
      end if;
      if Self.Att_Msg_Count >= 4 then
         Att_Msg_3_Status := Self.Get_Att_Msg_3 (Value => Att_Msg_3, Stale_Reference => Arg.Time);
         pragma Assert (Att_Msg_3_Status = Success);
      end if;

      -- Fetch translation messages based on configured count
      if Self.Trans_Msg_Count >= 1 then
         Trans_Msg_0_Status := Self.Get_Trans_Msg_0 (Value => Trans_Msg_0, Stale_Reference => Arg.Time);
         pragma Assert (Trans_Msg_0_Status = Success);
      end if;
      if Self.Trans_Msg_Count >= 2 then
         Trans_Msg_1_Status := Self.Get_Trans_Msg_1 (Value => Trans_Msg_1, Stale_Reference => Arg.Time);
         pragma Assert (Trans_Msg_1_Status = Success);
      end if;
      if Self.Trans_Msg_Count >= 3 then
         Trans_Msg_2_Status := Self.Get_Trans_Msg_2 (Value => Trans_Msg_2, Stale_Reference => Arg.Time);
         pragma Assert (Trans_Msg_2_Status = Success);
      end if;
      if Self.Trans_Msg_Count >= 4 then
         Trans_Msg_3_Status := Self.Get_Trans_Msg_3 (Value => Trans_Msg_3, Stale_Reference => Arg.Time);
         pragma Assert (Trans_Msg_3_Status = Success);
      end if;

      -- All fetched dependencies available, call the algorithm
      declare
         -- Convert Ada types to C types for attitude messages
         Att_0_C : constant Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Att_Msg_0));
         Att_1_C : constant Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Att_Msg_1));
         Att_2_C : constant Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Att_Msg_2));
         Att_3_C : constant Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (Att_Msg_3));

         -- Convert Ephemeris deps to Nav_Trans C types for the algorithm:
         function Eph_To_Trans_C (Eph : in Ephemeris.T) return Nav_Trans.C.U_C is
            Eph_C : constant Ephemeris.C.U_C := Ephemeris.C.To_C (Ephemeris.Unpack (Eph));
         begin
            return (Time_Tag => Eph_C.Time_Tag,
                    R_Bn_N => Eph_C.R_Bdy_Zero_N,
                    V_Bn_N => Eph_C.V_Bdy_Zero_N,
                    Vehaccumdv => [others => 0.0]);
         end Eph_To_Trans_C;

         Trans_0_C : constant Nav_Trans.C.U_C := Eph_To_Trans_C (Trans_Msg_0);
         Trans_1_C : constant Nav_Trans.C.U_C := Eph_To_Trans_C (Trans_Msg_1);
         Trans_2_C : constant Nav_Trans.C.U_C := Eph_To_Trans_C (Trans_Msg_2);
         Trans_3_C : constant Nav_Trans.C.U_C := Eph_To_Trans_C (Trans_Msg_3);

         -- Zero-initialized C values for padding unused array entries
         Zero_Att_C : constant Nav_Att.C.U_C := Nav_Att.C.To_C (Nav_Att.Unpack (
            Nav_Att.Serialization.From_Byte_Array ([others => 0])));
         Zero_Trans_C : constant Nav_Trans.C.U_C := (Time_Tag => 0.0,
            R_Bn_N => [others => 0.0], V_Bn_N => [others => 0.0],
            Vehaccumdv => [others => 0.0]);

         -- Create C arrays sized to match MAX_AGG_NAV_MSG (10).
         -- The C shim reads all MAX_AGG_NAV_MSG entries during conversion,
         -- so the arrays must be fully sized to avoid a buffer overread.
         -- Entries beyond index 3 are zero-initialized.
         type Att_Array is array (0 .. MAX_AGG_NAV_MSG - 1) of aliased Nav_Att.C.U_C;
         type Trans_Array is array (0 .. MAX_AGG_NAV_MSG - 1) of aliased Nav_Trans.C.U_C;

         Att_Msgs : Att_Array := [0 => Att_0_C, 1 => Att_1_C, 2 => Att_2_C, 3 => Att_3_C, others => Zero_Att_C];
         Trans_Msgs : Trans_Array := [0 => Trans_0_C, 1 => Trans_1_C, 2 => Trans_2_C, 3 => Trans_3_C, others => Zero_Trans_C];

         -- Call the C algorithm
         Output : constant Aggregate_Output := Update (
            Self.Alg,
            Att_Msgs_Payloads => Att_Msgs (0)'Unchecked_Access,
            Trans_Msgs_Payloads => Trans_Msgs (0)'Unchecked_Access
         );
      begin
         -- Send out aggregated attitude data product
         Self.Data_Product_T_Send (Self.Data_Products.Aggregated_Nav_Att (
            Arg.Time,
            Nav_Att.Pack (Nav_Att.C.To_Ada (Output.Nav_Att_Out))
         ));

         -- Send out aggregated translation data product
         Self.Data_Product_T_Send (Self.Data_Products.Aggregated_Nav_Trans (
            Arg.Time,
            Nav_Trans.Pack (Nav_Trans.C.To_Ada (Output.Nav_Trans_Out))
         ));
      end;
   end Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Nav Aggregate component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Nav_Aggregate.Implementation;
