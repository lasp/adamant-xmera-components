--------------------------------------------------------------------------------
-- Dv_Accumulation Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;

package body Component.Dv_Accumulation.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the delta-V accumulation algorithm with the control period.
   --
   -- Init Parameters:
   -- Control_Period : Basic_Types.Positive_Short_Float - [s] Time between two
   -- algorithm updates, the integration step of each sample, so it must equal the
   -- rate at which the component is scheduled. Fixed by the assembly, so it is not a
   -- runtime parameter. The type keeps it greater than zero.
   --
   overriding procedure Init (Self : in out Instance; Control_Period : in Basic_Types.Positive_Short_Float) is
   begin
      -- Create throws on an invalid configuration. The control period's type keeps it
      -- positive, and it is finite, so this asserts a property of the type rather than
      -- checking runtime input.
      pragma Assert (Validate_Config (Control_Period => Control_Period));
      Self.Alg := Create (Control_Period => Control_Period);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Integrate the acceleration of this tick and publish the accumulated delta-V.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The voted acceleration is produced every tick, earlier in the same tick,
      -- so any other status indicates that this component is not wired up
      -- correctly in the algorithm execution order. That should never happen, so
      -- we assert.
      Accel : Packed_F32x3.T;
      Accel_Status : constant Data_Dependency_Status.E :=
         Self.Get_Accel_Average (Value => Accel, Stale_Reference => Arg.Time);
      pragma Assert (Accel_Status = Success);
      -- The bias is published once, when the burn is set up, and holds for the
      -- whole burn, so a stale bias is used like a fresh one. Not_Available (no
      -- bias was ever published) and Error indicate an assembly defect, so we
      -- assert.
      Bias : Packed_F32x3.T;
      Bias_Status : constant Data_Dependency_Status.E :=
         Self.Get_Accel_Bias_B (Value => Bias, Stale_Reference => Arg.Time);
      pragma Assert (Bias_Status = Success or else Bias_Status = Stale);
   begin
      -- Integrate the sample, less the bias, and publish the accumulated delta-V.
      Self.Data_Product_T_Send (Self.Data_Products.Accumulated_Delta_V (
         Arg.Time,
         Packed_F32x3.C.Pack (Update (
            Self.Alg,
            R_Ddot_No_Gravity_Bn_B => (Value => Packed_F32x3.C.Unpack (Accel)),
            Accel_Bias_B           => (Value => Packed_F32x3.C.Unpack (Bias))).Value)
      ));
   end Tick_T_Recv_Sync;

   -- Zero the accumulated delta-V and start a new accumulation window at the next
   -- tick. The assembly fires this when a burn is set up, before the burn executor is
   -- started.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T) is
      Ignore : Tick.T renames Arg;
   begin
      -- Zeroes the accumulator and restarts the window only.
      Re_Initialize (Self.Alg);
   end Reset_Tick_T_Recv_Sync;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Dv Accumulation component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Dv_Accumulation.Implementation;
