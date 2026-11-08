--------------------------------------------------------------------------------
-- Torque_Thr_Force_Mapping Tests Body
--------------------------------------------------------------------------------

with Ada.Assertions;
with AUnit.Assertions;
with Basic_Assertions; use Basic_Assertions;
with Desired_Control_Axes;
with Force_Torque_Thr_Force_Mapping_Enums;
with Torque_Thr_Force_Mapping_Parameters;
with Packed_F32x3;
with Packed_U32;
with Packed_F32x8;
with Thruster_Availability_X8;
with Packed_F32x24;
with Parameter_Enums.Assertion;
with Parameter;
with Thr_Force_Cmd;
use Parameter_Enums.Assertion;
use Parameter_Enums.Parameter_Update_Status;

package body Torque_Thr_Force_Mapping_Tests.Implementation is

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

      -- Call component init here.
      Self.Tester.Component_Instance.Init;

      -- Call the component set up method that the assembly would normally call.
      Self.Tester.Component_Instance.Set_Up;
   end Set_Up_Test;

   overriding procedure Tear_Down_Test (Self : in out Instance) is
   begin
      -- Free the C++ algorithm heap:
      Self.Tester.Component_Instance.Destroy;
      -- Free component heap:
      Self.Tester.Final_Base;
   end Tear_Down_Test;

   -------------------------------------------------------------------------
   -- Helpers:
   -------------------------------------------------------------------------

   -- Run one cycle with the given torque command and return the published thruster
   -- forces.
   function Map_Torque (
      Self : in out Instance;
      Torque : in Packed_F32x3.T;
      Cycle : in Positive
   ) return Packed_F32x8.U is
      T : Component.Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Output : Thr_Force_Cmd.T;
   begin
      T.Commanded_Torque := (Torque_Request_Body => Torque);
      T.Tick_T_Send ((Time => T.System_Time, Count => 0));
      Natural_Assert.Eq (T.Thruster_Force_Cmd_History.Get_Count, Cycle);
      Output := T.Thruster_Force_Cmd_History.Get (Cycle);
      return Packed_F32x8.Unpack (Output.Thr_Force);
   end Map_Torque;

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
   -- forces, with no force commanded. The expectations are those of the force torque
   -- mapping's pure torque case, since a zero commanded force is what that case
   -- passes explicitly.
   overriding procedure Test_Pure_Torque (Self : in out Instance) is
      Expected_Torque_X : constant Packed_F32x8.U :=
         [0.0, 0.166667, 0.0, 0.0, 0.0, 0.166667, 0.0, 0.333333];
      Expected_Torque_Y : constant Packed_F32x8.U :=
         [0.0, 0.0, 0.166667, 0.0, 0.0, 0.333333, 0.0, 0.166667];
      Expected_Torque_Z : constant Packed_F32x8.U :=
         [0.0, 0.0, 0.083333, 0.083333, 0.0, 0.416667, 0.5, 0.083333];
   begin
      Assert_Forces (Map_Torque (Self, [1.0, 0.0, 0.0], 1), Expected_Torque_X);
      Assert_Forces (Map_Torque (Self, [0.0, 1.0, 0.0], 2), Expected_Torque_Y);
      Assert_Forces (Map_Torque (Self, [0.0, 0.0, 1.0], 3), Expected_Torque_Z);
   end Test_Pure_Torque;

   -- A zero torque command produces zero thruster force on every thruster.
   overriding procedure Test_Zero_Command (Self : in out Instance) is
   begin
      Assert_Forces (Map_Torque (Self, [0.0, 0.0, 0.0], 1), Packed_F32x8.U'[others => 0.0]);
   end Test_Zero_Command;

   -- Every mapped thruster force is non negative and at least one is zero. The
   -- algorithm shifts the least-squares solution along the null space of DG, which
   -- leaves the achieved force and torque unchanged, and then clamps at zero, so a
   -- thruster can never be commanded to pull.
   overriding procedure Test_Min_Shift (Self : in out Instance) is
      Forces : Packed_F32x8.U;
      Minimum : Short_Float;
   begin
      Forces := Map_Torque (Self, [0.4, 0.2, 0.4], 1);

      Minimum := Forces (Forces'First);
      for I in Forces'Range loop
         Short_Float_Assert.Ge (Forces (I), 0.0);
         if Forces (I) < Minimum then
            Minimum := Forces (I);
         end if;
      end loop;
      Short_Float_Assert.Eq (Minimum, 0.0, Epsilon => Epsilon);
   end Test_Min_Shift;

   -- Applying a new thruster geometry changes the mapping used on the next tick. The
   -- default geometry's pure torque solution is known from the independent reference;
   -- the mirrored geometry maps the same torque onto different thrusters, and the
   -- result is still a set of non negative forces with a zero minimum.
   overriding procedure Test_Parameter_Update (Self : in out Instance) is
      T : Component.Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Torque_Thr_Force_Mapping_Parameters.Instance;
      Expected_Default : constant Packed_F32x8.U :=
         [0.0, 0.166667, 0.0, 0.0, 0.0, 0.166667, 0.0, 0.333333];
      Mirrored_Forces : Packed_F32x8.U;
      Minimum : Short_Float;
      Same : Boolean := True;
   begin
      -- The default geometry maps the command one way:
      Assert_Forces (Map_Torque (Self, [1.0, 0.0, 0.0], 1), Expected_Default);

      -- Install the mirrored geometry:
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.R_Thruster_B (Mirrored_Positions)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.T_Hat_Thruster_B (Default_Directions)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Center_Of_Mass_B (Origin)), Success);
      Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Params.Desired_Control_Axes_B (All_Axes)), Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);

      -- The same command now maps onto different thrusters:
      Mirrored_Forces := Map_Torque (Self, [1.0, 0.0, 0.0], 2);
      Minimum := Mirrored_Forces (Mirrored_Forces'First);
      for I in Mirrored_Forces'Range loop
         Short_Float_Assert.Ge (Mirrored_Forces (I), 0.0);
         if Mirrored_Forces (I) < Minimum then
            Minimum := Mirrored_Forces (I);
         end if;
         if abs (Mirrored_Forces (I) - Expected_Default (I)) > Epsilon then
            Same := False;
         end if;
      end loop;
      Short_Float_Assert.Eq (Minimum, 0.0, Epsilon => Epsilon);
      Boolean_Assert.Eq (Same, False);
   end Test_Parameter_Update;

   -- A configuration the algorithm rejects is refused at parameter staging, before
   -- it can reach the throwing Create/Set_Config across the FFI boundary. Each case
   -- perturbs one field of an otherwise valid set, so the rejection is attributable
   -- to that field.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance) is
      T : Component.Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
      Params : Torque_Thr_Force_Mapping_Parameters.Instance;

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

      -- An ill-conditioned geometry is rejected:
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

      -- A non-finite thruster position is rejected. The value is injected as raw bytes
      -- because the compiler will not let a non-finite Short_Float be written as a
      -- literal, and because that is how one would arrive: as bytes from the ground.
      -- Staging accepts it, and converting it for the algorithm raises, which validation
      -- reports as a rejection.
      Stage_Valid_Set;
      declare
         Par : Parameter.T := Params.R_Thruster_B (Default_Positions);
      begin
         -- Overwrite the first big-endian float with +infinity.
         Par.Buffer (Par.Buffer'First .. Par.Buffer'First + 3) := [16#7F#, 16#80#, 16#00#, 16#00#];
         Parameter_Update_Status_Assert.Eq (T.Stage_Parameter (Par), Success);
      end;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Validation_Error);

      -- Restoring validity makes the set acceptable again, so the rejections above
      -- were caused by the perturbed values rather than by sticky staging state:
      Stage_Valid_Set;
      Parameter_Update_Status_Assert.Eq (T.Validate_Parameters, Success);
      Parameter_Update_Status_Assert.Eq (T.Update_Parameters, Success);
   end Test_Invalid_Parameter;

   -- A data dependency that comes back with the wrong identifier means the assembly
   -- is wired incorrectly. The component asserts rather than publishing anything.
   overriding procedure Test_Invalid_Data_Dependency (Self : in out Instance) is
      T : Component.Torque_Thr_Force_Mapping.Implementation.Tester.Instance_Access renames Self.Tester;
   begin
      T.Data_Dependency_Return_Id_Override := 999;
      begin
         T.Tick_T_Send ((Time => T.System_Time, Count => 0));
         AUnit.Assertions.Assert (False, "A dependency with the wrong identifier should have failed an assertion.");
      exception
         when Ada.Assertions.Assertion_Error =>
            null; -- Expected.
      end;
      Natural_Assert.Eq (T.Thruster_Force_Cmd_History.Get_Count, 0);
   end Test_Invalid_Data_Dependency;

end Torque_Thr_Force_Mapping_Tests.Implementation;
