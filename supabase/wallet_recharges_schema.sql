-- ==============================================================================
-- Phase 1.3: Wallet Recharges Table & Automated Payment Extensions
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.wallet_recharges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tech_id text NOT NULL,
    tech_name text NOT NULL,
    tech_phone text NOT NULL,
    amount integer NOT NULL,
    sender_phone text NOT NULL,
    receipt_url text DEFAULT '',
    status text DEFAULT 'pending',
    payment_method text DEFAULT 'vodafone_cash',
    fawry_ref_code text,
    is_auto_processed boolean DEFAULT false,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now(),
    approved_at timestamp with time zone
);

-- Ensure Columns exist for existing deployments
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS tech_name text DEFAULT '';
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS tech_phone text DEFAULT '';
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS sender_phone text DEFAULT '';
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS receipt_url text DEFAULT '';
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS payment_method text DEFAULT 'vodafone_cash';
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS fawry_ref_code text;
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS is_auto_processed boolean DEFAULT false;
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS rejection_reason text;

ALTER TABLE public.wallet_recharges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to wallet_recharges" ON public.wallet_recharges;
CREATE POLICY "Allow all access to wallet_recharges" ON public.wallet_recharges FOR ALL USING (true);

-- ==============================================================================
-- Function: Auto Approve & Credit Technician Wallet (Used by Webhooks & SMS Listener)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.auto_process_wallet_recharge(
    p_recharge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_recharge record;
BEGIN
    SELECT * INTO v_recharge FROM public.wallet_recharges WHERE id = p_recharge_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'طلب الشحن غير موجود');
    END IF;
    
    IF v_recharge.status = 'approved' THEN
        RETURN jsonb_build_object('success', true, 'message', 'تم شحن هذا الطلب سابقاً');
    END IF;
    
    -- 1. Update Recharge Status
    UPDATE public.wallet_recharges
    SET status = 'approved',
        approved_at = now(),
        is_auto_processed = true
    WHERE id = p_recharge_id;
    
    -- 2. Credit Technician Wallet Balance
    UPDATE public.technicians
    SET wallet_balance = COALESCE(wallet_balance, 0) + v_recharge.amount
    WHERE id = v_recharge.tech_id;
    
    RETURN jsonb_build_object('success', true, 'message', 'تم شحن محفظة الفني أوتوماتيكياً بنجاح');
END;
$$;
