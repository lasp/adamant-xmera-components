--------------------------------------------------------------------------------
-- Force_Torque_Thr_Force_Mapping Tests Body
--------------------------------------------------------------------------------

with Basic_Assertions; use Basic_Assertions;
with Desired_Control_Axes;
with Force_Torque_Thr_Force_Mapping_Enums;
with Force_Torque_Thr_Force_Mapping_Parameters;
with Packed_F32x3;
with Packed_U32;
with Packed_F32x8;
with Thruster_Availability_X8;
with Packed_F32x24;
with Parameter_Enums.Assertion;
with Thr_Force_Cmd;
use Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;

package body Force_Torque_Thr_Force_Mapping_Tests.Implementation is

   -- The expected thruster forces below were computed from an independent
   -- single-precision truncated-SVD pseudo-inverse of the control mapping matrix,
   -- not from this algorithm. The reference must use fp32, not fp64: the null-space
   -- shift divides by an entry of the shift direction, so the entry it selects can
   -- change with the precision, and the two would then clamp different thrusters.
   -- Epsilon is the fp32 agreement budget between the two.
   Epsilon : constant Short_Float := 0.0001;

   -- The eight-thruster geometry the parameter defaults carry: two thrusters at
   -- each of four corners, covering all six axes, with a condition number of 2.
   Default_Positions : constant Packed_F32x24.T :=
      [-1.0, -1.0, +1.0,
       -1.0, -1.0, +1.0,
       +1.0, +1.0, +1.0,
       +1.0, +1.0, +1.0,
       +1.0, +1.0, -1.0,
       +1.0, +1.0, -1.0,
       -1.0, -1.0, -1.0,
       -1.0, -1.0, -1.0];
   Default_Directions : constant Packed_F32x24.T :=
      [+0.0, +1.0, +0.0,
       +0.0, +0.0, -1.0,
       +0.0, +0.0, -1.0,
       -1.0, +0.0, +0.0,
       +0.0, -1.0, +0.0,
       -1.0, +0.0, +0.0,
       +1.0, +0.0, +0.0,
       +0.0, +1.0, +0.0];
   Origin : constant Packed_F32x3.T := [0.0, 0.0, 0.0];
   All_Axes : constant Desired_Control_Axes.T :=
      (Torque_X => True, Torque_Y => True, Torque_Z => True,
       Force_X => True, Force_Y => True, Force_Z => True);
   -- The full complement the default geometry configures.
   All_Thrusters : constant Packed_U32.T := (Value => 8);
   All_Available : constant Thruster_Availability_X8.T :=
      [others => Force_Torque_Thr_Force_Mapping_Enums.Device_Availability.Available];

   -- The default geometry mirrored through the body x axis. Still full rank with a
   -- condition number of 2, but it maps a given command onto different thrusters.
   Mirrored_Positions : constant Packed_F32x24.T :=
      [+1.0, -1.0, +1.0,
       +1.0, -1.0, +1.0,
       -1.0, +1.0, +1.0,
       -1.0, +1.0, +1.0,
       -1.0, +1.0, -1.0,
       -1.0, +1.0, -1.0,
       +1.0, -1.0, -1.0,
       +1.0, -1.0, -1.0];

   -- Layout with every thrust direction in the body y-z plane, so no thruster can
   -- produce a body x force. Used to exercise the controllability assertion.
   No_X_Force_Positions : constant Packed_F32x24.T :=
      [+0.964717, +0.881380, +1.800225,
       +0.964717, +0.881380, +0.565785,
       -0.964717, +0.881380, +1.800225,
       -0.964717, +0.881380, +0.565785,
       -0.964717, -0.881380, +1.800225,
       -0.964717, -0.881380, +0.565785,
       +0.964717, -0.881380, +1.800225,
       +0.964717, -0.881380, +0.565785];
   No_X_Force_Directions : constant Packed_F32x24.T :=
      [+0.0, -0.70710678, +0.70710678,
       +0.0, -0.70710678, -0.70710678,
       +0.0, -0.70710678, +0.70710678,
       +0.0, -0.70710678, -0.70710678,
       +0.0, +0.70710678, +0.70710678,
       +0.0, +0.70710678, -0.70710678,
       +0.0, +0.70710678, +0.70710678,
       +0.0, +0.70710678, -0.70710678];

   -- Six axes are covered, but the 5 mm moment arms leave the torque rows three
   -- orders of magnitude below the force rows, so the mapping is ill conditioned.
   Ill_Conditioned_Positions : constant Packed_F32x24.T :=
      [+0.005, +0.000, +0.000,
       -0.005, +0.000, +0.000,
       +0.000, +0.005, +0.000,
       +0.000, -0.005, +0.000,
       +0.000, +0.000, +0.005,
       +0.000, +0.000, -0.005,
       +0.005, +0.000, +0.000,
       +0.000, +0.005, +0.000];
   Ill_Conditioned_Directions : constant Packed_F32x24.T :=
      [+0.0, +1.0, +0.0,
       +0.0, -1.0, +0.0,
       +0.0, +0.0, +1.0,
       +0.0, +0.0, -1.0,
       +1.0, +0.0, +0.0,
       -1.0, +0.0, +0.0,
       +0.0, +1.0, +0.0,
       +0.0, +0.0, +1.0];

   -------------------------------------------------------------------------
   -- Fixtures:
   -------------------------------------------------------------------------

   overriding procedure Set_Up_Test (Self : in out Instance) is
   begin
      -- Allocate heap memory to component:
      Self.Tester.Init_Base;

      -- Make necessary connections between tester and component:
      Self.Tester.Connect;

      -- Component Init will be called manually in test body
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      -- Free component heap:
      Self.Tester.Component_Instance.Destroy;
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Run one cycle with the given command and return the published thruster forces.
   function Map_Command (
      Self : in out Instance;
      Torque : in Packed_F32x3.T;
      Force : in Packed_F32x3.T;
      Cycle : in Positive
   ) return Packed_F32x8.U is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Output : Thr_Force_Cmd.T;
   begin
      T.Commanded_Torque := (Torque_Request_Body => Torque);
      T.Commanded_Force := (Force_Request_Body => Force);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Thruster_Force_Cmd_History.Get_Count, Cycle);
      Output := T.Thruster_Force_Cmd_History.Get (Cycle);
      return Packed_F32x8.Unpack (Output.Thr_Force);
   end Map_Command;

   -- Compare a published thruster force vector against the independent reference.
   --
   -- Both sides are the unpacked form. Indexing the big-endian packed array reads
   -- each element through a validity check that GNAT evaluates on the unswapped
   -- bytes, so a stored 0.5 of 16#3E_FF_FF_FF# reads as a NaN and raises
   -- Constraint_Error. The unpacked array carries no storage order and reads
   -- correctly.
   procedure Assert_Forces (Actual : in Packed_F32x8.U; Expected : in Packed_F32x8.U) is
   begin
      for I in Actual'Range loop
         Short_Float_Assert.Eq (Actual (I), Expected (I), Epsilon => Epsilon);
      end loop;
   end Assert_Forces;

   -------------------------------------------------------------------------
   -- Tests:
   -------------------------------------------------------------------------

   -- A commanded torque about each body axis is reproduced by the mapped thruster
   -- forces.
   overriding procedure Test_Pure_Torque (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Expected_Torque_X : constant Packed_F32x8.U :=
         [0.0, 0.166667, 0.0, 0.0, 0.0, 0.166667, 0.0, 0.333333];
      Expected_Torque_Y : constant Packed_F32x8.U :=
         [0.0, 0.0, 0.166667, 0.0, 0.0, 0.333333, 0.0, 0.166667];
      Expected_Torque_Z : constant Packed_F32x8.U :=
         [0.0, 0.0, 0.083333, 0.083333, 0.0, 0.416667, 0.5, 0.083333];
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      Assert_Forces (Map_Command (Self, [1.0, 0.0, 0.0], [0.0, 0.0, 0.0], 1), Expected_Torque_X);
      Assert_Forces (Map_Command (Self, [0.0, 1.0, 0.0], [0.0, 0.0, 0.0], 2), Expected_Torque_Y);
      Assert_Forces (Map_Command (Self, [0.0, 0.0, 1.0], [0.0, 0.0, 0.0], 3), Expected_Torque_Z);
   end Test_Pure_Torque;

   -- A commanded force along each body axis is reproduced by the mapped thruster
   -- forces.
   overriding procedure Test_Pure_Force (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Expected_Force_X : constant Packed_F32x8.U :=
         [0.0, 0.0, 0.083333, 0.0, 0.083333, 0.0, 0.583333, 0.166667];
      Expected_Force_Y : constant Packed_F32x8.U :=
         [0.416667, 0.0, 0.083333, 0.083333, 0.0, 0.416667, 0.5, 0.583333];
      -- No thrust direction in this layout has a +z component, so a +z force needs a
      -- pulling thruster. The null-space shift cannot lift those entries, and the clamp
      -- takes them to zero, which drops the command entirely.
      Expected_Force_Z : constant Packed_F32x8.U := [others => 0.0];
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      Assert_Forces (Map_Command (Self, [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], 1), Expected_Force_X);
      Assert_Forces (Map_Command (Self, [0.0, 0.0, 0.0], [0.0, 1.0, 0.0], 2), Expected_Force_Y);
      Assert_Forces (Map_Command (Self, [0.0, 0.0, 0.0], [0.0, 0.0, 1.0], 3), Expected_Force_Z);
   end Test_Pure_Force;

   -- A simultaneous force and torque command is reproduced by the mapped thruster
   -- forces.
   overriding procedure Test_Combined_Force_And_Torque (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Expected : constant Packed_F32x8.U :=
         [0.183333, 0.0, 0.0, 0.0, 0.0, 0.683333, 1.2, 0.916667];
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      Assert_Forces (Map_Command (Self, [0.4, 0.2, 0.4], [0.9, 1.1, 1.0], 1), Expected);
   end Test_Combined_Force_And_Torque;

   -- A zero force and torque command produces zero thruster force on every thruster.
   overriding procedure Test_Zero_Command (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      Assert_Forces (Map_Command (Self, [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], 1), Packed_F32x8.U'[others => 0.0]);
   end Test_Zero_Command;

   -- Every mapped thruster force is non negative and at least one is zero. The
   -- algorithm shifts the least-squares solution along the null space of DG, which
   -- leaves the achieved force and torque unchanged, and then clamps at zero, so a
   -- thruster can never be commanded to pull.
   overriding procedure Test_Min_Shift (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Forces : Packed_F32x8.U;
      Minimum : Short_Float;
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      Forces := Map_Command (Self, [0.4, 0.2, 0.4], [0.9, 1.1, 1.0], 1);

      Minimum := Forces (Forces'First);
      for I in Forces'Range loop
         Short_Float_Assert.Ge (Forces (I), 0.0);
         if Forces (I) < Minimum then
            Minimum := Forces (I);
         end if;
      end loop;
      Short_Float_Assert.Eq (Minimum, 0.0, Epsilon => Epsilon);
   end Test_Min_Shift;

   -- Applying a new thruster geometry changes the mapping used on the next tick.
   overriding procedure Test_Parameter_Update (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Force_Torque_Thr_Force_Mapping_Parameters.Instance;
      Expected_Default : constant Packed_F32x8.U :=
         [0.183333, 0.0, 0.0, 0.0, 0.0, 0.683333, 1.2, 0.916667];
      Expected_Mirrored : constant Packed_F32x8.U :=
         [0.466667, 0.0, 0.0, 0.0, 0.0, 0.0, 0.325, 0.408333];
   begin
      T.Component_Instance.Init;
      T.Component_Instance.Set_Up;

      -- The default geometry maps the command one way:
      Assert_Forces (Map_Command (Self, [0.4, 0.2, 0.4], [0.9, 1.1, 1.0], 1), Expected_Default);

      -- Install the mirrored geometry:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Thruster_B (Mirrored_Positions)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.T_Hat_Thruster_B (Default_Directions)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Center_Of_Mass_B (Origin)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Desired_Control_Axes_B (All_Axes)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- The same command now maps onto different thrusters:
      Assert_Forces (Map_Command (Self, [0.4, 0.2, 0.4], [0.9, 1.1, 1.0], 2), Expected_Mirrored);
   end Test_Parameter_Update;

   -- A configuration the algorithm rejects is refused at parameter staging, before
   -- it can reach the throwing Create/Set_Config across the FFI boundary. Each case
   -- perturbs one field of an otherwise valid set, so the rejection is attributable
   -- to that field.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Force_Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Force_Torque_Thr_Force_Mapping_Parameters.Instance;

      procedure Stage_Valid_Set is
      begin
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Num_Thrusters (All_Thrusters)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Thruster_B (Default_Positions)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.T_Hat_Thruster_B (Default_Directions)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Center_Of_Mass_B (Origin)), Success);
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Desired_Control_Axes_B (All_Axes)), Success);
         Parameter_Update_Status_Assert.Eq (
            T.Stage_Parameter (Params.Thruster_Availability (All_Available)), Success);
      end Stage_Valid_Set;
   begin
      T.Component_Instance.Init;

      -- The baseline set is accepted:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- A thrust direction that is not a unit vector is rejected:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.T_Hat_Thruster_B ([0 => 0.5, others => 0.0])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Asserting an axis the thruster array cannot control is rejected. Every
      -- direction in this layout lies in the body y-z plane, so no combination of
      -- thrusters produces a body x force:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.R_Thruster_B (No_X_Force_Positions)), Success);
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.T_Hat_Thruster_B (No_X_Force_Directions)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- The same layout is accepted once the uncontrollable axis is not asserted:
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Desired_Control_Axes_B (
            (Torque_X => True, Torque_Y => True, Torque_Z => True,
             Force_X => False, Force_Y => True, Force_Z => True))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);

      -- An ill-conditioned geometry is rejected. The axis selection is left at the
      -- default, so the rejection is attributable to the conditioning check: selecting
      -- no axis at all is refused by a separate rule, exercised below.
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.R_Thruster_B (Ill_Conditioned_Positions)), Success);
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.T_Hat_Thruster_B (Ill_Conditioned_Directions)), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- A thruster count outside [1, MAX_EFF_CNT] is rejected at both ends:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Num_Thrusters ((Value => 0))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Num_Thrusters ((Value => 9))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Selecting no control axis is rejected on an otherwise valid set:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Desired_Control_Axes_B (
            (Torque_X => False, Torque_Y => False, Torque_Z => False,
             Force_X => False, Force_Y => False, Force_Z => False))), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Marking every thruster unavailable is rejected: the mapping needs at least one.
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (
         T.Stage_Parameter (Params.Thruster_Availability (
            [others => Force_Torque_Thr_Force_Mapping_Enums.Device_Availability.Unavailable])), Success);
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above
      -- were caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

end Force_Torque_Thr_Force_Mapping_Tests.Implementation;
