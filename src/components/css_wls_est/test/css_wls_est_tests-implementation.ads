--------------------------------------------------------------------------------
-- Css_Wls_Est Tests Spec
--------------------------------------------------------------------------------

-- This is a unit test suite for the Css Wls Est component.
package Css_Wls_Est_Tests.Implementation is

   -- Test data and state:
   type Instance is new Css_Wls_Est_Tests.Base_Instance with private;
   type Class_Access is access all Instance'Class;

private
   -- Fixture procedures:
   overriding procedure Set_Up_Test (Self : in out Instance);
   overriding procedure Tear_Down_Test (Self : in out Instance);

   -- Along each body axis the constellation is symmetric, so the fit returns the
   -- true heading exactly and every residual is zero. The weighted and unweighted
   -- fits must agree.
   overriding procedure Test_Nominal_Full_Coverage (Self : in out Instance);
   -- With only two lit sensors the fit is the exactly determined minimum norm
   -- solution, which bisects the two boresights.
   overriding procedure Test_Two_Sensor_Coverage (Self : in out Instance);
   -- With one lit sensor the fit can only report that sensor's boresight, a guess on
   -- the cone of possibilities.
   overriding procedure Test_Single_Sensor_Coverage (Self : in out Instance);
   -- With no reading above the threshold the component reports a zero heading rather
   -- than a stale or invented one.
   overriding procedure Test_No_Signal (Self : in out Instance);
   -- The first heading yields no rate. A ninety degree step over one tick period
   -- yields the corresponding rate about the orthogonal axis.
   overriding procedure Test_Rate_Estimate (Self : in out Instance);
   -- Raising the sensor use threshold from the ground drops the active sensor count,
   -- and the reconfiguration discards the prior heading so no rate is differenced
   -- across it.
   overriding procedure Test_Parameter_Update_Reconfigures (Self : in out Instance);
   -- A non-unit boresight, a negative bias and an out of range threshold are each
   -- rejected before they can reach the throwing configuration entry points.
   overriding procedure Test_Invalid_Parameter (Self : in out Instance);

   -- Test data and state:
   type Instance is new Css_Wls_Est_Tests.Base_Instance with record
      null;
   end record;
end Css_Wls_Est_Tests.Implementation;
