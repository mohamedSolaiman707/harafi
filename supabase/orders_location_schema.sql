-- ==============================================================================
-- Add GPS Location Columns to Orders Table (Client Home Pin & Live Tech Location)
-- ==============================================================================

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS client_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS client_lng double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tech_lat double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tech_lng double precision;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tech_location_updated_at timestamp with time zone;
