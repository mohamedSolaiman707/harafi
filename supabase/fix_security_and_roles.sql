-- ==============================================================================
-- Harafy Production Security Fixes Migration
-- Run this in your Supabase SQL Editor to resolve relation "public.user_roles" error
-- ==============================================================================

-- 1. Create user_roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'tech', 'client')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Allow public read access to user_roles
CREATE POLICY "Allow read user_roles" ON public.user_roles
    FOR SELECT TO public
    USING (true);

-- 2. Helper function is_admin() (Supports both user_roles table & admin email fallback)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN (
    EXISTS (
      SELECT 1 FROM public.user_roles 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
    OR
    (
      auth.role() = 'authenticated' 
      AND (
        auth.jwt() ->> 'email' IN ('mohamedsolaiman707@gmail.com', 'admin@harafi.com', 'admin@example.com')
        OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
      )
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Public Technician Safe View (Hides PII, ID docs, criminal records, wallet, earnings, notes)
CREATE OR REPLACE VIEW public.technicians_public AS
SELECT 
    id,
    name,
    spec,
    area,
    rating,
    total_jobs,
    photo_url,
    bio,
    is_verified,
    visit_price,
    price_range,
    portfolio_images,
    status,
    created_at
FROM public.technicians;

-- Grant select permission on public view
GRANT SELECT ON public.technicians_public TO anon, authenticated;

-- 4. Atomic Order Claim Function (Fixes Race Condition SEC-06)
CREATE OR REPLACE FUNCTION public.claim_order(
    p_order_id UUID,
    p_tech_id UUID
)
RETURNS boolean AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE public.orders
    SET tech_id = p_tech_id,
        status = 'مُعيّن',
        updated_at = NOW()
    WHERE id = p_order_id
      AND (status = 'قيد الانتظار' OR status = 'pending' OR tech_id IS NULL);
      
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated > 0 THEN
        INSERT INTO public.order_logs (order_id, status, message)
        VALUES (p_order_id, 'مُعيّن', 'تم تعيين فني للطلب بنجاح');
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Safe Order Cancellation Function (Enforces valid cancellation state SEC-07)
CREATE OR REPLACE FUNCTION public.cancel_order_safe(
    p_order_id UUID,
    p_tracking_code TEXT,
    p_reason TEXT DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    v_current_status TEXT;
    v_rows_updated INT;
BEGIN
    SELECT status INTO v_current_status 
    FROM public.orders 
    WHERE id = p_order_id AND tracking_code = p_tracking_code;

    IF v_current_status IS NULL THEN
        RAISE EXCEPTION 'الطلب غير موجود';
    END IF;

    IF v_current_status IN ('مكتمل', 'completed', 'ملغي', 'cancelled') THEN
        RAISE EXCEPTION 'لا يمكن إلغاء الطلب بعد إتمامه أو إلغائه بالفعل';
    END IF;

    UPDATE public.orders
    SET status = 'ملغي',
        updated_at = NOW()
    WHERE id = p_order_id AND tracking_code = p_tracking_code;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated > 0 THEN
        INSERT INTO public.order_logs (order_id, status, message)
        VALUES (p_order_id, 'ملغي', COALESCE(p_reason, 'تم إلغاء الطلب من قبل العميل'));
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
