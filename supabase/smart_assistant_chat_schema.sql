-- ─── Smart Assistant SQL Migration ──────────────────────────────────────────────
-- Phase 1: Chat Sessions, Message Persistence, Knowledge Base & RLS Policies

-- 1. Create chat_sessions table
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast user session lookups
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user ON public.chat_sessions(user_id, last_message_at DESC);

-- Enable RLS on chat_sessions
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chat_sessions
CREATE POLICY "Users can view their own chat sessions"
    ON public.chat_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own chat sessions"
    ON public.chat_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own chat sessions"
    ON public.chat_sessions FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own chat sessions"
    ON public.chat_sessions FOR DELETE
    USING (auth.uid() = user_id);


-- 2. Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
    content TEXT NOT NULL,
    image_url TEXT,
    intent TEXT,
    diagnosis JSONB,
    emergency_steps TEXT[],
    quick_replies TEXT[],
    contact_phone TEXT,
    feedback SMALLINT CHECK (feedback IN (-1, 1)),
    tokens INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for message retrieval inside sessions
CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON public.chat_messages(session_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_intent ON public.chat_messages(intent, created_at DESC);

-- Enable RLS on chat_messages
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chat_messages
CREATE POLICY "Users can view their session messages"
    ON public.chat_messages FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert messages into their sessions"
    ON public.chat_messages FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own message feedback"
    ON public.chat_messages FOR UPDATE
    USING (auth.uid() = user_id);


-- 3. Create knowledge_base table
CREATE TABLE IF NOT EXISTS public.knowledge_base (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category TEXT NOT NULL, -- pricing | faq | safety | policy | troubleshooting
    question TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT[],
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on knowledge_base (Public read access)
ALTER TABLE public.knowledge_base ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access on knowledge_base"
    ON public.knowledge_base FOR SELECT
    USING (true);

-- Insert Initial Knowledge Base entries for common Egyptian handyman queries
INSERT INTO public.knowledge_base (category, question, content, tags) VALUES
('pricing', 'ما هي أسعار زيارة السباكة في مصر؟', 'كشف السباكة ومعاينة الأعطال البسيطة يبدأ من 80 إلى 150 ج.م، وتغيير الخلاطات من 150 إلى 250 ج.م مع ضمان الصيانة.', ARRAY['سباكة', 'أسعار', 'كشف']),
('pricing', 'كم تكلفة صيانة وتعبئة فريون التكييف؟', 'تكلفة شحن الفريون (نوع R22 أو R410a) تتراوح بين 400 إلى 850 ج.م حسب القدرة الحصانية وحالة التسريب.', ARRAY['تكييف', 'فريون', 'أسعار']),
('safety', 'ماذا أفعل عند وجود رائحة غاز في المنزل؟', '1. أغلق المحبس الرئيسي فوراً. 2. لا تشعل أي نار ولا تضغط أي مفتاح كهرباء. 3. افتح النوافذ للتهوية. 4. غادر المكان واتصل بالطوارئ.', ARRAY['طوارئ', 'غاز', 'سلامة']),
('faq', 'هل توجد كفالة أو ضمان على الصيانة؟', 'نعم، يقدم تطبيق حرفي ضماناً معتمداً لمدة 30 يوماً على جميع خدمات الصيانة وقطع الغيار المشتراة عبر الفني.', ARRAY['ضمان', 'سياسة', 'حرفي'])
ON CONFLICT DO NOTHING;
