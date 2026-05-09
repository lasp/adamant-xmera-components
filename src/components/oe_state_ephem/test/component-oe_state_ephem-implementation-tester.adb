--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Tester Body
--------------------------------------------------------------------------------

with Oe_State_Ephem_Algorithm_C; use Oe_State_Ephem_Algorithm_C;
with Oe_Coefficients.C;

package body Component.Oe_State_Ephem.Implementation.Tester is

   use type Interfaces.C.unsigned;

   ---------------------------------------
   -- Initialize heap variables:
   ---------------------------------------
   procedure Init_Base (Self : in out Instance) is
   begin
      -- Initialize tester heap:
      -- Connector histories:
      Self.Data_Product_Fetch_T_Service_History.Init (Depth => 100);
      Self.Data_Product_T_Recv_Sync_History.Init (Depth => 100);
      -- Data product histories:
      Self.Ephemeris_State_History.Init (Depth => 100);
   end Init_Base;

   procedure Final_Base (Self : in out Instance) is
   begin
      -- Destroy tester heap:
      -- Connector histories:
      Self.Data_Product_Fetch_T_Service_History.Destroy;
      Self.Data_Product_T_Recv_Sync_History.Destroy;
      -- Data product histories:
      Self.Ephemeris_State_History.Destroy;
   end Final_Base;

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance) is
   begin
      Self.Component_Instance.Attach_Data_Product_Fetch_T_Request (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_Fetch_T_Service_Access);
      Self.Component_Instance.Attach_Data_Product_T_Send (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_T_Recv_Sync_Access);
      Self.Attach_Tick_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Tick_T_Recv_Sync_Access);
   end Connect;

   ---------------------------------------
   -- Algorithm configuration helpers:
   ---------------------------------------
   procedure Set_Central_Body_Mu (Self : in out Instance; Mu : in Interfaces.C.double) is
   begin
      Set_Central_Body_Gravitational_Parameter (Self.Component_Instance.Alg, Mu);
   end Set_Central_Body_Mu;

   procedure Configure_Arc (
      Self : in out Instance;
      Arc_Number : in Interfaces.C.unsigned;
      Number_Of_Coefficients : in Interfaces.C.unsigned;
      Middle_Time : in Interfaces.C.double;
      Radius_Time : in Interfaces.C.double;
      Anomaly_Flag : in Interfaces.C.unsigned;
      Radius_Periapsis : in Oe_Coefficients.T;
      Eccentricity : in Oe_Coefficients.T;
      Inclination : in Oe_Coefficients.T;
      Arg_Periapsis : in Oe_Coefficients.T;
      Raan : in Oe_Coefficients.T;
      True_Anomaly : in Oe_Coefficients.T
   ) is
      Rp_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.To_C (Oe_Coefficients.Unpack (Radius_Periapsis));
      Ec_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.To_C (Oe_Coefficients.Unpack (Eccentricity));
      Inc_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.To_C (Oe_Coefficients.Unpack (Inclination));
      Ap_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.To_C (Oe_Coefficients.Unpack (Arg_Periapsis));
      Ra_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.To_C (Oe_Coefficients.Unpack (Raan));
      Ta_C : aliased constant Oe_Coefficients.C.U_C := Oe_Coefficients.C.To_C (Oe_Coefficients.Unpack (True_Anomaly));
   begin
      Set_Number_Of_Arcs (Self.Component_Instance.Alg, Arc_Number + 1);
      Set_Arc_Number_Of_Coefficients (Self.Component_Instance.Alg, Arc_Number, Number_Of_Coefficients);
      Set_Arc_Middle_Time (Self.Component_Instance.Alg, Arc_Number, Middle_Time);
      Set_Arc_Radius_Time (Self.Component_Instance.Alg, Arc_Number, Radius_Time);
      Set_Arc_Anomaly_Flag (Self.Component_Instance.Alg, Arc_Number, Anomaly_Flag);
      Set_Arc_Radius_Periapsis_Coefficients (Self.Component_Instance.Alg, Arc_Number, Rp_C'Access);
      Set_Arc_Eccentricity_Coefficients (Self.Component_Instance.Alg, Arc_Number, Ec_C'Access);
      Set_Arc_Inclination_Coefficients (Self.Component_Instance.Alg, Arc_Number, Inc_C'Access);
      Set_Arc_Arg_Periapsis_Coefficients (Self.Component_Instance.Alg, Arc_Number, Ap_C'Access);
      Set_Arc_Raan_Coefficients (Self.Component_Instance.Alg, Arc_Number, Ra_C'Access);
      Set_Arc_True_Anomaly_Coefficients (Self.Component_Instance.Alg, Arc_Number, Ta_C'Access);
   end Configure_Arc;

   -- Helper function for returning data dependencies:
   function Return_Data_Dependency (Self : in out Instance; Arg : in Data_Product_Fetch.T) return Data_Product_Return.T is
      use Data_Product_Types;
      use Data_Product_Enums.Fetch_Status;
      use Sys_Time;
      -- Set default return values. These will be overridden below based on test configuration and
      -- the ID requested.
      Id_To_Return : Data_Product_Types.Data_Product_Id := Self.Data_Dependency_Return_Id_Override;
      Length_To_Return : Data_Product_Types.Data_Product_Buffer_Length_Type := Self.Data_Dependency_Return_Length_Override;
      Return_Status : Data_Product_Enums.Fetch_Status.E := Self.Data_Dependency_Return_Status_Override;
      Buffer_To_Return : Data_Product_Types.Data_Product_Buffer_Type;
      Time_To_Return : Sys_Time.T := Self.Data_Dependency_Timestamp_Override;
   begin
      -- Determine return data product ID:
      if Id_To_Return = 0 then
         case Arg.Id is
            -- ID for Clock_Correlation:
            when 0 => Id_To_Return := 0;
            -- If ID can not be found, then return ID out of range error.
            when others =>
               if Return_Status = Data_Product_Enums.Fetch_Status.Success then
                  Return_Status := Data_Product_Enums.Fetch_Status.Id_Out_Of_Range;
               end if;
         end case;
      end if;

      -- Determine return data product length:
      if Length_To_Return = 0 then
         case Arg.Id is
            -- Length for Clock_Correlation:
            when 0 => Length_To_Return := Tdb_Vehicle_Clock_Correlation.Size_In_Bytes;
            -- If ID can not be found, then return ID out of range error.
            when others =>
               if Return_Status = Data_Product_Enums.Fetch_Status.Success then
                  Return_Status := Data_Product_Enums.Fetch_Status.Id_Out_Of_Range;
               end if;
         end case;
      end if;

      -- Determine return timestamp:
      if Time_To_Return = (0, 0) then
         Time_To_Return := Self.System_Time;
      end if;

      -- Fill the data product buffer:
      if Return_Status = Data_Product_Enums.Fetch_Status.Success then
         case Arg.Id is
            -- Length for Clock_Correlation:
            when 0 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Tdb_Vehicle_Clock_Correlation.Size_In_Bytes - 1) :=
                  Tdb_Vehicle_Clock_Correlation.Serialization.To_Byte_Array (Self.Clock_Correlation);
            -- Do not fill. The ID is not recognized.
            when others =>
               Return_Status := Data_Product_Enums.Fetch_Status.Id_Out_Of_Range;
         end case;
      end if;

      -- Return the data product with the status:
      return (
         The_Status => Return_Status,
         The_Data_Product => (
            Header => (
               Time => Time_To_Return,
               Id => Id_To_Return,
               Buffer_Length => Length_To_Return
            ),
            Buffer => Buffer_To_Return
         )
      );
   end Return_Data_Dependency;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Fetch a data product item from the database.
   overriding function Data_Product_Fetch_T_Service (Self : in out Instance; Arg : in Data_Product_Fetch.T) return Data_Product_Return.T is
      To_Return : constant Data_Product_Return.T := Self.Return_Data_Dependency (Arg);
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Data_Product_Fetch_T_Service_History.Push (Arg);
      return To_Return;
   end Data_Product_Fetch_T_Service;

   -- The data product invoker connector
   overriding procedure Data_Product_T_Recv_Sync (Self : in out Instance; Arg : in Data_Product.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Data_Product_T_Recv_Sync_History.Push (Arg);
      -- Dispatch the data product to the correct handler:
      Self.Dispatch_Data_Product (Arg);
   end Data_Product_T_Recv_Sync;

   -----------------------------------------------
   -- Data product handler primitive:
   -----------------------------------------------
   -- Description:
   --    Data products for the OE State Ephem component.
   -- Computed spacecraft Cartesian state (position and velocity) from
   -- Chebyshev orbital element fit.
   overriding procedure Ephemeris_State (Self : in out Instance; Arg : in Cartesian_State.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Ephemeris_State_History.Push (Arg);
   end Ephemeris_State;

end Component.Oe_State_Ephem.Implementation.Tester;
