import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type ChatMessageInput = {
  role: "user" | "assistant";
  content: string;
};

type AgentChatRequest = {
  session_id?: string;
  message: string;
  image_base64?: string;
  context?: {
    user_name?: string;
    city?: string;
    active_orders_count?: number;
    available_techs_count?: number;
  };
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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return jsonResponse({ ok: true });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    let userId: string | null = null;

    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const { data: { user } } = await supabase.auth.getUser(token);
      if (user) {
        userId = user.id;
      }
    }

    const payload: AgentChatRequest = await req.json();
    const userMessageText = payload.message || "";
    let sessionId = payload.session_id;

    // Create session if not provided
    if (!sessionId && userId) {
      const { data: sessionData, error: sessionErr } = await supabase
        .from("chat_sessions")
        .insert({
          user_id: userId,
          title: userMessageText.substring(0, 50) || "محادثة جديدة",
        })
        .select("id")
        .single();

      if (!sessionErr && sessionData) {
        sessionId = sessionData.id;
      }
    }

    // Save User Message to DB if session exists
    if (sessionId && userId) {
      await supabase.from("chat_messages").insert({
        session_id: sessionId,
        user_id: userId,
        role: "user",
        content: userMessageText,
        image_url: payload.image_base64 ? "data:image/jpeg;base64,..." : null,
      });

      await supabase
        .from("chat_sessions")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", sessionId);
    }

    // Load recent history (up to 10 messages)
    let history: ChatMessageInput[] = [];
    if (sessionId) {
      const { data: pastMessages } = await supabase
        .from("chat_messages")
        .select("role, content")
        .eq("session_id", sessionId)
        .order("created_at", { ascending: true })
        .limit(10);

      if (pastMessages) {
        history = pastMessages.map((m) => ({
          role: m.role as "user" | "assistant",
          content: m.content,
        }));
      }
    }

    // Intent Detection & Emergency check
    const normalizedInput = normalize(userMessageText);
    const isEmergency = ["غاز", "شرر", "حريق", "كهربا مكشوفه", "ماس", "صعق", "طوارئ", "تفريغ فريون"].some((term) =>
      normalizedInput.includes(normalize(term))
    );

    // Call AI Model (Vercel Gateway -> Gemini -> OpenAI)
    const vercelKey = Deno.env.get("VERCEL_AI_GATEWAY_API_KEY");
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    const openaiKey = Deno.env.get("OPENAI_API_KEY");

    let aiReplyText = "";
    let detectedIntent = isEmergency ? "emergency" : "general_query";
    let emergencySteps: string[] = [];
    let quickReplies: string[] = [];
    let contactPhone: string | undefined = undefined;

    if (isEmergency) {
      aiReplyText = "⚠️ **تحذير طوارئ هام!**\nيرجى اتباع خطوات السلامة الفورية لحمايتك وحماية أسرتك:";
      emergencySteps = [
        "افصل المفتاح الكهربائي الرئيسي فوراً في حالة وجود ماس أو شرر.",
        "أغلق محبس الغاز العمومي فوراً إذا كانت هناك رائحة غاز.",
        "لا تقم بتشغيل أي أجهزة أو مئانس كهربائية.",
        "اختر 'طلب فني طوارئ' لإرسال أقرب فني متخصص في مدينتك فوراً.",
      ];
      quickReplies = ["طلب فني طوارئ", "تواصل مع الدعم الفني", "إعادة تشخيص"];
      contactPhone = "19000";
    } else {
      // Prompt construction for conversational assistant
      const systemPrompt = `أنت "حرفي بوت" - المساعد الذكي التفاعلي لمنصة حرفي للصيانة المنزلية في مصر.
تتحدث باللغة العربية بأسلوب مهني، ودود، ومشجع.
معلومات سياق العميل:
- اسم العميل: ${payload.context?.user_name || "العميل"}
- المدينة: ${payload.context?.user_name || "مصر"}
- عدد طلبات الصيانة النشطة: ${payload.context?.active_orders_count || 0}
- الفنيون المتاحون بالقرب منه: ${payload.context?.available_techs_count || 5} فنيين.

مهامك:
1. الإجابة عن أي استفسار تخص صيانة الكهرباء، السباكة، التكييفات، والأجهزة المنزلية.
2. تقديم حلول سريعة ونصائح مجانية آمنة يمكن للعميل تجريبها.
3. التوصية بطلب فني عند وجود أعطال ميكانيكية أو كهربائية معقدة.
4. إعطاء متوسط التكلفة بالجنيه المصري (ج.م) بمرونة ووضوح.`;

      // Simple AI Fallback flow if API key isn't provided
      if (!vercelKey && !geminiKey && !openaiKey) {
        aiReplyText = `أهلاً بك يا ${payload.context?.user_name || "فندم"} في منصة حرفي! 🛠️\n` +
          `أنا معك لمساعدتك في أي استفسار عن صيانة الأجهزة والسباكة والكهرباء.\n` +
          `يمكنك إخباري بتفاصيل العطل أو اختيار أحد الخيارات السريعة أدناه.`;
        quickReplies = ["فحص عطل سباكة", "فحص عطل تكييف", "طلب فني طوارئ", "تتبع الطلبات الحالية"];
      } else {
        // Try Gemini / OpenAI API call
        try {
          const apiKey = geminiKey || openaiKey;
          const apiUrl = geminiKey
            ? `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`
            : "https://api.openai.com/v1/chat/completions";

          let res;
          if (geminiKey) {
            res = await fetch(apiUrl, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [
                  { role: "user", parts: [{ text: `${systemPrompt}\n\nرسالة العميل: ${userMessageText}` }] }
                ]
              })
            });
            const data = await res.json();
            aiReplyText = data.candidates?.[0]?.content?.parts?.[0]?.text || "تم استلام طلبك ومراجعته.";
          } else {
            res = await fetch(apiUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${openaiKey}`
              },
              body: JSON.stringify({
                model: "gpt-4o-mini",
                messages: [
                  { role: "system", content: systemPrompt },
                  ...history.map(h => ({ role: h.role, content: h.content })),
                  { role: "user", content: userMessageText }
                ]
              })
            });
            const data = await res.json();
            aiReplyText = data.choices?.[0]?.message?.content || "تم استلام طلبك ومراجعته.";
          }

          quickReplies = ["طلب فني متخصص", "معرفة التكلفة التقديرية", "خطوات صيانة مجانية"];
        } catch (err) {
          console.error("AI Fetch error:", err);
          aiReplyText = "شكراً لتواصلك! يبدو أن هناك بطء مؤقت في الشبكة. يمكنك اختيار الخدمة المطلوبة وسنقوم بتوصيلك بأفضل فني متاح فوراً.";
          quickReplies = ["طلب فني متخصص", "تواصل مع الدعم الفني"];
        }
      }
    }

    // Save Assistant Message to DB if session exists
    let assistantMsgId: number | null = null;
    if (sessionId && userId) {
      const { data: insertedMsg } = await supabase
        .from("chat_messages")
        .insert({
          session_id: sessionId,
          user_id: userId,
          role: "assistant",
          content: aiReplyText,
          intent: detectedIntent,
          emergency_steps: emergencySteps.length > 0 ? emergencySteps : null,
          quick_replies: quickReplies.length > 0 ? quickReplies : null,
          contact_phone: contactPhone,
        })
        .select("id")
        .single();

      if (insertedMsg) {
        assistantMsgId = insertedMsg.id;
      }
    }

    return jsonResponse({
      session_id: sessionId,
      message_id: assistantMsgId,
      reply: aiReplyText,
      intent: detectedIntent,
      emergency_steps: emergencySteps,
      quick_replies: quickReplies,
      contact_phone: contactPhone,
    });
  } catch (err) {
    console.error("Agent chat function error:", err);
    return jsonResponse(
      {
        error: "حدث خطأ غير متوقع أثناء معالجة الطلب.",
        details: String(err),
      },
      500
    );
  }
});
