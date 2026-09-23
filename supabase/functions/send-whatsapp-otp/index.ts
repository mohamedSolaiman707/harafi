import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

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

function cleanPhoneNumber(phone: string): string {
  let clean = phone.replace(/\D/g, "");
  if (clean.startsWith("0")) clean = "2" + clean;
  if (!clean.startsWith("2")) clean = "20" + clean;
  return clean;
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

  try {
    const payload = await req.json();
    const { to, body, phone, otp } = payload;

    const instanceId = Deno.env.get("ULTRAMSG_INSTANCE_ID") || "instance188485";
    const token = Deno.env.get("ULTRAMSG_TOKEN") || "2f92w8s3fow0ofku";

    let targetPhone = to;
    let messageBody = body;

    if (!targetPhone && phone) {
      targetPhone = cleanPhoneNumber(phone);
    } else if (targetPhone) {
      targetPhone = cleanPhoneNumber(targetPhone);
    }

    if (!messageBody && otp) {
      messageBody = `كود التحقق الخاص بك لمنصة حرفي هو: *${otp}*\n\nيرجى إدخال الكود في التطبيق لإتمام طلبك. 🛠️`;
    }

    if (!targetPhone || !messageBody) {
      return jsonResponse({ success: false, error: "Missing required parameters: 'to'/'phone' and 'body'/'otp'" }, 400);
    }

    const url = `https://api.ultramsg.com/${instanceId}/messages/chat`;
    const formData = new URLSearchParams();
    formData.append("token", token);
    formData.append("to", targetPhone);
    formData.append("body", messageBody);

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: formData.toString(),
    });

    const responseData = await response.json();

    if (!response.ok || responseData.error) {
      return jsonResponse({ success: false, error: responseData.error || "Failed to send WhatsApp message" }, 500);
    }

    return jsonResponse({ success: true, data: responseData });
  } catch (error) {
    return jsonResponse({ success: false, error: String(error) }, 500);
  }
});
