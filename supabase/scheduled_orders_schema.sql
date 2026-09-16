-- Phase 3.1: Scheduled Orders Schema
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS is_scheduled boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS scheduled_date timestamp with time zone,
ADD COLUMN IF NOT EXISTS preferred_time_slot text;
