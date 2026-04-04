import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { post_id, content, nob_type } = await req.json();

    if (!post_id || (!content && nob_type !== "moment")) {
      return new Response(
        JSON.stringify({ error: "Missing post_id or content" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured", score: 0.5, ai_scored: false }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }
    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

    const prompt = `Rate this social post on quality (0.0-1.0).
Consider: originality, depth, clarity, authenticity.
Penalize: spam, low effort, repetition, attention-seeking.
Return ONLY valid JSON: { "score": float, "tags": string[] }

Post type: ${nob_type}
Post content: ${content || "(moment — caption only)"}`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 1024 },
        }),
      }
    );

    const data = await response.json();
    const rawText =
      data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "{}";

    let score = 0.5;
    try {
      const jsonStr = rawText.replace(/```json|```/g, "").trim();
      const parsed = JSON.parse(jsonStr);
      score = Math.min(1.0, Math.max(0.0, parsed.score ?? 0.5));
    } catch (_) {
      // fallback
    }

    // Update quality_score in posts table
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    await supabase
      .from("posts")
      .update({ quality_score: score })
      .eq("id", post_id);

    return new Response(
      JSON.stringify({ score }),
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
