with Ada.Numerics;

-- Scalar types for the solar array reference angles. The range is the one the
-- solarArrayReference algorithm accepts, in Short_Float, so a value of this type
-- is valid to the algorithm by construction.
package Solar_Array_Reference_Types is

   -- [rad] A solar array angle in [-pi, pi]. The bounds are the same values the
   -- C++ algorithm checks against: pi rounded to the nearest Short_Float, which
   -- lies just above pi.
   subtype Array_Angle is Short_Float range -Short_Float (Ada.Numerics.Pi) .. Short_Float (Ada.Numerics.Pi);

end Solar_Array_Reference_Types;
