--------------------------------------------------------------------------------
-- Average_Mimu_Data Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Mimu_Raw_Packet;
with Tick;
with Parameter_Update;
with Mimu_Input_Packet_X4;
with Mimu_Input_Packets.C;
with Average_Mimu_Data_Algorithm_C; use Average_Mimu_Data_Algorithm_C;

-- Averages MIMU accelerometer and gyro data within a configurable time window and
-- transforms to the spacecraft body frame.
package Component.Average_Mimu_Data.Implementation is

   -- The component class instance record:
   type Instance is new Average_Mimu_Data.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the AverageMimuData algorithm.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- Maximum number of packets to buffer between ticks (the FFI packet ring
   -- size, validated against the C constant at elaboration in the binding):
   Max_Buffered_Packets : constant Natural := Mimu_Input_Packet_X4.Length;

   -- ICD conversion factors (mission-stable, not parameterized):
   -- gyro [rad/s/count] = 4000 / 2^31-1 * pi/180
   Gyro_Scale : constant Short_Float := 3.2513631e-08;
   -- accel [m/s^2/count] = 160 / 2^31-1
   Accel_Scale : constant Short_Float := 7.4505806e-08;

   -- The component class instance record:
   type Instance is new Average_Mimu_Data.Base_Instance with record
      Alg : Average_Mimu_Data_Algorithm_Access := null;
      -- Algorithm input, staged in place: samples are converted directly
      -- into this structure on receive and consumed on tick. Packets with
      -- Is_Valid = 0 are skipped by the algorithm.
      Input : aliased Mimu_Input_Packets.C.U_C := (
         Packets => [others => (
            Is_Valid  => 0,
            Meas_Time => 0,
            Samples   => [others => (
               Gyro_P  => [others => 0.0],
               Accel_P => [others => 0.0]
            )]
         )]
      );
      -- Number of packets currently staged (0 .. Max_Buffered_Packets):
      Packet_Count : Natural := 0;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   -- Null method which can be implemented to provide some component
   -- set up code. This method is generally called by the assembly
   -- main.adb after all component initialization and tasks have been started.
   -- Some activities need to only be run once at startup, but cannot be run
   -- safely until everything is up and running, i.e. command registration, initial
   -- data product updates. This procedure should be implemented to do these things
   -- if necessary.
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Receive raw MIMU data packet and buffer for later processing.
   overriding procedure Mimu_Raw_Packet_T_Recv_Sync (Self : in out Instance; Arg : in Mimu_Raw_Packet.T);
   -- Tick that triggers the averaging algorithm over buffered samples and publishes
   -- the result.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Event_T_Send message is dropped due to a full queue.
   overriding procedure Event_T_Send_Dropped (Self : in out Instance; Arg : in Event.T) is null;
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Average Mimu Data component

   -- Invalid parameter handler. This procedure is called when a parameter's type is found to be invalid:
   -- Null: the staging code rejects the value and returns an error status to the Parameters
   -- component, which reports the offending parameter ID to the ground. That is sufficient, and
   -- we avoid adding per-component event overhead to these algorithm components.
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type) is null;
   -- This procedure is called when the parameters of a component have been updated. The default implementation of this
   -- subprogram in the implementation package is a null procedure. However, this procedure can, and should be implemented if
   -- something special needs to happen after a parameter update. Examples of this might be copying certain parameters to
   -- hardware registers, or performing other special functionality that only needs to be performed after parameters have
   -- been updated.
   overriding procedure Update_Parameters_Action (Self : in out Instance);
   -- This function is called when the parameter operation type is "Validate". The default implementation of this
   -- subprogram in the implementation package is a function that returns "Valid". However, this function can, and should be
   -- overridden if something special needs to happen to further validate a parameter. Examples of this might be validation of
   -- certain parameters beyond individual type ranges, or performing other special functionality that only needs to be
   -- performed after parameters have been validated. Note that range checking is performed during staging, and does not need
   -- to be implemented here.
   overriding function Validate_Parameters (
      Self : in out Instance;
      Gyro_Time_Delta : in Packed_F32.U;
      Accel_Time_Delta : in Packed_F32.U;
      Dcm_Pltf_To_Bdy : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E;

end Component.Average_Mimu_Data.Implementation;
