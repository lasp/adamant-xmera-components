--------------------------------------------------------------------------------
-- Solar_Array_Reference Component Tester Body
--------------------------------------------------------------------------------

-- Includes:
with Parameter;

package body Component.Solar_Array_Reference.Implementation.Tester is

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
      Self.Reference_Angle_History.Init (Depth => 100);
   end Init_Base;

   procedure Final_Base (Self : in out Instance) is
   begin
      -- Destroy tester heap:
      -- Connector histories:
      Self.Data_Product_Fetch_T_Service_History.Destroy;
      Self.Data_Product_T_Recv_Sync_History.Destroy;
      -- Data product histories:
      Self.Reference_Angle_History.Destroy;
   end Final_Base;

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance) is
   begin
      Self.Component_Instance.Attach_Data_Product_Fetch_T_Request (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_Fetch_T_Service_Access);
      Self.Component_Instance.Attach_Data_Product_T_Send (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_T_Recv_Sync_Access);
      Self.Attach_Tick_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Tick_T_Recv_Sync_Access);
      Self.Attach_Reset_Tick_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Reset_Tick_T_Recv_Sync_Access);
      Self.Attach_Parameter_Update_T_Provide (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Parameter_Update_T_Modify_Access);
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
            -- ID for Navigation_Attitude:
            when 0 => Id_To_Return := 0;
            -- ID for Attitude_Reference:
            when 1 => Id_To_Return := 1;
            -- ID for Sun_Direction_Body:
            when 2 => Id_To_Return := 2;
            -- ID for Tracking_Mode:
            when 3 => Id_To_Return := 3;
            -- ID for Specified_Array_Angle:
            when 4 => Id_To_Return := 4;
            -- ID for Offset_Angle:
            when 5 => Id_To_Return := 5;
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
            -- Length for Navigation_Attitude:
            when 0 => Length_To_Return := Nav_Att_Output.Size_In_Bytes;
            -- Length for Attitude_Reference:
            when 1 => Length_To_Return := Att_Ref.Size_In_Bytes;
            -- Length for Sun_Direction_Body:
            when 2 => Length_To_Return := Packed_F32x3.Size_In_Bytes;
            -- Length for Tracking_Mode:
            when 3 => Length_To_Return := Packed_Tracking_Mode.Size_In_Bytes;
            -- Length for Specified_Array_Angle:
            when 4 => Length_To_Return := Packed_Array_Angle.Size_In_Bytes;
            -- Length for Offset_Angle:
            when 5 => Length_To_Return := Packed_Array_Angle.Size_In_Bytes;
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
            -- Length for Navigation_Attitude:
            when 0 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Nav_Att_Output.Size_In_Bytes - 1) :=
                  Nav_Att_Output.Serialization.To_Byte_Array (Self.Navigation_Attitude);
            -- Length for Attitude_Reference:
            when 1 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Att_Ref.Size_In_Bytes - 1) :=
                  Att_Ref.Serialization.To_Byte_Array (Self.Attitude_Reference);
            -- Length for Sun_Direction_Body:
            when 2 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Packed_F32x3.Size_In_Bytes - 1) :=
                  Packed_F32x3.Serialization.To_Byte_Array (Self.Sun_Direction_Body);
            -- Length for Tracking_Mode:
            when 3 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Packed_Tracking_Mode.Size_In_Bytes - 1) :=
                  Packed_Tracking_Mode.Serialization.To_Byte_Array (Self.Tracking_Mode);
            -- Length for Specified_Array_Angle:
            when 4 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Packed_Array_Angle.Size_In_Bytes - 1) :=
                  Packed_Array_Angle.Serialization.To_Byte_Array (Self.Specified_Array_Angle);
            -- Length for Offset_Angle:
            when 5 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Packed_Array_Angle.Size_In_Bytes - 1) :=
                  Packed_Array_Angle.Serialization.To_Byte_Array (Self.Offset_Angle);
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
   --    Data products for the Solar Array Reference component.
   -- [rad] Reference rotation angle of the solar array about its drive axis, wrapped
   -- to [-pi, pi].
   overriding procedure Reference_Angle (Self : in out Instance; Arg : in Packed_F32.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Reference_Angle_History.Push (Arg);
   end Reference_Angle;

   -----------------------------------------------
   -- Special primitives for aiding in the staging,
   -- fetching, and updating of parameters
   -----------------------------------------------
   not overriding function Stage_Parameter (Self : in out Instance; Par : in Parameter.T) return Parameter_Update_Status.E is
      use Parameter_Enums.Parameter_Update_Status;
      use Parameter_Enums.Parameter_Operation_Type;
      Param_Update : Parameter_Update.T := (
         Table_Id => 1,
         Operation => Stage,
         Status => Success,
         Param => Par
      );
   begin
      Self.Parameter_Update_T_Provide (Param_Update);
      return Param_Update.Status;
   end Stage_Parameter;

   not overriding function Fetch_Parameter (Self : in out Instance; Id : in Parameter_Types.Parameter_Id; Par : out Parameter.T) return Parameter_Update_Status.E is
      use Parameter_Enums.Parameter_Update_Status;
      use Parameter_Enums.Parameter_Operation_Type;
      Param_Update : Parameter_Update.T := (
         Table_Id => 1,
         Operation => Fetch,
         Status => Success,
         Param => (Header => (Id => Id, Buffer_Length => 0), Buffer => [others => 0])
      );
   begin
      -- Set the ID to fetch:
      Param_Update.Param.Header.Id := Id;
      Self.Parameter_Update_T_Provide (Param_Update);
      Par := Param_Update.Param;
      return Param_Update.Status;
   end Fetch_Parameter;

   not overriding function Validate_Parameters (Self : in out Instance) return Parameter_Update_Status.E is
      use Parameter_Enums.Parameter_Update_Status;
      use Parameter_Enums.Parameter_Operation_Type;
      Param_Update : Parameter_Update.T := (
         Table_Id => 1,
         Operation => Validate,
         Status => Success,
         Param => ((0, 0), [others => 0])
      );
   begin
      Self.Parameter_Update_T_Provide (Param_Update);
      return Param_Update.Status;
   end Validate_Parameters;

   not overriding function Update_Parameters (Self : in out Instance) return Parameter_Update_Status.E is
      use Parameter_Enums.Parameter_Update_Status;
      use Parameter_Enums.Parameter_Operation_Type;
      Param_Update : Parameter_Update.T := (
         Table_Id => 1,
         Operation => Update,
         Status => Success,
         Param => ((0, 0), [others => 0])
      );
   begin
      Self.Parameter_Update_T_Provide (Param_Update);
      return Param_Update.Status;
   end Update_Parameters;

end Component.Solar_Array_Reference.Implementation.Tester;
