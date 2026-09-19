--------------------------------------------------------------------------------
-- Celestial_Two_Body_Point Component Implementation Body
--------------------------------------------------------------------------------

with Att_Ref;
with Att_Ref.C;
with Cartesian_State;
with Packed_F64x3.C;

package body Component.Celestial_Two_Body_Point.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the celestial two body point algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Create throws on an invalid configuration, so the parameter default must be a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks it at startup
      -- and in unit test set up.
      Self.Alg := Create (Alignment_Threshold => Self.Alignment_Threshold.Value);
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

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All three states are published fresh by the ephemeris components earlier in
      -- the same tick, so any other status indicates that this component is not wired
      -- up correctly in the algorithm execution order. That should never happen, so we
      -- assert.
      Primary : Cartesian_State.T;
      Primary_Status : constant Data_Dependency_Status.E :=
         Self.Get_Primary_Body_State (Value => Primary, Stale_Reference => Arg.Time);
      pragma Assert (Primary_Status = Success);
      Secondary : Cartesian_State.T;
      Secondary_Status : constant Data_Dependency_Status.E :=
         Self.Get_Secondary_Body_State (Value => Secondary, Stale_Reference => Arg.Time);
      pragma Assert (Secondary_Status = Success);
      Spacecraft : Cartesian_State.T;
      Spacecraft_Status : constant Data_Dependency_Status.E :=
         Self.Get_Spacecraft_State (Value => Spacecraft, Stale_Reference => Arg.Time);
      pragma Assert (Spacecraft_Status = Success);
   begin
      -- Apply any pending parameter update (e.g. a new alignment threshold):
      Self.Update_Parameters;

      -- Call the C algorithm and publish the reference. Each position and velocity is
      -- converted straight from the packed record and crosses by value. Update is
      -- qualified because Parameter_Enums also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Attitude_Reference (
         Arg.Time,
         Att_Ref.C.Pack (Celestial_Two_Body_Point_Algorithm_C.Update (
            Self.Alg,
            R_Pn_N => (Value => Packed_F64x3.C.Unpack (Primary.Position)),
            V_Pn_N => (Value => Packed_F64x3.C.Unpack (Primary.Velocity)),
            R_Sn_N => (Value => Packed_F64x3.C.Unpack (Secondary.Position)),
            V_Sn_N => (Value => Packed_F64x3.C.Unpack (Secondary.Velocity)),
            R_Bn_N => (Value => Packed_F64x3.C.Unpack (Spacecraft.Position)),
            V_Bn_N => (Value => Packed_F64x3.C.Unpack (Spacecraft.Velocity))))
      ));
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
   --    Parameters for the Celestial Two Body Point component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the configuration into the C algorithm.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The value was checked by Validate_Parameters at staging, so Set_Config will not
      -- reject it.
      Set_Config (Self.Alg, Alignment_Threshold => Self.Alignment_Threshold.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary. The value crosses the boundary
   -- as the bare float, so no marshalling here can raise.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Alignment_Threshold : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
   begin
      if Validate_Config (Alignment_Threshold => Alignment_Threshold.Value) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Celestial Two Body Point component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Celestial_Two_Body_Point.Implementation;
