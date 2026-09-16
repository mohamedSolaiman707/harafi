-- Phase 2.1: Promo Codes Schema and Order Discount Columns
CREATE TABLE IF NOT EXISTS public.promo_codes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    code text UNIQUE NOT NULL,
    discount_percentage integer DEFAULT 0,
    discount_amount integer DEFAULT 0,
    max_uses integer DEFAULT 100,
    current_uses integer DEFAULT 0,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to promo_codes" ON public.promo_codes FOR ALL USING (true);

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS promo_code text,
ADD COLUMN IF NOT EXISTS discount_amount integer DEFAULT 0;
