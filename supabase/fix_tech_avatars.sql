-- ==============================================================================
-- Migration: Fix Technician Avatars (Separation of ID Proof and Profile Photo)
-- ==============================================================================
-- Description: Resets photo_url (public avatar) to NULL for any technician 
-- whose photo_url is identical to their national_id_front_url or identity_proof_url.
-- This ensures that private ID cards do not appear as public profile avatars.
-- ==============================================================================

UPDATE public.technicians
SET photo_url = NULL
WHERE photo_url IS NOT NULL
  AND (
    photo_url = national_id_front_url 
    OR photo_url = identity_proof_url
  );
