--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Implementation Body
--------------------------------------------------------------------------------

with Basic_Types;
with Cartesian_State;
with Cartesian_State.C;
with Interfaces;
with Oe_Arc;
with Oe_Coefficients;
with Oe_State_Ephem_Enums;
with Oe_State_Ephem_Parameter_Table.Validation;
with Parameter_Enums;

use Interfaces;

package body Component.Oe_State_Ephem.Implementation is

   ------------------------------------------------------------------------
   -- Local Helpers
   ------------------------------------------------------------------------

   -- Assemble the C++ configuration POD from a packed parameter table. The
   -- whole config is the parameter table, so this is the single place that
   -- maps a table into the algorithm's config. The table is unpacked once
   -- into native values inside this frame (~10 KB) so the large temporary is
   -- confined to this call; Config is written in place on the caller's
   -- aliased local (another ~10 KB) rather than returned by value.
   procedure Make_Config (
      Table : in Oe_State_Ephem_Parameter_Table.T;
      Config : out Oe_State_Ephem_Config_C
   ) is
      use Oe_State_Ephem_Enums;
      Tbl : constant Oe_State_Ephem_Parameter_Table.U :=
         Oe_State_Ephem_Parameter_Table.Unpack (Table);

      -- Copy a 20-element coefficient vector into the C POD array. The source
      -- (Packed_F64x20.U) and destination differ only in aliased-ness of the
      -- component, so copy element-by-element.
      function To_Coeff_Array (Src : in Oe_Coefficients.U) return Oe_Coeff_Array_C is
         Result : Oe_Coeff_Array_C;
      begin
         for I in Result'Range loop
            Result (I) := Src.Data (I);
         end loop;
         return Result;
      end To_Coeff_Array;
   begin
      Config.Central_Body_Gravitational_Parameter := Tbl.Central_Body_Mu;
      Config.Number_Of_Arcs := Tbl.Number_Of_Arcs.Value;
      Config.Ephemeris_Time_J2000 := Tbl.Ephemeris_Time;
      Config.Vehicle_Time_Offset := Tbl.Vehicle_Clock_Time;
      for I in Config.Fit_Coefficients'Range loop
         declare
            Arc : Oe_Arc.U renames Tbl.Arcs (I);
         begin
            Config.Fit_Coefficients (I) := (
               Number_Cheb_Coefficients => Arc.Number_Of_Coefficients.Value,
               Ephemeris_Time_Middle => Arc.Middle_Time,
               Ephemeris_Time_Radius => Arc.Radius_Time,
               Radius_Periapsis_Coefficients => To_Coeff_Array (Arc.Radius_Periapsis),
               Eccentricity_Coefficients => To_Coeff_Array (Arc.Eccentricity),
               Inclination_Coefficients => To_Coeff_Array (Arc.Inclination),
               Arg_Periapsis_Coefficients => To_Coeff_Array (Arc.Arg_Periapsis),
               Raan_Coefficients => To_Coeff_Array (Arc.Raan),
               True_Anomaly_Coefficients => To_Coeff_Array (Arc.True_Anomaly),
               Anomaly_Flag => Anomaly_Type_C'Val (Anomaly_Type.E'Pos (Arc.Anomaly_Flag))
            );
         end;
      end loop;
   end Make_Config;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   overriding procedure Init (Self : in out Instance; Default_Table : not null Oe_State_Ephem_Parameter_Table.T_Access) is
      Config : aliased Oe_State_Ephem_Config_C;
   begin
      -- Store the default table as the current applied table so a Get_Pointer
      -- issued before any tick reports the startup configuration. There are no
      -- C++ getters under the config pattern, so the component is the source of
      -- truth for what the algorithm currently holds.
      Self.Dump_Buffer := Default_Table.all;
      -- Build the initial config and construct the algorithm eagerly. The
      -- default table provided by the assembly must satisfy the algorithm's
      -- config validator (Number_Of_Arcs in [1, Max]; every active arc with
      -- Number_Of_Coefficients >= 1 and positive middle/radius time); an
      -- invalid config would make Create throw across the FFI boundary.
      Make_Config (Self.Dump_Buffer, Config);
      Self.Alg := Create (Config'Unchecked_Access);
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
      -- Apply the staged parameter table BEFORE running the algorithm so the
      -- algorithm operates on the freshest values starting this tick. Only do
      -- this if a new table is staged.
      if Self.Staged_Parameters.Is_Staged then
         declare
            Config : aliased Oe_State_Ephem_Config_C;
         begin
            -- Drain the staged table into the dump buffer (which doubles as the
            -- current-applied-table store), rebuild the config, and push it. The
            -- staged bytes were validated by Make_Config + Validate_Config at Set
            -- time, so Set_Config will not reject them.
            Self.Staged_Parameters.Copy_From_Staged (Self.Dump_Buffer);
            Make_Config (Self.Dump_Buffer, Config);
            Set_Config (Self.Alg, Config'Unchecked_Access);
         end;
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
            -- Forwarder hands us a payload-only region. Overlay, validate the
            -- byte format, then validate the resulting config values before
            -- staging so that only a table the algorithm will accept can reach
            -- the throwing Set_Config on the next tick.
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
                     -- Byte format is valid. Overlay the packed .T directly on
                     -- the upstream buffer and check the config values against
                     -- the algorithm's own validator before staging.
                     Table_T : constant Oe_State_Ephem_Parameter_Table.T
                        with Import, Convention => Ada, Address => Arg.Region.Address;
                     Config : aliased Oe_State_Ephem_Config_C;
                  begin
                     Make_Config (Table_T, Config);
                     if Validate_Config (Config'Unchecked_Access) then
                        Self.Staged_Parameters.Stage (Table_T);
                     else
                        Self.Event_T_Send_If_Connected (Self.Events.Invalid_Parameter_Table_Values (
                           Self.Sys_Time_T_Get
                        ));
                        Status := Parameter_Error;
                     end if;
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
            -- Expose the component's copy of the currently-applied table. The
            -- config pattern removed the C++ getters, so the dump buffer (kept
            -- in sync at Init and on every applying tick) is the source of
            -- truth for the algorithm's current configuration. This works as
            -- long as the table is not being applied while this operation is
            -- called; operators dump only after a table upload succeeds.
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
