import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function validateApiKey(req: Request): boolean {
  const key = req.headers.get("apikey") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!key || (anonKey && key !== anonKey) || key.length < 20) {
    return false;
  }
  return true;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS, status: 200 });
  }

  if (!validateApiKey(req)) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  try {
    const { selfie, profile } = await req.json();

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: `You are an identity verification AI for a dating app.
Return ONLY valid JSON in this exact format:
{
  "same_person": boolean,
  "real_selfie_probability": number,
  "gender_detected": "male" | "female" | "unknown",
  "fraud_signals": string[],
  "confidence": number
}`,
                },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: selfie,
                  },
                },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: profile,
                  },
                },
              ],
            },
          ],
        }),
      }
    );

    const data = await response.json();

    return new Response(JSON.stringify(data), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (e) {
    return new Response(
      JSON.stringify({
        error: e instanceof Error ? e.message : String(e),
      }),
      {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
