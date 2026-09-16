-- V1 schema for outcome tracking and future smart matching

CREATE TABLE public.job_outcomes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL UNIQUE,
  customer_id text,
  ai_detected_category text,
  ai_category_name_ar text,
  ai_confidence numeric,
  ai_problem_summary text,
  ai_possible_issue text,
  ai_recommended_action text,
  ai_safety_notes text[] DEFAULT '{}'::text[],
  ai_follow_up_questions text[] DEFAULT '{}'::text[],
  ai_analysis_source text DEFAULT 'openai',
  recommended_technician_id uuid,
  technician_actual_diagnosis text,
  repair_action_taken text,
  first_visit_fix boolean DEFAULT false,
  repeat_issue boolean DEFAULT false,
  warranty_claimed boolean DEFAULT false,
  customer_rating integer CHECK (customer_rating >= 1 AND customer_rating <= 5),
  customer_feedback text,
  resolution_time_minutes integer,
  parts_used text,
  final_cost bigint,
  inspection_fee integer DEFAULT 0,
  labor_fee integer DEFAULT 0,
  parts_fee integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT job_outcomes_pkey PRIMARY KEY (id),
  CONSTRAINT job_outcomes_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE,
  CONSTRAINT job_outcomes_recommended_technician_id_fkey FOREIGN KEY (recommended_technician_id) REFERENCES public.technicians(id)
);

CREATE INDEX job_outcomes_ai_detected_category_idx ON public.job_outcomes (ai_detected_category);
CREATE INDEX job_outcomes_recommended_technician_id_idx ON public.job_outcomes (recommended_technician_id);
CREATE INDEX job_outcomes_repeat_issue_idx ON public.job_outcomes (repeat_issue);
CREATE INDEX job_outcomes_warranty_claimed_idx ON public.job_outcomes (warranty_claimed);
CREATE INDEX job_outcomes_created_at_idx ON public.job_outcomes (created_at);

ALTER TABLE public.job_outcomes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access on job_outcomes"
ON public.job_outcomes FOR SELECT
TO public
USING (true);

CREATE POLICY "Allow authenticated write on job_outcomes"
ON public.job_outcomes FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated update on job_outcomes"
ON public.job_outcomes FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
