import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SmartMatchRequest = {
  service?: string;
  area?: string;
  description?: string;
  diagnosis?: {
    detectedCategory?: string;
    categoryNameAr?: string;
    confidence?: number;
    problemSummary?: string;
    possibleIssue?: string;
    recommendedAction?: string;
    needsTechnician?: boolean;
    urgency?: "low" | "normal" | "high";
    safetyNotes?: string[];
  } | null;
};


type SmartMatchResponse = {
  analysisSource: "openai" | "heuristic";
  autoPickThreshold: number;
  topTechnicians: Array<{
    technicianId: string;
    name: string;
    score: number;
    reliabilityScore: number;
    reason: string;
    rating: number;
    totalJobs: number;
    area?: string | null;
    status?: string | null;
    matchedJobs: number;
    firstVisitRate: number;
    repeatRate: number;
  }>;
  recommendedTechnicianId: string | null;
  fallbackTechnicianIds: string[];
  reasoning: string;
};

type OpenAIRankResponse = {
  recommendedTechnicianId: string | null;
  reasoning: string;
  rankedTechnicians: Array<{
    technicianId: string;
    reason: string;
  }>;
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });

function normalize(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replaceAll("Ø£", "Ø§")
    .replaceAll("Ø¥", "Ø§")
    .replaceAll("Ø¢", "Ø§")
    .replaceAll("Ø©", "Ù‡")
    .replaceAll("Ù‰", "ÙŠ");
}

function buildKeywordScore(text: string, service: string) {
  const map: Record<string, string[]> = {
    plumbing: ["Ø³Ø¨Ø§Ùƒ", "Ù…ÙŠØ§Ù‡", "ØªØ³Ø±ÙŠØ¨", "Ø­Ù†ÙÙŠØ©", "Ù…Ø§Ø³ÙˆØ±Ø©", "ØµØ±Ù", "Ø§Ù†Ø³Ø¯Ø§Ø¯"],
    electrical: ["ÙƒÙ‡Ø±Ø¨", "ÙÙŠØ´Ø©", "Ù„Ù…Ø¨Ø©", "Ù…ÙØªØ§Ø­", "Ø³Ù„Ùƒ", "Ù„ÙˆØ­Ø©", "Ø´ÙˆØ±Øª"],
    carpentry: ["Ø¨Ø§Ø¨", "Ø´Ø¨Ùƒ", "Ø®Ø´Ø¨", "Ù†Ø¬Ø§Ø±", "Ø¯ÙˆÙ„Ø§Ø¨", "Ø³Ø±ÙŠØ±", "Ø¯Ø±Ø¬"],
    air_conditioning: ["ØªÙƒÙŠÙ", "ÙØ±ÙŠÙˆÙ†", "ØªØ¨Ø±ÙŠØ¯", "ÙƒÙ…Ø¨Ø±ÙˆØ³Ø±", "Ù…Ø±ÙˆØ­Ø©", "Ø³Ø¨Ù„Øª"],
    washing_machine: ["ØºØ³Ø§Ù„Ø©", "Ø¹ØµØ±", "ØµØ±Ù", "Ø·Ù„Ù…Ø¨Ø©", "Ù…ÙˆØªÙˆØ±"],
    refrigerator: ["Ø«Ù„Ø§Ø¬Ø©", "ÙØ±ÙŠØ²Ø±", "ØªØ¨Ø±ÙŠØ¯", "ØªØ±Ù…ÙˆØ³", "ØªØ±Ù…ÙˆØ³ØªØ§Øª"],
    stove: ["Ø¨ÙˆØªØ§Ø¬Ø§Ø²", "ØºØ§Ø²", "Ø´Ø¹Ù„Ø©", "ÙØ±Ù†", "Ø§Ø´Ø¹Ø§Ù„"],
    tv: ["Ø´Ø§Ø´Ø©", "Ø±Ø³ÙŠÙØ±", "ØµÙˆØ±Ø©", "ØµÙˆØª", "Ù„ÙŠØ¯", "Ø¨Ù„Ø§Ø²Ù…Ø§"],
  };
  return (map[service] ?? []).reduce((score, keyword) => score + (normalize(text).includes(normalize(keyword)) ? 1 : 0), 0);
}



async function rankWithOpenAI(request: SmartMatchRequest, candidates: SmartMatchResponse["topTechnicians"]) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey || candidates.length === 0) return null;

  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-5.6-sol";
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text: [
                "You are a technician ranking engine for home service requests in Egypt.",
                "Choose the best technician only from the provided candidate list.",
                "Use fit to the problem, area, rating, availability, historical outcomes, and first-visit fix rate.",
                "Return JSON only with no extra text.",
              ].join(" "),
            },
          ],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify({
                service: request.service,
                area: request.area,
                description: request.description,
                diagnosis: request.diagnosis,
                candidates,
              }),
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "harafi_smart_match",
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              recommendedTechnicianId: { type: ["string", "null"] },
              reasoning: { type: "string" },
              rankedTechnicians: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    technicianId: { type: "string" },
                    reason: { type: "string" },
                  },
                  required: ["technicianId", "reason"],
                },
              },
            },
            required: ["recommendedTechnicianId", "reasoning", "rankedTechnicians"],
          },
        },
      },
    }),
  });

  if (!response.ok) return null;
  const data = await response.json();
  const content = data.output_text ?? data.output?.[0]?.content?.[0]?.text ?? null;
  if (!content) return null;
  return JSON.parse(content) as OpenAIRankResponse;
}
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return jsonResponse({ ok: true });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Missing Supabase env vars" }, 500);
  }

  const client = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
  const body = (await req.json()) as SmartMatchRequest;
  const service = body.service ?? "";
  const area = body.area ?? "";
  const diagnosisText = [
    body.diagnosis?.categoryNameAr ?? "",
    body.diagnosis?.problemSummary ?? "",
    body.diagnosis?.possibleIssue ?? "",
    body.diagnosis?.recommendedAction ?? "",
    body.description ?? "",
  ].join(" ");

  const techsResponse = await client
    .from("technicians")
    .select("id,name,spec,rating,total_jobs,area,status,is_verified,visit_price,price_range,photo_url")
    .eq("spec", service)
    .neq("status", "قيد الانتظار");

  if (techsResponse.error) {
    return jsonResponse({ error: techsResponse.error.message }, 500);
  }

  const techs = techsResponse.data ?? [];
  const outcomesResponse = await client
    .from("job_outcomes")
    .select("recommended_technician_id, first_visit_fix, repeat_issue")
    .order("created_at", { ascending: false })
    .limit(500);

  if (outcomesResponse.error) {
    return jsonResponse({ error: outcomesResponse.error.message }, 500);
  }

  const outcomes = outcomesResponse.data ?? [];
  const ranked = techs.map((tech) => {
    const techOutcomes = outcomes.filter((row) => row.recommended_technician_id === tech.id);
    const matchedJobs = techOutcomes.length;
    const firstVisitFixes = techOutcomes.filter((row) => row.first_visit_fix === true).length;
    const repeatIssues = techOutcomes.filter((row) => row.repeat_issue === true).length;
    const firstVisitRate = matchedJobs === 0 ? 0 : firstVisitFixes / matchedJobs;
    const repeatRate = matchedJobs === 0 ? 0 : repeatIssues / matchedJobs;
    const keywordScore = buildKeywordScore(diagnosisText, service) * 8;
    const areaScore = area && tech.area && normalize(tech.area).includes(normalize(area)) ? 12 : 0;
    const availabilityScore = tech.status === "متاح" ? 25 : tech.status === "مشغول" ? 10 : 0;
    const ratingScore = Number(tech.rating ?? 0) * 12;
    const reliabilityScore = buildReliabilityScore({
      totalJobs: Number(tech.total_jobs ?? 0),
      firstVisitRate,
      repeatRate,
      rating: Number(tech.rating ?? 0),
      isVerified: Boolean(tech.is_verified),
      status: String(tech.status ?? ""),
    });
    const volumeScore = Math.min(Number(tech.total_jobs ?? 0), 50) * 0.2;
    const verificationScore = tech.is_verified ? 8 : 0;
    const score = areaScore + availabilityScore + ratingScore + reliabilityScore + volumeScore + verificationScore + keywordScore;

    const reasonParts = [];
    if (areaScore > 0) reasonParts.push("قريب من المنطقة");
    if (keywordScore > 0) reasonParts.push("مطابق للتحليل");
    if (verificationScore > 0) reasonParts.push("موثّق");
    if (firstVisitRate >= 0.7 && matchedJobs >= 5) reasonParts.push("حل من أول زيارة");
    if (repeatRate <= 0.1 && matchedJobs >= 5) reasonParts.push("أقل عودة أعطال");
    if (reasonParts.length === 0) reasonParts.push("أفضل توازن بين الخبرة والتوفر");

    return {
      technicianId: tech.id,
      name: tech.name,
      score: Number(score.toFixed(2)),
      reliabilityScore: Number(reliabilityScore.toFixed(2)),
      reason: reasonParts.slice(0, 3).join(" Â· "),
      rating: Number(tech.rating ?? 0),
      totalJobs: Number(tech.total_jobs ?? 0),
      area: tech.area,
      status: tech.status,
      matchedJobs,
      firstVisitRate: Number(firstVisitRate.toFixed(2)),
      repeatRate: Number(repeatRate.toFixed(2)),
      eligibleForAutoPick: reliabilityScore >= 60,
    };
  }).sort((a, b) => b.score - a.score);

  const eligibleRanked = ranked.filter((item) => item.eligibleForAutoPick);
  const autoPickPool = eligibleRanked.length > 0 ? eligibleRanked : ranked;

  const response: SmartMatchResponse = {
    analysisSource: "heuristic",
    autoPickThreshold: 60,
    topTechnicians: ranked.slice(0, 5),
    recommendedTechnicianId: autoPickPool[0]?.technicianId ?? null,
    fallbackTechnicianIds: autoPickPool.slice(1, 4).map((item) => item.technicianId),
    reasoning: autoPickPool[0]?.reason ?? "Not enough data yet",
  };

  const openAIRank = await rankWithOpenAI(body, response.topTechnicians);
  if (openAIRank) {
    const topMap = new Map(response.topTechnicians.map((item) => [item.technicianId, item]));
    const reordered = openAIRank.rankedTechnicians
      .map((item) => {
        const base = topMap.get(item.technicianId);
        return base ? { ...base, reason: item.reason || base.reason } : null;
      })
      .filter((item): item is NonNullable<typeof item> => item !== null);

    const remaining = response.topTechnicians.filter(
      (item) => !reordered.some((rankedItem) => rankedItem.technicianId === item.technicianId),
    );

    response.analysisSource = "openai";
    response.topTechnicians = [...reordered, ...remaining];
    const openAIRecommended = response.topTechnicians.find((item) => item.technicianId === openAIRank.recommendedTechnicianId);
    const openAIEligible = response.topTechnicians.filter((item) => item.reliabilityScore >= response.autoPickThreshold);
    const pool = openAIEligible.length > 0 ? openAIEligible : response.topTechnicians;
    response.recommendedTechnicianId = openAIRecommended && openAIRecommended.reliabilityScore >= response.autoPickThreshold
      ? openAIRank.recommendedTechnicianId
      : pool[0]?.technicianId ?? null;
    const poolForFallback = response.topTechnicians.filter((item) => item.technicianId !== response.recommendedTechnicianId && item.reliabilityScore >= response.autoPickThreshold);
    response.fallbackTechnicianIds = response.topTechnicians
      .filter((item) => item.technicianId !== response.recommendedTechnicianId)
      .slice(0, 3)
      .map((item) => item.technicianId);
    if (poolForFallback.length > 0) {
      response.fallbackTechnicianIds = poolForFallback.slice(0, 3).map((item) => item.technicianId);
    }
    response.reasoning = openAIRank.reasoning || response.reasoning;
  }

  return jsonResponse(response);
});

function buildReliabilityScore(input: {
  totalJobs: number;
  firstVisitRate: number;
  repeatRate: number;
  rating: number;
  isVerified: boolean;
  status: string;
}) {
  const jobsComponent =
    input.totalJobs >= 40 ? 25 :
    input.totalJobs >= 20 ? 18 :
    input.totalJobs >= 10 ? 10 :
    input.totalJobs >= 3 ? 5 : 0;
  const fixComponent = Math.min(Math.max(input.firstVisitRate * 45, 0), 45);
  const repeatPenalty = Math.min(Math.max(input.repeatRate * 35, 0), 35);
  const ratingComponent = Math.min(Math.max((input.rating / 5) * 20, 0), 20);
  const verificationComponent = input.isVerified ? 5 : 0;
  const statusComponent = input.status === "متاح" ? 5 : input.status === "مشغول" ? 2 : 0;
  const raw = jobsComponent + fixComponent + ratingComponent + verificationComponent + statusComponent - repeatPenalty;
  return Math.min(Math.max(raw, 0), 100);
}
