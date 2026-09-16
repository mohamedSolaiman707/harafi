-- ====================================================
-- إصلاح نظام المحادثات المباشرة (order_messages)
-- شغّل هذا الكود في Supabase → SQL Editor
-- ====================================================

-- 1. إنشاء الجدول لو مش موجود
CREATE TABLE IF NOT EXISTS public.order_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id text NOT NULL,
    sender_type text NOT NULL CHECK (sender_type IN ('client', 'tech', 'admin')),
    sender_name text NOT NULL,
    message text NOT NULL,
    audio_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2. تفعيل Row Level Security
ALTER TABLE public.order_messages ENABLE ROW LEVEL SECURITY;

-- 3. حذف أي Policies قديمة وإنشاء واحدة تسمح بكل العمليات
DROP POLICY IF EXISTS "Allow all access to order_messages" ON public.order_messages;
CREATE POLICY "Allow all access to order_messages"
    ON public.order_messages
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- 4. تفعيل Realtime على الجدول (مهم جداً للبث الفوري)
ALTER PUBLICATION supabase_realtime ADD TABLE public.order_messages;

-- 5. إنشاء Index لتسريع الاستعلام على order_id
CREATE INDEX IF NOT EXISTS idx_order_messages_order_id
    ON public.order_messages (order_id, created_at ASC);

-- 6. اختبار: تحقق من وجود الجدول والـ Policies
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'order_messages';
