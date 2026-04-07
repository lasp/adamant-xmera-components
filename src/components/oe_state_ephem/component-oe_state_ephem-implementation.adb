--------------------------------------------------------------------------------
-- Oe_State_Ephem Component Implementation Body
--------------------------------------------------------------------------------

with Interfaces.C;
with Tdb_Vehicle_Clock_Correlation;
with Cartesian_State.C;

package body Component.Oe_State_Ephem.Implementation is

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the OE state ephemeris algorithm.
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

      -- Grab data dependencies:
      --
      -- Data_Dependency_Status.E can be Success, Not_Available, Error, or Stale.
      -- All return values besides Success indicate that this component is not
      -- wired up correctly in the algorithm execution order and received errant,
      -- stale, or no data. This should never happen, so we assert.
      Clock_Corr : Tdb_Vehicle_Clock_Correlation.T;
      Clock_Corr_Status : constant Data_Dependency_Status.E :=
         Self.Get_Clock_Correlation (Value => Clock_Corr, Stale_Reference => Arg.Time);
      pragma Assert (Clock_Corr_Status = Success);
   begin
      -- Update the parameters:
      Self.Update_Parameters;

      declare
         -- Unpack clock correlation to access fields:
         Clock_Corr_U : constant Tdb_Vehicle_Clock_Correlation.U :=
            Tdb_Vehicle_Clock_Correlation.Unpack (Clock_Corr);

         -- Convert Sys_Time to nanoseconds for the algorithm callTime:
         -- Subseconds field is in units of 1/(2^16) seconds.
         Call_Time_Ns : constant Interfaces.Unsigned_64 :=
            Interfaces.Unsigned_64 (Arg.Time.Seconds) * 1_000_000_000 +
            (Interfaces.Unsigned_64 (Arg.Time.Subseconds) * 1_000_000_000) / 65_536;
      begin
         -- Set ephemeris time and vehicle time offset from clock correlation:
         Set_Ephemeris_Time_J2000 (
            Self.Alg,
            Interfaces.C.double (Clock_Corr_U.Ephemeris_Time)
         );
         Set_Vehicle_Time_Offset (
            Self.Alg,
            Interfaces.C.double (Clock_Corr_U.Vehicle_Clock_Time)
         );

         -- Call algorithm update:
         declare
            Result : constant Cartesian_State.C.U_C := Update (Self.Alg, Call_Time_Ns);
         begin
            -- Send out data product:
            Self.Data_Product_T_Send (Self.Data_Products.Ephemeris_State (
               Arg.Time,
               Cartesian_State.Pack (Cartesian_State.C.To_Ada (Result))
            ));
         end;
      end;
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
   -- Apply updated parameters to the C++ algorithm.
   overriding procedure Update_Parameters_Action (Self : in out Instance) is
   begin
      -- Set gravitational parameter when parameters update:
      Set_Central_Body_Gravitational_Parameter (
         Self.Alg,
         Interfaces.C.double (Self.Central_Body_Mu.Value)
      );
   end Update_Parameters_Action;

   -- Description:
   --    Parameters for the OE State Ephem component
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
   --    Data dependencies for the OE State Ephem component.
   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T) is
      pragma Annotate (GNATSAS, Intentional, "subp always fails", "intentional assertion");
   begin
      -- None of the data dependencies should be invalid in this case.
      pragma Assert (False);
   end Invalid_Data_Dependency;

end Component.Oe_State_Ephem.Implementation;
