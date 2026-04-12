import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ---------------------------------------------------------------------------
// nob-country-insight — AI-powered country mood summary
//
// Receives aggregate data from the client (already fetched via
// fetch_country_insight_data RPC) and produces a short editorial summary
// with Gemini. This keeps the edge function stateless and lets the client
// show the raw aggregate even if the AI call fails.
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS, status: 200 });
  }

  try {
    const {
      country_code,
      country_name,
      time_window,
      total_posts,
      unique_authors,
      avg_quality,
      dominant_mood,
      mood_breakdown,
      top_topics,
      engagement,
      data_quality,
    } = await req.json();

    if (!country_code || data_quality === "insufficient") {
      return new Response(
        JSON.stringify({ error: "Insufficient data for insight" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "AI not configured" }),
        { status: 503, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.1-flash-lite-preview";

    // Build a privacy-safe prompt from aggregate-only data
    const moodList = (mood_breakdown ?? [])
      .map((m: any) => `${m.mood} (${m.count})`)
      .join(", ");
    const topicList = (top_topics ?? [])
      .map((t: any) => `${t.topic} (${t.count})`)
      .join(", ");
    const eng = engagement ?? {};
    const totalEng =
      (eng.reactions ?? 0) + (eng.echoes ?? 0) + (eng.comments ?? 0);

    const prompt =
      `You are a concise cultural analyst for a social app called Noblara.\n` +
      `Analyze the following AGGREGATE mood data for a country and produce a short editorial insight.\n\n` +
      `Country: ${country_name ?? country_code}\n` +
      `Time window: last ${time_window}\n` +
      `Total anonymous posts: ${total_posts}\n` +
      `Unique contributors: ${unique_authors}\n` +
      `Average content quality (0-1): ${avg_quality}\n` +
      `Dominant mood: ${dominant_mood}\n` +
      `Mood breakdown: ${moodList || "none"}\n` +
      `Top topics: ${topicList || "none"}\n` +
      `Total engagement (reactions+echoes+comments): ${totalEng}\n` +
      `Data quality: ${data_quality}\n\n` +
      `Rules:\n` +
      `- Never invent facts. Only analyze what the data shows.\n` +
      `- If data is limited, say so. Do not dramatize.\n` +
      `- Keep summary_text under 60 words.\n` +
      `- summary_title should be max 10 words.\n` +
      `- viral_topic: pick the topic with highest engagement density, or null if nothing stands out.\n` +
      `- confidence: 0.0-1.0 based on data volume and consistency.\n` +
      `- Tone: observational, calm, intelligent. Not news-anchor dramatic.`;

    const body = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 512,
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            summary_title: { type: "string" },
            summary_text: { type: "string" },
            viral_topic: { type: "string" },
            viral_reason: { type: "string" },
            confidence: { type: "number" },
          },
          required: ["summary_title", "summary_text", "confidence"],
        },
      },
    };

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

    // Single attempt — insight is non-critical, no retry needed
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errBody = await response.text().catch(() => "");
      console.error("[nob-country-insight] gemini", response.status, errBody);
      return new Response(
        JSON.stringify({ error: `gemini_http_${response.status}` }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const data = await response.json();
    const rawText =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const finishReason = data?.candidates?.[0]?.finishReason ?? "unknown";

    if (!rawText || finishReason !== "STOP") {
      return new Response(
        JSON.stringify({ error: "ai_incomplete", finishReason }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    let parsed: any;
    try {
      parsed = JSON.parse(rawText);
    } catch {
      return new Response(
        JSON.stringify({ error: "ai_parse_failed", raw: rawText.slice(0, 300) }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        summary_title: parsed.summary_title ?? "",
        summary_text: parsed.summary_text ?? "",
        viral_topic: parsed.viral_topic ?? null,
        viral_reason: parsed.viral_reason ?? null,
        confidence: typeof parsed.confidence === "number" ? parsed.confidence : 0.5,
        data_quality,
        time_window,
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[nob-country-insight] error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});
