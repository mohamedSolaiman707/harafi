import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type FollowUpAnswer = { question: string; answer: string };

type AnalyzeRequest = {
  description?: string;
  answers?: FollowUpAnswer[];
  image_base64?: string;
  image_name?: string;
};

type Diagnosis = {
  analysisSource: "openai" | "fallback";
  detectedCategory: string;
  categoryNameAr: string;
  confidence: number;
  confidenceLevel: "low" | "medium" | "high";
  problemSummary: string;
  possibleIssue: string;
  secondaryIssue?: string | null;
  recommendedAction: string;
  diyTip?: string | null;
  estimatedPartsCost?: string | null;
  needsTechnician: boolean;
  urgency: "low" | "normal" | "high";
  safetyLevel: "low" | "medium" | "high";
  safetyNotes: string[];
  followUpQuestions: string[];
};

const allowedCategories = [
  "electricity",
  "plumbing",
  "air_conditioning",
  "carpentry",
  "washing_machine",
  "refrigerator",
  "stove",
  "tv",
] as const;

const categoryLabels: Record<string, string> = {
  electricity: "كهرباء",
  plumbing: "سباكة",
  air_conditioning: "تكييفات",
  carpentry: "نجارة",
  washing_machine: "غسالات",
  refrigerator: "ثلاجات",
  stove: "بوتاجازات",
  tv: "شاشات",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

function normalize(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replaceAll("أ", "ا")
    .replaceAll("إ", "ا")
    .replaceAll("آ", "ا")
    .replaceAll("ة", "ه")
    .replaceAll("ى", "ي");
}

function confidenceLevelFromScore(score: number): "low" | "medium" | "high" {
  if (score >= 0.8) return "high";
  if (score >= 0.55) return "medium";
  return "low";
}

function safetyLevelFromText(text: string): "low" | "medium" | "high" {
  const normalized = normalize(text);
  const unsafeTerms = ["غاز", "كهرب", "شرر", "حريق", "ريحة غاز", "صعق"];
  if (unsafeTerms.some((term) => normalized.includes(normalize(term)))) {
    return "high";
  }
  if (normalized.includes("تسريب") || normalized.includes("سخن")) return "medium";
  return "low";
}

async function analyzeWithOpenAI(request: AnalyzeRequest): Promise<Diagnosis> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is missing");
  }

  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

  const systemPrompt = `
أنت مهندس صيانة خبير ومستشار أعطال منزلية في مصر لـ منصة حرفي.
وظيفتك تقديم تشخيص فني ذكي جداً وعميق يعطي قيمة حقيقية فائقة للعميل.

قواعد التشخيص:
1. التخصصات المسموح بها: ${allowedCategories.join(", ")}.
2. اذكر اسم العطل الميكانيكي أو الكهربائي بدقة (مثل: طلمبة طرد، مكثف كباش، حاساس ديفروست، صمام مية، جلبة، كارتة، شورت مفتاح).
3. أضف حقل "diyTip": نصيحة بسيطة وعملية مجانية يمكن للعميل تجربتها بنفسه الآن فوراً قد تحل المشكلة (مثل تنظيف مصفاة أو ريست للتكييف).
4. أضف حقل "estimatedPartsCost": تقدير متوسط سعر قطعة الغيار الأصلي في السوق المصري بالجنيه (مثال: من 180 إلى 250 ج.م).

يجب إعادة النتيجة بتنسيق JSON صالح يحتوي الحقول التالية فقط:
{
  "detectedCategory": "washing_machine",
  "categoryNameAr": "غسالات",
  "confidence": 0.95,
  "confidenceLevel": "high",
  "problemSummary": "ملخص العطل",
  "possibleIssue": "السبب المباشر واسم القطعة التالفة والشرح الميكانيكي",
  "secondaryIssue": "احتمال ثانوي متداخل إن وجد",
  "recommendedAction": "التوصية والإجراء الموصى به",
  "diyTip": "نصيحة افعلها بنفسك مجاناً الآن",
  "estimatedPartsCost": "تقدير أسعار قطع الغيار بالجنيه المصري",
  "needsTechnician": true,
  "urgency": "normal",
  "safetyLevel": "low",
  "safetyNotes": ["ملاحظة أمان 1"],
  "followUpQuestions": ["سؤال استيضاحي 1"]
}
`;

  const userMessages: Array<Record<string, unknown>> = [
    {
      role: "system",
      content: systemPrompt,
    },
    {
      role: "user",
      content: [
        { type: "text", text: `وصف العميل للعطل: ${request.description || "غير متوفر"}` },
        ...(request.image_base64
          ? [
              {
                type: "image_url",
                image_url: {
                  url: `data:image/${request.image_name?.split(".").pop() ?? "jpeg"};base64,${request.image_base64}`,
                },
              },
            ]
          : []),
      ],
    },
  ];

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: userMessages,
      response_format: { type: "json_object" },
      temperature: 0.3,
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenAI request failed with status ${response.status}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("OpenAI response did not include content");
  }

  const parsed = JSON.parse(content);
  const confidence = Number(parsed.confidence ?? 0.85);
  const safetyText = `${parsed.possibleIssue ?? ""} ${parsed.recommendedAction ?? ""} ${request.description ?? ""}`;

  return {
    analysisSource: "openai",
    detectedCategory: String(parsed.detectedCategory ?? "electricity"),
    categoryNameAr: String(parsed.categoryNameAr ?? categoryLabels[parsed.detectedCategory] ?? "فني متخصص"),
    confidence,
    confidenceLevel: ["low", "medium", "high"].includes(String(parsed.confidenceLevel))
      ? parsed.confidenceLevel
      : confidenceLevelFromScore(confidence),
    problemSummary: String(parsed.problemSummary ?? request.description ?? ""),
    possibleIssue: String(parsed.possibleIssue ?? ""),
    secondaryIssue: parsed.secondaryIssue ? String(parsed.secondaryIssue) : null,
    recommendedAction: String(parsed.recommendedAction ?? ""),
    diyTip: parsed.diyTip ? String(parsed.diyTip) : null,
    estimatedPartsCost: parsed.estimatedPartsCost ? String(parsed.estimatedPartsCost) : null,
    needsTechnician: Boolean(parsed.needsTechnician ?? true),
    urgency: parsed.urgency === "high" || parsed.urgency === "low" ? parsed.urgency : "normal",
    safetyLevel: ["low", "medium", "high"].includes(String(parsed.safetyLevel))
      ? parsed.safetyLevel
      : safetyLevelFromText(safetyText),
    safetyNotes: Array.isArray(parsed.safetyNotes) ? parsed.safetyNotes.map((item: unknown) => String(item)) : [],
    followUpQuestions: Array.isArray(parsed.followUpQuestions)
      ? parsed.followUpQuestions.map((item: unknown) => String(item))
      : [],
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body = (await req.json()) as AnalyzeRequest;
    const diagnosis = await analyzeWithOpenAI(body);
    return jsonResponse(diagnosis);
  } catch (error) {
    return jsonResponse(
      {
        error: "Failed to analyze problem",
        details: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
