pragma Ada_2012;

pragma Style_Checks (Off);
pragma Warnings     (Off, "-gnatwu");

with Interfaces.C;         use Interfaces; use Interfaces.C;
with Att_Ref.C;
with Nav_Att.C;
with Att_Guid.C;
with Packed_F32x3_Record.C;

package Att_Tracking_Error_Algorithm_C is

   -- ISC License
   -- *
   -- * Copyright (c) 2025, Laboratory for Atmospheric and Space Physics,
   -- * University of Colorado at Boulder
   -- *
   -- * Permission to use, copy, modify, and/or distribute this software
   -- * for any purpose with or without fee is hereby granted, provided
   -- * that the above copyright notice and this permission notice appear
   -- * in all copies.
   -- *
   -- * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
   -- * WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
   -- * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
   -- * AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
   -- * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
   -- * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
   -- * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
   -- * WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
   --

   --* Opaque handle for an AttTrackingErrorAlgorithm instance.
   type Att_Tracking_Error_Algorithm is limited private;
   type Att_Tracking_Error_Algorithm_Access is access all Att_Tracking_Error_Algorithm;

   --* @brief Construct a new AttTrackingErrorAlgorithm.
   function Create
     return Att_Tracking_Error_Algorithm_Access
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_create";

   --* @brief Destroy an AttTrackingErrorAlgorithm.
   procedure Destroy
     (Self : Att_Tracking_Error_Algorithm_Access)
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_destroy";

   --* @brief Run the update step of the attitude tracking error algorithm.
   --* @param Self              The algorithm instance.
   --* @param Current_Sim_Nanos Current simulation time (ns).
   --* @param Att_Ref_In        Pointer to reference-frame message payload.
   --* @param Att_Nav_In        Pointer to navigation attitude message payload.
   --* @return Computed guidance message payload.
   function Update
     (Self               : Att_Tracking_Error_Algorithm_Access;
      Current_Sim_Nanos  : Unsigned_64;
      Att_Ref_In         : Att_Ref.C.U_C_Access;
      Att_Nav_In         : Nav_Att.C.U_C_Access)
     return Att_Guid.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_update";

   --* @brief Set the σ_R0R three-vector.
   procedure Set_Sigma_R0R
     (Self      : Att_Tracking_Error_Algorithm_Access;
      Sigma_R0R : Packed_F32x3_Record.C.U_C)
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_setSigma_R0R";

   --* @brief Get the current σ_R0R three-vector.
   function Get_Sigma_R0R
     (Self : Att_Tracking_Error_Algorithm_Access)
     return Packed_F32x3_Record.C.U_C
     with Import       => True,
          Convention   => C,
          External_Name => "AttTrackingErrorAlgorithm_getSigma_R0R";

private

   -- Private representation: opaque null record
   type Att_Tracking_Error_Algorithm is null record;

end Att_Tracking_Error_Algorithm_C;

pragma Style_Checks (On);
pragma Warnings     (On, "-gnatwu");
