--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Implementation Body
--------------------------------------------------------------------------------

with Basic_Types;
with Cartesian_State;
with Cartesian_State.C;
with Interfaces;
with Oe_Arc;
with Oe_Coefficients;
with Oe_Coefficients.C;
with Oe_State_Ephem_Enums;
with Oe_State_Ephem_Parameter_Table.Validation;
with Parameter_Enums;

use Interfaces;

package body Component.Oe_State_Ephem.Implementation is

   ------------------------------------------------------------------------
   -- Local Helpers
   ------------------------------------------------------------------------

   -- Push one packed Oe_Arc.T to the C++ algorithm.
   procedure Apply_Arc_To_Algorithm (
      Alg : in Oe_State_Ephem_Algorithm_Access;
      Arc_Number : in Unsigned_32;
      Arc : in Oe_Arc.T
   ) is
      use Oe_State_Ephem_Enums;
      Rp_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.Unpack (Arc.Radius_Periapsis);
      Ec_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.Unpack (Arc.Eccentricity);
      Inc_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.Unpack (Arc.Inclination);
      Ap_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.Unpack (Arc.Arg_Periapsis);
      Ra_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.Unpack (Arc.Raan);
      Ta_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.Unpack (Arc.True_Anomaly);
   begin
      Set_Arc_Number_Of_Coefficients (Alg, Arc_Number, Arc.Number_Of_Coefficients.Value);
      Set_Arc_Middle_Time (Alg, Arc_Number, Arc.Middle_Time);
      Set_Arc_Radius_Time (Alg, Arc_Number, Arc.Radius_Time);
      Set_Arc_Anomaly_Flag (Alg, Arc_Number, Unsigned_32 (Anomaly_Type.E'Pos (Arc.Anomaly_Flag)));
      Set_Arc_Radius_Periapsis_Coefficients (Alg, Arc_Number, Rp_C'Access);
      Set_Arc_Eccentricity_Coefficients (Alg, Arc_Number, Ec_C'Access);
      Set_Arc_Inclination_Coefficients (Alg, Arc_Number, Inc_C'Access);
      Set_Arc_Arg_Periapsis_Coefficients (Alg, Arc_Number, Ap_C'Access);
      Set_Arc_Raan_Coefficients (Alg, Arc_Number, Ra_C'Access);
      Set_Arc_True_Anomaly_Coefficients (Alg, Arc_Number, Ta_C'Access);
   end Apply_Arc_To_Algorithm;

   -- Push a packed Oe_State_Ephem_Parameter_Table.T to the C++ algorithm.
   procedure Apply_Table_To_Algorithm (
      Alg : in Oe_State_Ephem_Algorithm_Access;
      Table : in Oe_State_Ephem_Parameter_Table.T
   ) is
   begin
      Set_Ephemeris_Time_J2000 (Alg, Table.Ephemeris_Time);
      Set_Vehicle_Time_Offset (Alg, Table.Vehicle_Clock_Time);
      Set_Central_Body_Gravitational_Parameter (Alg, Table.Central_Body_Mu);
      Set_Number_Of_Arcs (Alg, Table.Number_Of_Arcs.Value);
      -- Push only the active arcs (the C++ algorithm asserts every per-arc
      -- Number_Of_Coefficients is positive, so we cannot push trailing
      -- zero-coefficient slots even though Update() would ignore them).
      -- Trailing slots retain whatever the algorithm had previously.
      for I in 0 .. Natural (Table.Number_Of_Arcs.Value) - 1 loop
         Apply_Arc_To_Algorithm (Alg, Unsigned_32 (I), Table.Arcs (I));
      end loop;
   end Apply_Table_To_Algorithm;

   -- Copy the staged parameter table into the C++ algorithm. Isolated
   -- into a separate procedure so the ~10 KB Oe_State_Ephem_Parameter_
   -- Table.T lives only on this helper's stack frame which is not
   -- frequently called.
   procedure Drain_Staged_To_Algorithm (
      Staged : in out Staged_Table_Pkg.Staged_Variable;
      Alg : in Oe_State_Ephem_Algorithm_Access
   ) is
      New_Table_T : Oe_State_Ephem_Parameter_Table.T;
   begin
      Staged.Copy_From_Staged (New_Table_T);
      Apply_Table_To_Algorithm (Alg, New_Table_T);
   end Drain_Staged_To_Algorithm;

   -- Read one arc from the C++ algorithm directly into the caller's
   -- packed Oe_Arc.T slot. Written as a single aggregate so the compiler
   -- enforces that every field is filled; 'out' parameter keeps the
   -- aggregate write in-place on the caller's slot (no temporary).
   procedure Read_Arc_From_Algorithm (
      Alg : in Oe_State_Ephem_Algorithm_Access;
      Arc_Number : in Unsigned_32;
      Out_Arc : out Oe_Arc.T
   ) is
      use Oe_State_Ephem_Enums;
   begin
      Out_Arc := (
         Number_Of_Coefficients => (Value => Get_Arc_Number_Of_Coefficients (Alg, Arc_Number)),
         Middle_Time => Get_Arc_Middle_Time (Alg, Arc_Number),
         Radius_Time => Get_Arc_Radius_Time (Alg, Arc_Number),
         Anomaly_Flag => Anomaly_Type.E'Val (Natural (Get_Arc_Anomaly_Flag (Alg, Arc_Number))),
         Radius_Periapsis => Oe_Coefficients.C.Pack (Get_Arc_Radius_Periapsis_Coefficients (Alg, Arc_Number)),
         Eccentricity => Oe_Coefficients.C.Pack (Get_Arc_Eccentricity_Coefficients (Alg, Arc_Number)),
         Inclination => Oe_Coefficients.C.Pack (Get_Arc_Inclination_Coefficients (Alg, Arc_Number)),
         Arg_Periapsis => Oe_Coefficients.C.Pack (Get_Arc_Arg_Periapsis_Coefficients (Alg, Arc_Number)),
         Raan => Oe_Coefficients.C.Pack (Get_Arc_Raan_Coefficients (Alg, Arc_Number)),
         True_Anomaly => Oe_Coefficients.C.Pack (Get_Arc_True_Anomaly_Coefficients (Alg, Arc_Number))
      );
   end Read_Arc_From_Algorithm;

   -- Read the full algorithm state directly into the caller's table.
   -- The scalar fields are written individually rather than as a single
   -- full-record aggregate: an aggregate covering the 10-element Arcs
   -- field would require building a ~10 KB Oe_Arc_Records.T value on the
   -- stack and then copying it into Out_T, which is exactly what the
   -- 'out' parameter form is meant to avoid here.
   procedure Read_Table_From_Algorithm (
      Alg : in Oe_State_Ephem_Algorithm_Access;
      Out_T : out Oe_State_Ephem_Parameter_Table.T
   ) is
   begin
      Out_T.Ephemeris_Time := Get_Ephemeris_Time_J2000 (Alg);
      Out_T.Vehicle_Clock_Time := Get_Vehicle_Time_Offset (Alg);
      Out_T.Central_Body_Mu := Get_Central_Body_Gravitational_Parameter (Alg);
      Out_T.Number_Of_Arcs := (Value => Get_Number_Of_Arcs (Alg));
      for I in Out_T.Arcs'Range loop
         Read_Arc_From_Algorithm (Alg, Unsigned_32 (I), Out_T.Arcs (I));
      end loop;
   end Read_Table_From_Algorithm;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   overriding procedure Init (Self : in out Instance; Default_Table : not null Oe_State_Ephem_Parameter_Table.T_Access) is
   begin
      -- Allocate the C++ algorithm on the heap.
      Self.Alg := Create;
      -- Apply the default table immediately so any tick arriving before
      -- an uploaded table is received still produces deterministic
      -- output. Default_Table is a pointer to an aliased packed-T value
      -- declared in the assembly's defaults file. We pass by access to
      -- avoid large stack usage by the environment task.
      Apply_Table_To_Algorithm (Self.Alg, Default_Table.all);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
   begin
      -- Apply staged parameter table BEFORE running the algorithm so the
      -- algorithm operates on the freshest values starting this tick. But
      -- only do this is a new table is staged.
      if Self.Staged_Parameters.Is_Staged then
         Drain_Staged_To_Algorithm (Self.Staged_Parameters, Self.Alg);
         Self.Event_T_Send_If_Connected (Self.Events.Parameter_Table_Applied (Self.Sys_Time_T_Get));
      end if;

      declare
         Call_Time_Ns : constant Interfaces.Unsigned_64 :=
            Interfaces.Unsigned_64 (Arg.Time.Seconds) * 1_000_000_000 +
            (Interfaces.Unsigned_64 (Arg.Time.Subseconds) * 1_000_000_000) / 65_536;
         Result : constant Cartesian_State.C.U_C := Update (Self.Alg, Call_Time_Ns);
      begin
         Self.Data_Product_T_Send (Self.Data_Products.Ephemeris_State (
            Arg.Time,
            Cartesian_State.Pack (Cartesian_State.C.To_Ada (Result))
         ));
      end;
   end Tick_T_Recv_Sync;

   overriding function Parameters_Memory_Region_T_Service (Self : in out Instance; Arg : in Parameters_Memory_Region.T) return Parameters_Memory_Region_Release.T is
      use Parameter_Enums.Parameter_Table_Operation_Type;
      use Parameter_Enums.Parameter_Table_Update_Status;
      Status : Parameter_Enums.Parameter_Table_Update_Status.E := Success;
   begin
      case Arg.Operation is
         when Set =>
            -- Forwarder hands us a payload-only region. Let's overlay and
            -- validate before using.
            declare
               Bytes : constant Basic_Types.Byte_Array (0 .. Arg.Region.Length - 1)
                  with Import, Convention => Ada, Address => Arg.Region.Address;
               Errant_Field : Interfaces.Unsigned_32 := 0;
            begin
               if not Oe_State_Ephem_Parameter_Table.Validation.Valid (Bytes, Errant_Field) then
                  Self.Event_T_Send_If_Connected (Self.Events.Invalid_Parameter_Table_Format (
                     Self.Sys_Time_T_Get,
                     (Value => Errant_Field)
                  ));
                  Status := Parameter_Error;
               else
                  declare
                     -- Validation succeeded.
                     -- TODO - call C++ side validation checks.
                     --
                     -- Overlay the packed .T directly on the upstream
                     -- buffer, and then stage this parameter set.
                     Table_T : constant Oe_State_Ephem_Parameter_Table.T
                        with Import, Convention => Ada, Address => Arg.Region.Address;
                  begin
                     Self.Staged_Parameters.Stage (Table_T);
                  end;
               end if;
            end;

         when Validate =>
            -- Validate is intentionally unsupported for this component.
            Self.Event_T_Send_If_Connected (Self.Events.Validate_Not_Supported (
               Self.Sys_Time_T_Get
            ));
            Status := Parameter_Error;

         when Get_Copy =>
            -- Get_Copy is intentionally unsupported for this component.
            Self.Event_T_Send_If_Connected (Self.Events.Get_Copy_Not_Supported (
               Self.Sys_Time_T_Get
            ));
            Status := Parameter_Error;

         when Get_Pointer =>
            -- Snapshot the algorithm's current state into the component's
            -- dedicated Dump_Buffer in-place and expose its address. This
            -- works fine as long as the table is not being updated while
            -- this operation is called. We expect operators to what for
            -- table upload success before trying to dump.
            Read_Table_From_Algorithm (Self.Alg, Self.Dump_Buffer);
            return (
               Region => (
                  Address => Self.Dump_Buffer'Address,
                  Length => Oe_State_Ephem_Parameter_Table.Size_In_Bytes
               ),
               Status => Success
            );
      end case;

      return (Region => Arg.Region, Status => Status);
   end Parameters_Memory_Region_T_Service;

end Component.Oe_State_Ephem.Implementation;
