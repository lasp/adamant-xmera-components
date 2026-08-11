--------------------------------------------------------------------------------
-- Body_Rate_Miscompare Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Tick;
with Body_Rate_Miscompare_Algorithm_C; use Body_Rate_Miscompare_Algorithm_C;

-- Compares IMU and star tracker body rates and falls back to IMU solution if they
-- disagree.
package Component.Body_Rate_Miscompare.Implementation is

   -- The component class instance record:
   type Instance is new Body_Rate_Miscompare.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the body rate miscompare algorithm.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Body_Rate_Miscompare.Base_Instance with record
      Alg : Body_Rate_Miscompare_Algorithm_Access := null;
      -- Whether the fault flag was set on the previous tick, used to detect
      -- latch/clear transitions.
      Prev_Fault_Latched : Boolean := False;
      -- folded into the config alongside the threshold/persistence parameters.
      Use_Imu_Rates : Boolean := False;
   end record;

   ---------------------------------------
   -- Set Up Procedure
   ---------------------------------------
   -- Null method which can be implemented to provide some component
   -- set up code. This method is generally called by the assembly
   -- main.adb after all component initialization and tasks have been started.
   -- Some activities need to only be run once at startup, but cannot be run
   -- safely until everything is up and running, ie. command registration, initial
   -- data product updates. This procedure should be implemented to do these things
   -- if necessary.
   overriding procedure Set_Up (Self : in out Instance) is null;

   ---------------------------------------
   -- Invokee connector primitives:
   ---------------------------------------
   -- Run the algorithm up to the current time.
   overriding procedure Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- The parameter update connector.
   overriding procedure Parameter_Update_T_Modify (Self : in out Instance; Arg : in out Parameter_Update.T);
   -- Reset the algorithm's fault persistence state. Called on GNC state change.
   overriding procedure Reset_Tick_T_Recv_Sync (Self : in out Instance; Arg : in Tick.T);
   -- This is the command receive connector.
   overriding procedure Command_T_Recv_Sync (Self : in out Instance; Arg : in Command.T);

   ---------------------------------------
   -- Invoker connector primitives:
   ---------------------------------------
   -- This procedure is called when a Data_Product_T_Send message is dropped due to a full queue.
   overriding procedure Data_Product_T_Send_Dropped (Self : in out Instance; Arg : in Data_Product.T) is null;
   -- This procedure is called when a Command_Response_T_Send message is dropped due to a full queue.
   overriding procedure Command_Response_T_Send_Dropped (Self : in out Instance; Arg : in Command_Response.T) is null;
   -- This procedure is called when a Event_T_Send message is dropped due to a full queue.
   overriding procedure Event_T_Send_Dropped (Self : in out Instance; Arg : in Event.T) is null;

   -----------------------------------------------
   -- Command handler primitives:
   -----------------------------------------------
   -- Description:
   --    Commands for the Body Rate Miscompare component.
   -- Force the algorithm to always output IMU rates (Value => True) or resume normal
   -- miscompare logic (Value => False). Drives the algorithm's setUseImuRates, which
   -- also clears a latched fault when set False.
   overriding function Use_Imu_Rates (Self : in out Instance; Arg : in Packed_Boolean.T) return Command_Execution_Status.E;

   -- Invalid command handler. This procedure is called when a command's arguments are found to be invalid:
   overriding procedure Invalid_Command (Self : in out Instance; Cmd : in Command.T; Errant_Field_Number : in Unsigned_32; Errant_Field : in Basic_Types.Poly_Type);

   -----------------------------------------------
   -- Parameter primitives:
   -----------------------------------------------
   -- Description:
   --    Parameters for the Body Rate Miscompare component

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
      Body_Rate_Threshold : in Packed_F32.U;
      Fault_Persistence_Limit : in Packed_U32.U
   ) return Parameter_Validation_Status.E is (Parameter_Validation_Status.Valid);

   -----------------------------------------------
   -- Data dependency primitives:
   -----------------------------------------------
   -- Description:
   --    Data dependencies for the Body Rate Miscompare component.
   -- Function which retrieves a data dependency.
   -- The default implementation is to simply call the Data_Product_Fetch_T_Request connector. Change the implementation if this component
   -- needs to do something different.
   overriding function Get_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id) return Data_Product_Return.T is (Self.Data_Product_Fetch_T_Request ((Id => Id)));

   -- Invalid data dependency handler. This procedure is called when a data dependency's id or length are found to be invalid:
   overriding procedure Invalid_Data_Dependency (Self : in out Instance; Id : in Data_Product_Types.Data_Product_Id; Ret : in Data_Product_Return.T);

end Component.Body_Rate_Miscompare.Implementation;
