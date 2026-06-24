--------------------------------------------------------------------------------
-- Average_Mimu_Data Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Mimu_Raw_Packet;
with Tick;
with Parameter_Update;
with Packed_F32x3.C;
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

   -- Maximum number of packets to buffer between ticks (matches the C ring size):
   Max_Buffered_Packets : constant := Average_Mimu_Data_Algorithm_C.Max_Mimu_Pkt;

   -- Number of raw samples per packet (matches the C per-packet sample count):
   Samples_Per_Packet : constant := Average_Mimu_Data_Algorithm_C.Max_Mimu_Samples_Per_Pkt;

   -- ICD conversion factors (mission-stable, not parameterized):
   -- gyro [rad/s/count] = 4000 / 2^31-1 * pi/180
   Gyro_Scale : constant Short_Float := 3.2513631e-08;
   -- accel [m/s^2/count] = 160 / 2^31-1
   Accel_Scale : constant Short_Float := 7.4505806e-08;

   -- Pre-converted sample data for a single packet (10 samples deep):
   type Packet_Vector3f_Array is array (0 .. Samples_Per_Packet - 1) of Packed_F32x3.C.U_C;

   type Converted_Packet_Data is record
      -- First-sample time of the packet [ns]; per-sample times are derived
      -- inside the algorithm from this plus the device sample period.
      Meas_Time : Interfaces.Unsigned_64;
      Gyro_P    : Packet_Vector3f_Array;
      Accel_P   : Packet_Vector3f_Array;
   end record;

   type Converted_Buffer_Array is array (0 .. Max_Buffered_Packets - 1) of Converted_Packet_Data;

   -- The component class instance record:
   type Instance is new Average_Mimu_Data.Base_Instance with record
      Alg : Average_Mimu_Data_Algorithm_Access := null;
      -- Pre-converted sample buffer, populated on recv, consumed on tick:
      Buffer : Converted_Buffer_Array := [others => (
         Meas_Time => 0,
         Gyro_P    => [others => [others => 0.0]],
         Accel_P   => [others => [others => 0.0]]
      )];
      -- Number of packets currently stored (0 .. Max_Buffered_Packets):
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
   overriding procedure Invalid_Parameter (Self : in out Instance; Par : in Parameter.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type);
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
      Time_Delta : in Packed_F32.U;
      Dcm_Pltf_To_Bdy : in Packed_F32x9.U
   ) return Parameter_Validation_Status.E is (Parameter_Validation_Status.Valid);

end Component.Average_Mimu_Data.Implementation;
