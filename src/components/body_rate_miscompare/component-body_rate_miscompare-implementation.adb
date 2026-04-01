--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;
with Interfaces.C;
with Algorithm_Wrapper_Util;

package body Component.Body_Rate_Miscompare.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the body rate miscompare algorithm.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Allocate C++ class on the heap
      Self.Alg := Create;
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;
      use Algorithm_Wrapper_Util;

      -- Grab data dependencies:
      Imu_Body : Packed_F32x3_Record.T;
      Imu_Body_Status : constant Data_Dependency_Status.E :=
         Self.Get_Imu_Body (Value => Imu_Body, Stale_Reference => Arg.Time);
      St_Body : St_Att.T;
      St_Body_Status : constant Data_Dependency_Status.E :=
         Self.Get_Star_Tracker_Attitude (Value => St_Body, Stale_Reference => Arg.Time);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      if Is_Dep_Status_Success (Imu_Body_Status) and then
         Is_Dep_Status_Success (St_Body_Status)
      then
         -- Call algorithm with angular velocity vectors:
         declare
            Imu_Omega : constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (Imu_Body.Value));
            St_Omega : constant Packed_F32x3_Record.C.U_C := (Value => Packed_F32x3.C.Unpack (St_Body.Omega_Bn_B));

            Output : constant Body_Rate_Miscompare_Output_C := Update (
               Self.Alg,
               Imu_Omega => Imu_Omega,
               St_Omega  => St_Omega
            );
         begin
            -- Send out body rate data product:
            Self.Data_Product_T_Send (Self.Data_Products.Body_Rate (
               Arg.Time,
               (Time_Tag => 0.0,
                Sigma_Bn => [0.0, 0.0, 0.0],
                Omega_Bn_B => Packed_F32x3.C.Pack (Output.Omega_Bn_B.Value),
                Veh_Sun_Pnt_Bdy => [0.0, 0.0, 0.0])
            ));
            -- Send out body rate fault data product:
            Self.Data_Product_T_Send (Self.Data_Products.Rate_Fault_Status (
               Arg.Time,
               (Fault_Detected => Interfaces.C."/=" (Output.Body_Rate_Fault_Detected, 0))
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
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Set body rate threshold when parameters update:
      Set_Body_Rate_Threshold (Self.Alg, Self.Body_Rate_Threshold.Value);
   end Update_Parameters_Action;

   -- Description:
   --    Parameters for the Body Rate Miscompare component
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
   --    Data dependencies for the Body Rate Miscompare component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Body_Rate_Miscompare.Implementation;