import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BASE_PROMPT =
  "Improve this text gently. Fix spelling and grammar errors, improve clarity and flow.\n\n" +
  "ABSOLUTE RULES — NEVER BREAK THESE:\n" +
  "1. Your output language MUST be IDENTICAL to the input language. Auto-detect the language and stay in it.\n" +
  "2. NEVER translate. If input is Turkish, output Turkish. If Korean, output Korean. If English, output English. Any language.\n" +
  "3. Keep the original meaning, tone, and voice.\n" +
  "4. Keep roughly the same length — do NOT shorten aggressively.\n" +
  "5. Do NOT leave sentences unfinished.\n" +
  "6. Do NOT summarize.\n" +
  "7. Return ONLY the improved text. No explanations, no labels, no quotes.";

function validateApiKey(req: Request): boolean {
  const key = req.headers.get("apikey") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!key || (anonKey && key !== anonKey) || key.length < 20) {
    return false;
  }
  return true;
}

const PROMPTS: Record<string, string> = {
  improve: BASE_PROMPT,
};

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
    const { content, edit_type } = await req.json();

    if (!content || !edit_type || !PROMPTS[edit_type]) {
      return new Response(
        JSON.stringify({ error: "Missing content or invalid edit_type" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

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
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: PROMPTS[edit_type] },
                { text: `\n\nText:\n${content}` },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 2048,
          },
        }),
      }
    );

    if (!response.ok) {
      const errorBody = await response.text();
      return new Response(
        JSON.stringify({ error: `Gemini API error: ${response.status}`, details: errorBody }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const edited =
      data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? content;

    return new Response(
      JSON.stringify({ edited_content: edited }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
