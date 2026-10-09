--------------------------------------------------------------------------------
-- Inertial_3d Component Implementation Spec
--------------------------------------------------------------------------------

-- Includes:
with Att_Ref;
with Tick;
with Packed_F32x3_Record;
with Inertial_3d_Algorithm_C; use Inertial_3d_Algorithm_C;

-- Inertial 3D algorithm produces a fixed inertial attitude reference message. The
-- algorithm holds the reference attitude as configuration and returns it
-- unchanged on every tick. The attitude arrives through a connector from the
-- component that commands the inertial-hold state, and reconfigures the algorithm
-- on receipt.
package Component.Inertial_3d.Implementation is

   -- The component class instance record:
   type Instance is new Inertial_3d.Base_Instance with private;

   --------------------------------------------------
   -- Subprogram for implementation init method:
   --------------------------------------------------
   -- Initializes the inertial 3D algorithm instance.
   overriding procedure Init (Self : in out Instance);
   not overriding procedure Destroy (Self : in out Instance);

private

   -- The component class instance record:
   type Instance is new Inertial_3d.Base_Instance with record
      Alg : Inertial_3d_Algorithm_Access := null;
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
   -- Run the algorithm up to the current time and return the attitude reference it
   -- produces.
   overriding function Tick_T_Service (Self : in out Instance; Arg : in Tick.T) return Att_Ref.T;
   -- Set the inertial attitude the reference holds, as the MRP from the inertial
   -- frame N to the reference frame R. The sender is required to send a finite
   -- vector, and a new attitude reconfigures the algorithm on receipt.
   overriding procedure Attitude_T_Recv_Sync (Self : in out Instance; Arg : in Packed_F32x3_Record.T);

end Component.Inertial_3d.Implementation;
