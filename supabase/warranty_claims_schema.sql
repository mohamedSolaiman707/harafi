-- Phase 2.2: Warranty Claims Table Schema
CREATE TABLE IF NOT EXISTS public.warranty_claims (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id text NOT NULL,
    tracking_code text NOT NULL,
    client_name text NOT NULL,
    client_phone text NOT NULL,
    tech_id text,
    issue_description text NOT NULL,
    claim_images jsonb DEFAULT '[]'::jsonb,
    status text DEFAULT 'pending',
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone
);

ALTER TABLE public.warranty_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to warranty_claims" ON public.warranty_claims FOR ALL USING (true);
