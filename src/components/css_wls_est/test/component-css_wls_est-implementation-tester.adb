--------------------------------------------------------------------------------
-- Css_Wls_Est Component Tester Body
--------------------------------------------------------------------------------

-- Includes:
with Parameter;

package body Component.Css_Wls_Est.Implementation.Tester is

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
      Self.Sun_Heading_B_History.Init (Depth => 100);
      Self.Omega_Bn_B_History.Init (Depth => 100);
      Self.Num_Active_Css_History.Init (Depth => 100);
      Self.Residual_State_Heading_History.Init (Depth => 100);
      Self.Post_Fit_Residuals_History.Init (Depth => 100);
   end Init_Base;

   procedure Final_Base (Self : in out Instance) is
   begin
      -- Destroy tester heap:
      -- Connector histories:
      Self.Data_Product_Fetch_T_Service_History.Destroy;
      Self.Data_Product_T_Recv_Sync_History.Destroy;
      -- Data product histories:
      Self.Sun_Heading_B_History.Destroy;
      Self.Omega_Bn_B_History.Destroy;
      Self.Num_Active_Css_History.Destroy;
      Self.Residual_State_Heading_History.Destroy;
      Self.Post_Fit_Residuals_History.Destroy;
   end Final_Base;

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance) is
   begin
      Self.Component_Instance.Attach_Data_Product_Fetch_T_Request (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_Fetch_T_Service_Access);
      Self.Component_Instance.Attach_Data_Product_T_Send (To_Component => Self'Unchecked_Access, Hook => Self.Data_Product_T_Recv_Sync_Access);
      Self.Attach_Tick_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Tick_T_Recv_Sync_Access);
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
            -- ID for Css_Sensor_Input:
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
            -- Length for Css_Sensor_Input:
            when 0 => Length_To_Return := Css_Sensor_Values.Size_In_Bytes;
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
            -- Length for Css_Sensor_Input:
            when 0 =>
               Buffer_To_Return (Buffer_To_Return'First .. Buffer_To_Return'First + Css_Sensor_Values.Size_In_Bytes - 1) :=
                  Css_Sensor_Values.Serialization.To_Byte_Array (Self.Css_Sensor_Input);
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
   --    Data products for the Css Wls Est component.
   -- [-] Estimated unit sun heading in the body frame. Zero when no fit was
   -- possible.
   overriding procedure Sun_Heading_B (Self : in out Instance; Arg : in Packed_F32x3.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Sun_Heading_B_History.Push (Arg);
   end Sun_Heading_B;

   -- [r/s] Inertial angular velocity in the body frame. Zero until two headings have
   -- been observed.
   overriding procedure Omega_Bn_B (Self : in out Instance; Arg : in Packed_F32x3.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Omega_Bn_B_History.Push (Arg);
   end Omega_Bn_B;

   -- [-] Sensors whose reading exceeded the use threshold this cycle.
   overriding procedure Num_Active_Css (Self : in out Instance; Arg : in Packed_U32.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Num_Active_Css_History.Push (Arg);
   end Num_Active_Css;

   -- [-] Heading captured before the singular-fit zeroing, for diagnostics.
   overriding procedure Residual_State_Heading (Self : in out Instance; Arg : in Packed_F32x3.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Residual_State_Heading_History.Push (Arg);
   end Residual_State_Heading;

   -- [-] Post-fit measurement residuals for the 8 physical channels.
   overriding procedure Post_Fit_Residuals (Self : in out Instance; Arg : in Packed_F32x8.T) is
   begin
      -- Push the argument onto the test history for looking at later:
      Self.Post_Fit_Residuals_History.Push (Arg);
   end Post_Fit_Residuals;

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

end Component.Css_Wls_Est.Implementation.Tester;
