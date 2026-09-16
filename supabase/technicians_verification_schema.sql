-- Phase 1.2: Identity Verification Columns for Technicians
ALTER TABLE public.technicians
ADD COLUMN IF NOT EXISTS national_id_front_url text,
ADD COLUMN IF NOT EXISTS national_id_back_url text,
ADD COLUMN IF NOT EXISTS criminal_record_url text;
