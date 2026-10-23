--------------------------------------------------------------------------------
-- Average_Rw_Speed_Data Component Implementation Body
--------------------------------------------------------------------------------

with Rw_Speed_Sample.C;
with Rwa_Speeds.C;
with Sys_Time.Arithmetic;

package body Component.Average_Rw_Speed_Data.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the averaging algorithm with the default parameter values.
   overriding procedure Init (Self : in out Instance) is
   begin
      -- Create throws on an invalid configuration, so the parameter default must form a
      -- valid one. The generated Assert_Valid_Parameter_Defaults checks it at startup
      -- and in unit test set up.
      Self.Alg := Create (Rw_Speed_Averaging_Window => Self.Averaging_Window.Value);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Take the wheel speed measurement of this tick as a sample and publish the averaged
   -- speeds.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The wheel speeds are measured by the reaction wheel interface on every tick,
      -- earlier in the same tick, and stamped with the time of the measurement. Any
      -- other status indicates that this component is not wired up correctly in the
      -- algorithm execution order. That should never happen, so we assert.
      Speeds : Rwa_Speeds.T;
      Speeds_Time : Sys_Time.T;
      Speeds_Status : constant Data_Dependency_Status.E :=
         Self.Get_Wheel_Speeds (Value => Speeds, Timestamp => Speeds_Time, Stale_Reference => Arg.Time);
      pragma Assert (Speeds_Status = Success);

      -- The speeds record is exactly the array the shim takes, so the dependency
      -- crosses the FFI boundary unpacked behind its measurement time. The sample
      -- crosses by pointer, so it needs an object to point at.
      Sample : aliased constant Rw_Speed_Sample.C.U_C :=
         (Meas_Time => Sys_Time.Arithmetic.To_Nanoseconds (Speeds_Time), Wheel_Speeds => Rwa_Speeds.C.Unpack (Speeds));
   begin
      -- Apply any pending parameter update (e.g. a new window):
      Self.Update_Parameters;

      -- Take the sample and publish the mean of the samples in the window, stamped
      -- with the time of the measurement. Update is qualified because Parameter_Enums
      -- also declares one.
      Self.Data_Product_T_Send (Self.Data_Products.Averaged_Wheel_Speeds (
         Speeds_Time,
         Rwa_Speeds.C.Pack (Average_Rw_Speed_Data_Algorithm_C.Update (Self.Alg, Sample => Sample'Access))
      ));
   end Tick_T_Recv_Sync;

   -- Clear the stored samples, so the average starts over from the next sample. The
   -- assembly fires this on a state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Clears the stored samples only; the configuration is untouched.
      Re_Initialize (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

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
   --    Parameters for the Average Rw Speed Data component.
   -- This procedure is called when the parameters of a component have been updated. In this case we
   -- push the whole configuration into the C algorithm. The stored samples are kept, so the new
   -- window applies to them from the next tick on.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- The value was checked by Validate_Parameters at staging, so Set_Config will not
      -- reject it.
      Set_Config (Self.Alg, Rw_Speed_Averaging_Window => Self.Averaging_Window.Value);
   end Update_Parameters_Action;

   -- Validate a staged parameter set before it is applied by asking the algorithm's own
   -- non-throwing Validate_Config predicate, so the config rules live solely in the
   -- algorithm. Rejecting an invalid update here at staging keeps it from reaching the
   -- throwing Create/Set_Config across the FFI boundary. The window crosses the boundary
   -- as it is, so no marshalling here can raise, and a non-finite value is rejected by
   -- the predicate.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Averaging_Window : in Packed_F32.U
   ) return Parameter_Validation_Status.E is
      Ignore : Instance renames Self;
   begin
      if Validate_Config (Rw_Speed_Averaging_Window => Averaging_Window.Value) then
         return Parameter_Validation_Status.Valid;
      else
         return Parameter_Validation_Status.Invalid;
      end if;
   end Validate_Parameters;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Average Rw Speed Data component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Average_Rw_Speed_Data.Implementation;
