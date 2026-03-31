--------------------------------------------------------------------------------
-- Inertial_Ukf Component Implementation Body
--------------------------------------------------------------------------------

with Nav_Att;
with St_Att_Input.C;
with Gyro_Input;
with Gyro_Input.C;
with Rw_Speeds_Input;
with Rw_Speeds_Input.C;
with Rw_Array_Config_Input.C;
with Vehicle_Config_Input.C;
with Nav_Att.C;
with Inertial_Filter_Output.C;
with Inertial_UKF_Algorithm_C; use Inertial_UKF_Algorithm_C;
with Algorithm_Wrapper_Util;

package body Component.Inertial_Ukf.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial UKF component.
   -- No heap allocation needed -- InertialUKFAlgorithm is purely static.
   overriding procedure Init (Self : in out Instance) is
   begin
      null;
   end Init;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;
      use Algorithm_Wrapper_Util;

      -- Fetch data dependencies:
      St_Tracker_Att : Nav_Att.T;
      St_Tracker_Att_Status : constant Data_Dependency_Status.E :=
         Self.Get_Star_Tracker_Att (Value => St_Tracker_Att, Stale_Reference => Arg.Time);

      Gyro_Meas : Gyro_Input.T;
      Gyro_Meas_Status : constant Data_Dependency_Status.E :=
         Self.Get_Gyro_Measurement (Value => Gyro_Meas, Stale_Reference => Arg.Time);

      Rw_Speeds_Dep : Rw_Speeds_Input.T;
      Rw_Speeds_Status : constant Data_Dependency_Status.E :=
         Self.Get_Rw_Speeds (Value => Rw_Speeds_Dep, Stale_Reference => Arg.Time);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      if Is_Dep_Status_Success (St_Tracker_Att_Status) and then
         Is_Dep_Status_Success (Gyro_Meas_Status) and then
         Is_Dep_Status_Success (Rw_Speeds_Status)
      then
         declare
            -- Convert star tracker attitude from Nav_Att.T to St_Att_Input.C.U_C.
            -- Nav_Att has an extra vehSunPntBdy field not needed by the algorithm.
            Nav_Att_U : constant Nav_Att.U := Nav_Att.Unpack (St_Tracker_Att);
            St_Att_C : aliased St_Att_Input.C.U_C := St_Att_Input.C.To_C ((
               Time_Tag      => Short_Float (Nav_Att_U.Time_Tag),
               Mrp_Bdy_Inrtl => Nav_Att_U.Sigma_Bn,
               Omega_Bn_B    => Nav_Att_U.Omega_Bn_B
            ));

            -- Convert gyro measurement:
            Gyro_C : aliased Gyro_Input.C.U_C :=
               Gyro_Input.C.To_C (Gyro_Input.Unpack (Gyro_Meas));

            -- Convert reaction wheel speeds:
            Rw_C : aliased Rw_Speeds_Input.C.U_C :=
               Rw_Speeds_Input.C.To_C (Rw_Speeds_Input.Unpack (Rw_Speeds_Dep));

            -- Convert parameters to C types:
            Rw_Config_C : aliased Rw_Array_Config_Input.C.U_C :=
               Rw_Array_Config_Input.C.To_C (Self.Rw_Array_Config);
            Veh_Config_C : aliased Vehicle_Config_Input.C.U_C :=
               Vehicle_Config_Input.C.To_C (Self.Vehicle_Config);

            -- Call the stateless UKF algorithm:
            Output : constant Inertial_UKF_Output := Update_State (
               St_Att     => St_Att_C'Unchecked_Access,
               Gyro       => Gyro_C'Unchecked_Access,
               Rw_Speeds  => Rw_C'Unchecked_Access,
               Rw_Config  => Rw_Config_C'Unchecked_Access,
               Veh_Config => Veh_Config_C'Unchecked_Access
            );
         begin
            -- Publish navigation attitude estimate:
            Self.Data_Product_T_Send (Self.Data_Products.Nav_Att_Estimate (
               Arg.Time,
               Nav_Att.C.Pack (Output.Nav_Att_Est)
            ));

            -- Publish filter diagnostic data:
            Self.Data_Product_T_Send (Self.Data_Products.Filter_Data (
               Arg.Time,
               Inertial_Filter_Output.C.Pack (Output.Filter)
            ));
         end;
      end if;
   end Tick_T_Recv_Sync;

   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T) is
   begin
      -- Process the parameter update, staging or fetching parameters as requested.
      Self.Process_Parameter_Update (Arg);
   end Parameter_Update_T_Modify;

   -----------------------------------------------
   -- Parameter handlers:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Inertial UKF component.
   -- Invalid Parameter handler. This procedure is called when a parameter's type is found to be invalid:
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the parameters should be invalid in this case.
      pragma Assert (False);
   end Invalid_Parameter;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Inertial UKF component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Inertial_Ukf.Implementation;
