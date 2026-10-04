--------------------------------------------------------------------------------
-- Mrp_Rotation Component Tester Body
--------------------------------------------------------------------------------

-- Includes:
with Parameter;

package body Component.Mrp_Rotation.Implementation.Tester is

   ---------------------------------------
   -- Test initialization functions:
   ---------------------------------------
   procedure Connect (Self : in out Instance) is
   begin
      Self.Attach_Att_Ref_Tick_T_Request (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Att_Ref_Tick_T_Service_Access);
      Self.Attach_Reset_Tick_T_Send (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Reset_Tick_T_Recv_Sync_Access);
      Self.Attach_Parameter_Update_T_Provide (To_Component => Self.Component_Instance'Unchecked_Access, Hook => Self.Component_Instance.Parameter_Update_T_Modify_Access);
   end Connect;

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

end Component.Mrp_Rotation.Implementation.Tester;
