--------------------------------------------------------------------------------
-- Oe_State_Ephem Tests Body
--------------------------------------------------------------------------------

with Ada.Numerics.Long_Elementary_Functions;
with Basic_Assertions; use Basic_Assertions;
with Basic_Types;
with Cartesian_State;
with Interfaces; use Interfaces;
with Memory_Region;
with Oe_Arc;
with Oe_Arc_Records;
with Oe_Coefficients;
with Oe_State_Ephem_Enums;
with Oe_State_Ephem_Parameter_Table;
with Packed_F64x20;
with Packed_F64x3;
with Packed_F64x3.Assertion; use Packed_F64x3.Assertion;
with Parameter_Enums;
with Parameters_Memory_Region_Release;
with Parameters_Memory_Region_Release.Assertion; use Parameters_Memory_Region_Release.Assertion;
with System;

package body Oe_State_Ephem_Tests.Implementation is

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Build a "minimum valid" arc: one Chebyshev coefficient slot (the
   -- algorithm rejects zero-coefficient arcs), all coefficients zero,
   -- True_Anomaly flag, zero time.
   function Zero_Arc return Oe_Arc.U is
      use Oe_State_Ephem_Enums;
      Zero_Coeff : constant Oe_Coefficients.U := (Data => [others => 0.0]);
   begin
      return (
         Number_Of_Coefficients => (Value => 1),
         -- Middle_Time and Radius_Time must be strictly positive per the C++
         -- algorithm's setter validation; pick small canonical values.
         Middle_Time => 1.0,
         Radius_Time => 0.5,
         Anomaly_Flag => Anomaly_Type.True_Anomaly,
         Radius_Periapsis => Zero_Coeff,
         Eccentricity => Zero_Coeff,
         Inclination => Zero_Coeff,
         Arg_Periapsis => Zero_Coeff,
         Raan => Zero_Coeff,
         True_Anomaly => Zero_Coeff
      );
   end Zero_Arc;

   -- Build a "minimum valid" parameter table: zero Mu, exactly one zero arc.
   -- The C++ algorithm requires Number_Of_Arcs >= 1 and per-arc
   -- Number_Of_Coefficients >= 1, so a literal all-zero table can't be the
   -- default. With Mu = 0 and zero coefficients the algorithm output is
   -- (numerically) zero on all axes.
   function Zero_Table return Oe_State_Ephem_Parameter_Table.T is
      Arcs_U : constant Oe_Arc_Records.U := [others => Zero_Arc];
   begin
      return Oe_State_Ephem_Parameter_Table.Pack ((
         Ephemeris_Time => 0.0,
         Vehicle_Clock_Time => 0.0,
         Central_Body_Mu => 0.0,
         Number_Of_Arcs => (Value => 1),
         Arcs => Arcs_U));
   end Zero_Table;

   --  Aliased packed instance of the zero table so test fixtures can pass
   --  its 'Access to Component.Init (which takes T_Access). Initialized
   --  from a U aggregate via Pack -- one-time elaboration cost on the
   --  host test stack, which is generous. Semantically a constant --
   --  tests do not mutate it.
   Zero_Table_T_Aliased : aliased Oe_State_Ephem_Parameter_Table.T :=
      Oe_State_Ephem_Parameter_Table.Pack ((
         Ephemeris_Time => 0.0,
         Vehicle_Clock_Time => 0.0,
         Central_Body_Mu => 0.0,
         Number_Of_Arcs => (Value => 1),
         Arcs => [others => Zero_Arc]
      ));

   -- Send a parameter table to the component via Parameters_Memory_Region (Set).
   -- The service handler processes synchronously and returns the release status.
   function Send_Set_Table (
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access;
      Table : in Oe_State_Ephem_Parameter_Table.T
   ) return Parameter_Enums.Parameter_Table_Update_Status.E is
      use Parameter_Enums.Parameter_Table_Operation_Type;
      Bytes : aliased constant Basic_Types.Byte_Array :=
         Oe_State_Ephem_Parameter_Table.Serialization.To_Byte_Array (Table);
      Region : constant Memory_Region.T :=
         (Address => Bytes'Address, Length => Bytes'Length);
   begin
      return T.Parameters_Memory_Region_T_Request ((Region => Region, Operation => Set)).Status;
   end Send_Set_Table;

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Init with the zero default table. This applies all-zero parameters
      -- to the C++ algorithm so the first tick produces deterministic output
      -- (zero, given zero coefficients and zero Mu).
      Self.Tester.Component_Instance.Init (Default_Table => Zero_Table_T_Aliased'Access);

      Self.Tester.Component_Instance.Set_Up;
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   overriding procedure Test_Zero_Inputs (Self : in out Instance) is
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Init applied the zero default (Ephemeris_Time = 0, Vehicle_Clock_Time = 0,
      -- Mu = 0, one zero-coefficient arc). Output must be zero r/v.
      Expected_Zero : constant Packed_F64x3.T := [0.0, 0.0, 0.0];
      Epsilon : constant Long_Float := 1.0E-7;
   begin
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      Natural_Assert.Eq (T.Data_Product_T_Recv_Sync_History.Get_Count, 1);
      Natural_Assert.Eq (T.Ephemeris_State_History.Get_Count, 1);

      declare
         Output : constant Cartesian_State.T := T.Ephemeris_State_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, Expected_Zero, Epsilon => Epsilon);
         Packed_F64x3_Assert.Eq (Output.Velocity, Expected_Zero, Epsilon => Epsilon);
      end;
   end Test_Zero_Inputs;

   overriding procedure Test_Cheby_Fit_Via_Set (Self : in out Instance) is
      use Oe_State_Ephem_Enums;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Closed-form circular equatorial orbit at the arc midpoint. At t = 0
      -- in normalized Chebyshev coordinates only the constant coefficient
      -- contributes, so each orbital element collapses to its first
      -- coefficient and the resulting state has an analytic form.
      Radius_M : constant Long_Float := 7.0E6;
      Mu : constant Long_Float := 3.986004418E14;
      Middle_Time_S : constant Long_Float := 1000.0;
      Radius_Time_S : constant Long_Float := 500.0;
      Circular_Speed : constant Long_Float :=
         Ada.Numerics.Long_Elementary_Functions.Sqrt (Mu / Radius_M);

      function Constant_Coeff (Value : in Long_Float) return Oe_Coefficients.U is
         Data : Packed_F64x20.U := [others => 0.0];
      begin
         Data (0) := Value;
         return (Data => Data);
      end Constant_Coeff;

      Zero_Coeff_U : constant Oe_Coefficients.U := (Data => [others => 0.0]);

      Arc_0 : constant Oe_Arc.U := (
         Number_Of_Coefficients => (Value => 1),
         Middle_Time => Middle_Time_S,
         Radius_Time => Radius_Time_S,
         Anomaly_Flag => Anomaly_Type.True_Anomaly,
         Radius_Periapsis => Constant_Coeff (Radius_M),
         Eccentricity => Zero_Coeff_U,
         Inclination => Zero_Coeff_U,
         Arg_Periapsis => Zero_Coeff_U,
         Raan => Zero_Coeff_U,
         True_Anomaly => Zero_Coeff_U
      );

      Arcs : constant Oe_Arc_Records.U := [0 => Arc_0, others => Zero_Arc];
      Table : constant Oe_State_Ephem_Parameter_Table.T :=
         Oe_State_Ephem_Parameter_Table.Pack ((
            -- Vehicle epoch maps to the arc midpoint, so Chebyshev t = 0.
            Ephemeris_Time => Middle_Time_S,
            Vehicle_Clock_Time => 0.0,
            Central_Body_Mu => Mu,
            Number_Of_Arcs => (Value => 1),
            Arcs => Arcs));

      Tolerance_Rel : constant Long_Float := 1.0E-3;
      Position_Tol : constant Long_Float := Radius_M * Tolerance_Rel;
      Velocity_Tol : constant Long_Float := Circular_Speed * Tolerance_Rel;

      Expected_Position : constant Packed_F64x3.T := [Radius_M, 0.0, 0.0];
      Expected_Velocity : constant Packed_F64x3.T := [0.0, Circular_Speed, 0.0];

      Set_Status : constant Parameter_Enums.Parameter_Table_Update_Status.E :=
         Send_Set_Table (T, Table);
   begin
      -- Set succeeded; table is staged. The next tick applies and runs.
      pragma Assert (Set_Status = Success);

      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Parameter_Table_Applied event must fire on the applying tick.
      Natural_Assert.Eq (T.Parameter_Table_Applied_History.Get_Count, 1);

      -- Algorithm output matches the analytic circular orbit.
      Natural_Assert.Eq (T.Ephemeris_State_History.Get_Count, 1);
      declare
         Output : constant Cartesian_State.T := T.Ephemeris_State_History.Get (1);
      begin
         Packed_F64x3_Assert.Eq (Output.Position, Expected_Position, Epsilon => Position_Tol);
         Packed_F64x3_Assert.Eq (Output.Velocity, Expected_Velocity, Epsilon => Velocity_Tol);
      end;
   end Test_Cheby_Fit_Via_Set;

   overriding procedure Test_Set_Invalid_Format (Self : in out Instance) is
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Start from a valid zero table, then corrupt the Anomaly_Flag of arc 0
      -- to a value outside the Anomaly_Type enum range. Validation.Valid
      -- should reject this before deserialization.
      Bytes : aliased Basic_Types.Byte_Array :=
         Oe_State_Ephem_Parameter_Table.Serialization.To_Byte_Array (Zero_Table);

      -- Anomaly_Flag is an E8 inside arc 0. Find its offset and corrupt it.
      -- Layout of the payload:
      --   [Ephemeris_Time(8)][Vehicle_Clock_Time(8)][Central_Body_Mu(8)]
      --   [Number_Of_Arcs(4)][arc_0.Number_Of_Coefficients(4)]
      --   [arc_0.Middle_Time(8)][arc_0.Radius_Time(8)][arc_0.Anomaly_Flag(1)]...
      Anomaly_Offset : constant Natural := 8 + 8 + 8 + 4 + 4 + 8 + 8;
      Region : constant Memory_Region.T :=
         (Address => Bytes'Address, Length => Bytes'Length);
   begin
      Bytes (Bytes'First + Anomaly_Offset) := 16#FF#;   -- out of range for Anomaly_Type

      -- Service returns Parameter_Error; event fired:
      Parameters_Memory_Region_Release_Assert.Eq (
         T.Parameters_Memory_Region_T_Request ((Region => Region, Operation => Set)),
         (Region => Region, Status => Parameter_Error)
      );
      Natural_Assert.Eq (T.Invalid_Parameter_Table_Format_History.Get_Count, 1);

      -- No staged application: the next tick should NOT fire Parameter_Table_Applied.
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Parameter_Table_Applied_History.Get_Count, 0);
   end Test_Set_Invalid_Format;

   overriding procedure Test_Validate_Returns_Parameter_Error (Self : in out Instance) is
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;
      Bytes : aliased constant Basic_Types.Byte_Array :=
         Oe_State_Ephem_Parameter_Table.Serialization.To_Byte_Array (Zero_Table);
      Region : constant Memory_Region.T :=
         (Address => Bytes'Address, Length => Bytes'Length);
   begin
      Parameters_Memory_Region_Release_Assert.Eq (
         T.Parameters_Memory_Region_T_Request ((Region => Region, Operation => Validate)),
         (Region => Region, Status => Parameter_Error)
      );

      -- Validate emits Validate_Not_Supported (same loud-rejection
      -- contract as Get_Copy). No other event fires, no table is staged
      -- or applied. Catches a future change that misroutes the rejection
      -- through a different event family.
      Natural_Assert.Eq (T.Validate_Not_Supported_History.Get_Count, 1);
      Natural_Assert.Eq (T.Invalid_Parameter_Table_Format_History.Get_Count, 0);
      Natural_Assert.Eq (T.Get_Copy_Not_Supported_History.Get_Count, 0);
      Natural_Assert.Eq (T.Parameter_Table_Applied_History.Get_Count, 0);
   end Test_Validate_Returns_Parameter_Error;

   overriding procedure Test_Get_Pointer_Returns_Current_Table (Self : in out Instance) is
      use Oe_State_Ephem_Enums;
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      use type System.Address;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      -- Build a table with non-trivial scalars so Get_Pointer can show round-trip.
      Mu : constant Long_Float := 3.986004418E14;
      Middle_Time_S : constant Long_Float := 1000.0;
      Radius_Time_S : constant Long_Float := 500.0;

      Zero_Coeff_U : constant Oe_Coefficients.U := (Data => [others => 0.0]);
      Arc_0 : constant Oe_Arc.U := (
         Number_Of_Coefficients => (Value => 5),
         Middle_Time => Middle_Time_S,
         Radius_Time => Radius_Time_S,
         Anomaly_Flag => Anomaly_Type.True_Anomaly,
         Radius_Periapsis => Zero_Coeff_U,
         Eccentricity => Zero_Coeff_U,
         Inclination => Zero_Coeff_U,
         Arg_Periapsis => Zero_Coeff_U,
         Raan => Zero_Coeff_U,
         True_Anomaly => Zero_Coeff_U
      );
      Arcs : constant Oe_Arc_Records.U := [0 => Arc_0, others => Zero_Arc];
      Set_Table : constant Oe_State_Ephem_Parameter_Table.T :=
         Oe_State_Ephem_Parameter_Table.Pack ((
            Ephemeris_Time => Middle_Time_S,
            Vehicle_Clock_Time => 0.0,
            Central_Body_Mu => Mu,
            Number_Of_Arcs => (Value => 1),
            Arcs => Arcs));

      Set_Status : constant Parameter_Enums.Parameter_Table_Update_Status.E :=
         Send_Set_Table (T, Set_Table);

      -- Get_Pointer ignores the caller-provided region. Pass an empty
      -- region; OE returns a region pointing at its own staged buffer.
      Empty_Region : constant Memory_Region.T :=
         (Address => System.Null_Address, Length => 0);
   begin
      pragma Assert (Set_Status = Success);

      -- Drive an applying tick so the staged value drains and the algorithm
      -- holds the uploaded state. Is_Staged is False again afterward.
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));

      -- Request Get_Pointer; OE serializes current algorithm state into
      -- its staged buffer and returns a non-null region of the expected
      -- length with Success.
      declare
         Release : constant Parameters_Memory_Region_Release.T :=
            T.Parameters_Memory_Region_T_Request ((Region => Empty_Region, Operation => Get_Pointer));
      begin
         pragma Assert (Release.Status = Success);
         pragma Assert (Release.Region.Length = Oe_State_Ephem_Parameter_Table.Size_In_Bytes);
         pragma Assert (Release.Region.Address /= System.Null_Address);

         -- Read the returned region's bytes and round-trip into a packed
         -- table whose scalars match what we uploaded. The Import aspect
         -- on the overlay is critical: Initialize_Scalars (enabled on
         -- Linux_Test) would otherwise scribble sentinel bytes into the
         -- underlying buffer at declaration time, clobbering OE's
         -- snapshot before we read it.
         declare
            Returned_Bytes : constant Basic_Types.Byte_Array (0 .. Release.Region.Length - 1)
               with Import, Convention => Ada, Address => Release.Region.Address;

            Returned_T : constant Oe_State_Ephem_Parameter_Table.T :=
               Oe_State_Ephem_Parameter_Table.Serialization.From_Byte_Array (Returned_Bytes);
            Returned_U : constant Oe_State_Ephem_Parameter_Table.U :=
               Oe_State_Ephem_Parameter_Table.Unpack (Returned_T);
            Returned_Arc : constant Oe_Arc.U := Returned_U.Arcs (0);
            use type Anomaly_Type.E;
         begin
            pragma Assert (Returned_U.Ephemeris_Time = Middle_Time_S);
            pragma Assert (Returned_U.Vehicle_Clock_Time = 0.0);
            pragma Assert (Returned_U.Central_Body_Mu = Mu);
            pragma Assert (Returned_U.Number_Of_Arcs.Value = 1);
            pragma Assert (Returned_Arc.Number_Of_Coefficients.Value = 5);
            pragma Assert (Returned_Arc.Middle_Time = Middle_Time_S);
            pragma Assert (Returned_Arc.Radius_Time = Radius_Time_S);
            pragma Assert (Returned_Arc.Anomaly_Flag = Anomaly_Type.True_Anomaly);
         end;
      end;
   end Test_Get_Pointer_Returns_Current_Table;

   -- OE rejects Get_Copy with Parameter_Error and emits
   -- Get_Copy_Not_Supported so the misuse is visible in telemetry rather
   -- than only as a silent Parameter_Error status. Callers should use
   -- Get_Pointer for dump access.
   overriding procedure Test_Get_Copy_Returns_Parameter_Error (Self : in out Instance) is
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;
      Buf : aliased Basic_Types.Byte_Array (0 .. Oe_State_Ephem_Parameter_Table.Size_In_Bytes - 1) :=
         [others => 0];
      Region : constant Memory_Region.T :=
         (Address => Buf'Address, Length => Buf'Length);
   begin
      Parameters_Memory_Region_Release_Assert.Eq (
         T.Parameters_Memory_Region_T_Request ((Region => Region, Operation => Get_Copy)),
         (Region => Region, Status => Parameter_Error)
      );
      Natural_Assert.Eq (T.Get_Copy_Not_Supported_History.Get_Count, 1);
   end Test_Get_Copy_Returns_Parameter_Error;

   -- Get_Pointer always succeeds, even while a Set is staged. The dump
   -- buffer reflects the algorithm's *current* state (what's running),
   -- not the pending upload; the staged Set is preserved and applies on
   -- the next tick. This isolates the dump path from the stage-then-
   -- apply pipeline so an auto-dump-after-Set in an upstream forwarder
   -- can't deadlock or fail on a still-pending stage.
   overriding procedure Test_Get_Pointer_Succeeds_While_Staged (Self : in out Instance) is
      use Oe_State_Ephem_Enums;
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      Mu : constant Long_Float := 3.986004418E14;
      Zero_Coeff_U : constant Oe_Coefficients.U := (Data => [others => 0.0]);
      Arc_0 : constant Oe_Arc.U := (
         Number_Of_Coefficients => (Value => 1),
         Middle_Time => 1.0,
         Radius_Time => 0.5,
         Anomaly_Flag => Anomaly_Type.True_Anomaly,
         Radius_Periapsis => Zero_Coeff_U,
         Eccentricity => Zero_Coeff_U,
         Inclination => Zero_Coeff_U,
         Arg_Periapsis => Zero_Coeff_U,
         Raan => Zero_Coeff_U,
         True_Anomaly => Zero_Coeff_U
      );
      Arcs : constant Oe_Arc_Records.U := [0 => Arc_0, others => Zero_Arc];
      Set_Table : constant Oe_State_Ephem_Parameter_Table.T :=
         Oe_State_Ephem_Parameter_Table.Pack ((
            Ephemeris_Time => 0.0,
            Vehicle_Clock_Time => 0.0,
            Central_Body_Mu => Mu,
            Number_Of_Arcs => (Value => 1),
            Arcs => Arcs));

      Set_Status : constant Parameter_Enums.Parameter_Table_Update_Status.E :=
         Send_Set_Table (T, Set_Table);

      Empty_Region : constant Memory_Region.T :=
         (Address => System.Null_Address, Length => 0);
   begin
      -- After Set, the staged buffer holds the pending upload. Do NOT
      -- drive a tick yet -- Is_Staged is still True.
      pragma Assert (Set_Status = Success);
      pragma Assert (T.Parameter_Table_Applied_History.Get_Count = 0);

      -- Get_Pointer must succeed: the new dump path reads the algorithm's
      -- current state into a dedicated Dump_Buffer, independent of the
      -- staged upload. The returned region reflects the pre-stage state
      -- (still the default-initialized algorithm; Mu = 0.0 from Init).
      declare
         Release_While_Staged : constant Parameters_Memory_Region_Release.T :=
            T.Parameters_Memory_Region_T_Request ((Region => Empty_Region, Operation => Get_Pointer));
         use type System.Address;
      begin
         pragma Assert (Release_While_Staged.Status = Success);
         pragma Assert (Release_While_Staged.Region.Length = Oe_State_Ephem_Parameter_Table.Size_In_Bytes);
         pragma Assert (Release_While_Staged.Region.Address /= System.Null_Address);

         declare
            Bytes : constant Basic_Types.Byte_Array (0 .. Release_While_Staged.Region.Length - 1)
               with Import, Convention => Ada, Address => Release_While_Staged.Region.Address;
            Snapshot_T : constant Oe_State_Ephem_Parameter_Table.T :=
               Oe_State_Ephem_Parameter_Table.Serialization.From_Byte_Array (Bytes);
            Snapshot_U : constant Oe_State_Ephem_Parameter_Table.U :=
               Oe_State_Ephem_Parameter_Table.Unpack (Snapshot_T);
         begin
            -- Pre-stage state: the algorithm still holds the Init default
            -- (Zero_Table_T_Aliased), not the values we just staged. The
            -- pending Set is sitting in Staged_Parameters waiting for the
            -- next tick.
            pragma Assert (Snapshot_U.Central_Body_Mu = 0.0);
            pragma Assert (Snapshot_U.Number_Of_Arcs.Value = 1);
         end;
      end;

      -- The staged Set was NOT clobbered by the Get_Pointer. Drive a
      -- tick; the staged buffer drains and the algorithm now holds the
      -- uploaded Mu.
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      pragma Assert (T.Parameter_Table_Applied_History.Get_Count = 1);

      -- A second Get_Pointer now returns the freshly-applied state.
      declare
         Release_After_Tick : constant Parameters_Memory_Region_Release.T :=
            T.Parameters_Memory_Region_T_Request ((Region => Empty_Region, Operation => Get_Pointer));
      begin
         pragma Assert (Release_After_Tick.Status = Success);
         declare
            Bytes : constant Basic_Types.Byte_Array (0 .. Release_After_Tick.Region.Length - 1)
               with Import, Convention => Ada, Address => Release_After_Tick.Region.Address;
            Applied_T : constant Oe_State_Ephem_Parameter_Table.T :=
               Oe_State_Ephem_Parameter_Table.Serialization.From_Byte_Array (Bytes);
            Applied_U : constant Oe_State_Ephem_Parameter_Table.U :=
               Oe_State_Ephem_Parameter_Table.Unpack (Applied_T);
         begin
            pragma Assert (Applied_U.Central_Body_Mu = Mu);
            pragma Assert (Applied_U.Number_Of_Arcs.Value = 1);
         end;
      end;
   end Test_Get_Pointer_Succeeds_While_Staged;

   -- Dump_Buffer is overwritten on every Get_Pointer call, so back-to-back
   -- Get_Pointers must each reflect the algorithm's current state at the
   -- time of the call. The new dump-buffer design (separate from staging)
   -- relies on this for correctness; a regression to a write-once /
   -- cached-dump strategy would slip past Test_Get_Pointer_*_Current /
   -- _Succeeds_While_Staged because those only inspect one snapshot.
   overriding procedure Test_Get_Pointer_Reflects_Current_State (Self : in out Instance) is
      use Oe_State_Ephem_Enums;
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      First_Mu : constant Long_Float := 1.0E14;
      Second_Mu : constant Long_Float := 4.0E14;

      function Table_With_Mu (Mu : in Long_Float) return Oe_State_Ephem_Parameter_Table.T is
         Zero_Coeff_U : constant Oe_Coefficients.U := (Data => [others => 0.0]);
         Arc_0 : constant Oe_Arc.U := (
            Number_Of_Coefficients => (Value => 1),
            Middle_Time => 1.0,
            Radius_Time => 0.5,
            Anomaly_Flag => Anomaly_Type.True_Anomaly,
            Radius_Periapsis => Zero_Coeff_U,
            Eccentricity => Zero_Coeff_U,
            Inclination => Zero_Coeff_U,
            Arg_Periapsis => Zero_Coeff_U,
            Raan => Zero_Coeff_U,
            True_Anomaly => Zero_Coeff_U);
         Arcs : constant Oe_Arc_Records.U := [0 => Arc_0, others => Zero_Arc];
      begin
         return Oe_State_Ephem_Parameter_Table.Pack ((
            Ephemeris_Time => 0.0,
            Vehicle_Clock_Time => 0.0,
            Central_Body_Mu => Mu,
            Number_Of_Arcs => (Value => 1),
            Arcs => Arcs));
      end Table_With_Mu;

      Empty_Region : constant Memory_Region.T :=
         (Address => System.Null_Address, Length => 0);

      function Get_Pointer_Mu return Long_Float is
         Release : constant Parameters_Memory_Region_Release.T :=
            T.Parameters_Memory_Region_T_Request ((Region => Empty_Region, Operation => Get_Pointer));
      begin
         pragma Assert (Release.Status = Success);
         declare
            Bytes : constant Basic_Types.Byte_Array (0 .. Release.Region.Length - 1)
               with Import, Convention => Ada, Address => Release.Region.Address;
            Snapshot : constant Oe_State_Ephem_Parameter_Table.T :=
               Oe_State_Ephem_Parameter_Table.Serialization.From_Byte_Array (Bytes);
         begin
            return Oe_State_Ephem_Parameter_Table.Unpack (Snapshot).Central_Body_Mu;
         end;
      end Get_Pointer_Mu;
   begin
      -- Upload Table_With_Mu(First_Mu); tick to apply it.
      pragma Assert (Send_Set_Table (T, Table_With_Mu (First_Mu)) = Success);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      pragma Assert (T.Parameter_Table_Applied_History.Get_Count = 1);

      -- First Get_Pointer reflects the first upload.
      pragma Assert (Get_Pointer_Mu = First_Mu);

      -- Upload Table_With_Mu(Second_Mu); tick to apply it.
      pragma Assert (Send_Set_Table (T, Table_With_Mu (Second_Mu)) = Success);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      pragma Assert (T.Parameter_Table_Applied_History.Get_Count = 2);

      -- Second Get_Pointer reflects the second upload, NOT the cached
      -- first one. Proves Dump_Buffer is overwritten on each call.
      pragma Assert (Get_Pointer_Mu = Second_Mu);
   end Test_Get_Pointer_Reflects_Current_State;

   -- Generic_Staged_Variable documents "only the latest persists" -- prove
   -- OE relies on that semantic correctly. Two Set calls without a tick
   -- between them must result in only the latest being applied on the
   -- next tick (one Parameter_Table_Applied event, algorithm holds the
   -- second upload's values).
   overriding procedure Test_Repeated_Set_Without_Tick (Self : in out Instance) is
      use Oe_State_Ephem_Enums;
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      T : Component.Oe_State_Ephem.Implementation.Tester.Instance_Access renames Self.Tester;

      First_Mu : constant Long_Float := 1.0E14;
      Second_Mu : constant Long_Float := 4.0E14;

      function Table_With_Mu (Mu : in Long_Float) return Oe_State_Ephem_Parameter_Table.T is
         Zero_Coeff_U : constant Oe_Coefficients.U := (Data => [others => 0.0]);
         Arc_0 : constant Oe_Arc.U := (
            Number_Of_Coefficients => (Value => 1),
            Middle_Time => 1.0,
            Radius_Time => 0.5,
            Anomaly_Flag => Anomaly_Type.True_Anomaly,
            Radius_Periapsis => Zero_Coeff_U,
            Eccentricity => Zero_Coeff_U,
            Inclination => Zero_Coeff_U,
            Arg_Periapsis => Zero_Coeff_U,
            Raan => Zero_Coeff_U,
            True_Anomaly => Zero_Coeff_U);
         Arcs : constant Oe_Arc_Records.U := [0 => Arc_0, others => Zero_Arc];
      begin
         return Oe_State_Ephem_Parameter_Table.Pack ((
            Ephemeris_Time => 0.0,
            Vehicle_Clock_Time => 0.0,
            Central_Body_Mu => Mu,
            Number_Of_Arcs => (Value => 1),
            Arcs => Arcs));
      end Table_With_Mu;
   begin
      -- Stage two distinct tables without an intervening tick.
      pragma Assert (Send_Set_Table (T, Table_With_Mu (First_Mu)) = Success);
      pragma Assert (Send_Set_Table (T, Table_With_Mu (Second_Mu)) = Success);

      -- No tick yet, so no Apply event fired.
      Natural_Assert.Eq (T.Parameter_Table_Applied_History.Get_Count, 0);

      -- Single tick: only the most-recent Set is applied. Generic_
      -- Staged_Variable.Stage discards the first table.
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Parameter_Table_Applied_History.Get_Count, 1);

      -- Dump confirms the algorithm holds Second_Mu, not First_Mu.
      declare
         Empty_Region : constant Memory_Region.T :=
            (Address => System.Null_Address, Length => 0);
         Release : constant Parameters_Memory_Region_Release.T :=
            T.Parameters_Memory_Region_T_Request ((Region => Empty_Region, Operation => Get_Pointer));
         Bytes : constant Basic_Types.Byte_Array (0 .. Release.Region.Length - 1)
            with Import, Convention => Ada, Address => Release.Region.Address;
         Snapshot : constant Oe_State_Ephem_Parameter_Table.T :=
            Oe_State_Ephem_Parameter_Table.Serialization.From_Byte_Array (Bytes);
      begin
         pragma Assert (Oe_State_Ephem_Parameter_Table.Unpack (Snapshot).Central_Body_Mu = Second_Mu);
      end;
   end Test_Repeated_Set_Without_Tick;

end Oe_State_Ephem_Tests.Implementation;
