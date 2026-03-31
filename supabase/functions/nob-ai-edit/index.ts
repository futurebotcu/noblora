import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PROMPTS: Record<string, string> = {
  fix_typos:
    "Fix only spelling and grammar errors. Do not change the meaning, tone or style. Return only the corrected text, nothing else.",
  clean_up:
    "Clean up this text slightly. Fix typos, remove redundancy, improve flow. Keep the author's voice. Max 150 chars. Return only the cleaned text, nothing else.",
  make_clearer:
    "Make this thought clearer and more concise. Keep the original meaning and tone. Max 150 chars. Return only the text, nothing else.",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS, status: 200 });
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
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";

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
            maxOutputTokens: 256,
          },
        }),
      }
    );

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
