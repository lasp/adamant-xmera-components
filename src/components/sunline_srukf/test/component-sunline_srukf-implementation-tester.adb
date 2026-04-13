--------------------------------------------------------------------------------
-- Sunline_Srukf Component Tester Body
--------------------------------------------------------------------------------

package body Component.Sunline_Srukf.Implementation.Tester is

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
      Self.Sunline_Srukf_State_History.Init (Depth => 100);
   end Init_Base;

   procedure Final_Base (Self : in out Instance) is
   begin
      -- Destroy tester heap:
      -- Connector histories:
      Self.Data_Product_Fetch_T_Service_History.Destroy;
      Self.Data_Product_T_Recv_Sync_History.Destroy;
      -- Data product histories:
      Self.Sunline_Srukf_State_History.Destroy;
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
            -- ID for Spacecraft_Attitude:
            when 0 => Id_To_Return := 0;
            -- ID for Css_Cos_Values_A:
            when 1 => Id_To_Return := 1;
            -- ID for Css_Cos_Values_B:
            when 2 => Id_To_Return := 2;
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
            -- Length for Spacecraft_Attitude:
            when 0 => Length_To_Return := Nav_Att.Size_In_Bytes;
            -- Length for Css_Cos_Values_A:
            when 1 => Length_To_Return := Packed_F32x8.Size_In_Bytes;
            -- Length for Css_Cos_Values_B:
            when 2 => Length_To_Return := Packed_F32x8.Size_In_Bytes;
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
            -- Length for Spacecraft_Attitude:
            when 0 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Nav_Att.Size_In_Bytes - 1) :=
                  Nav_Att.Serialization.To_Byte_Array (Self.Spacecraft_Attitude);
            -- Length for Css_Cos_Values_A:
            when 1 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Packed_F32x8.Size_In_Bytes - 1) :=
                  Packed_F32x8.Serialization.To_Byte_Array (Self.Css_Cos_Values_A);
            -- Length for Css_Cos_Values_B:
            when 2 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Packed_F32x8.Size_In_Bytes - 1) :=
                  Packed_F32x8.Serialization.To_Byte_Array (Self.Css_Cos_Values_B);
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
   --    Data products for the Sunline SRuKF component.
   -- Output state from the sunline SRuKF algorithm (timeTag, sigma_BN, omega_BN_B,
   -- vehSunPntBdy).
   overriding procedure Sunline_Srukf_State (Self : in out Instance; Arg : in Sunline_Srukf_Output.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Sunline_Srukf_State_History.Push (Arg);
   end Sunline_Srukf_State;

end Component.Sunline_Srukf.Implementation.Tester;
