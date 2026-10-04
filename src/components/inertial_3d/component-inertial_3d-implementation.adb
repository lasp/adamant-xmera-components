--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Body
--------------------------------------------------------------------------------

with Packed_F32x3.C;
with Packed_F32x3_Record.C;

package body Component.Inertial_3d.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
   overriding procedure Init (Self : in out Instance) is
      -- The reference attitude arrives as a data dependency, which cannot be
      -- fetched until the assembly is running. Construct the algorithm with the
      -- zero MRP so a tick landing before the first command still produces
      -- deterministic output.
      Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C :=
         Packed_F32x3_Record.C.Unpack ((Value => [0.0, 0.0, 0.0]));
   begin
      -- Create throws on an invalid configuration. The zero MRP is a valid one, so
      -- this asserts a property of the default rather than checking runtime input.
      pragma Assert (Validate_Config (Sigma_Rn => Sigma_Rn_C));
      Self.Alg := Create (Sigma_Rn => Sigma_Rn_C);
   end Init;

   not overriding procedure Destroy (Self : in out Instance) is
   begin
      -- Free the C++ heap data.
      Destroy (Self.Alg);
   end Destroy;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time and return the attitude reference it
   -- produces.
   overriding function Tick_T_Service (Self : in out Instance; Arg : in Tick.T) return Att_Ref.T is
      use Data_Product_Enums;
      use Data_Product_Enums.Data_Dependency_Status;

      -- Grab the commanded data dependency:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- The reference attitude is commanded sporadically, on entry into the state
      -- rather than every control cycle, so on most ticks it comes back Stale.
      -- Stale is a normal state here: the algorithm keeps the attitude it was last
      -- given. Success means a new attitude arrived this tick. Any other status
      -- indicates that this component is not wired up correctly, so we assert.
      Sigma : Packed_F32x3_Record.T;
      Sigma_Status : constant Data_Dependency_Status.E :=
         Self.Get_Sigma_Reference (Value => Sigma, Stale_Reference => Arg.Time);
      pragma Assert (Sigma_Status = Success or else Sigma_Status = Stale);
   begin
      -- A new attitude reconfigures the algorithm, which holds the reference
      -- attitude as configuration. The assembly maps this dependency with a stale
      -- limit equal to the tick period, so exactly one tick after a command sees
      -- Success and reconfigures the algorithm, and every later tick keeps the
      -- attitude while the product is Stale.
      if Sigma_Status = Success then
         declare
            Sigma_Rn_C : constant Packed_F32x3_Record.C.U_C := Packed_F32x3_Record.C.Unpack (Sigma);
         begin
            -- Set_Config throws on an invalid configuration. The attitude is published
            -- inside the flight software, which is required to publish a finite
            -- vector, so the algorithm's own predicate is asserted rather than checked.
            pragma Assert (Validate_Config (Sigma_Rn => Sigma_Rn_C));
            Set_Config (Self.Alg, Sigma_Rn => Sigma_Rn_C);
         end;
      end if;

      -- The algorithm holds the reference attitude as configuration and returns it
      -- unchanged, so Update takes no per-tick input. It produces the MRP alone; the
      -- reference rates are zero for a fixed inertial attitude, matching the C++
      -- adapter, which zero-initializes the payload and writes only sigma_RN.
      return Att_Ref.Pack ((
         Sigma_Rn => Packed_F32x3.C.To_Ada (Update (Self.Alg).Value),
         Omega_Rn_N => [others => 0.0],
         Domega_Rn_N => [others => 0.0]
      ));
   end Tick_T_Service;

   -----------------------------------------------
   -- Data dependency handlers:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Inertial 3D component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Inertial_3d.Implementation;
