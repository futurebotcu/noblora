import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Mood vocabulary kept aligned with the Flutter mood-color palette so the
// world map and feed lanes have something to render. Adding a new mood here
// also requires updating mood_map_screen.dart `moodColor`.
const MOODS = [
  "quiet",
  "tender",
  "hopeful",
  "reflective",
  "grounded",
  "curious",
  "restless",
  "burning",
  "late_night",
];

type AnalysisResult = {
  quality_score: number;
  primary_mood: string | null;
  secondary_mood: string | null;
  mood_intensity: number;
  topic_labels: string[];
  language_code: string | null;
  ai_status: string;
  ai_error?: string;
};

function defaultAnalysis(status: string, error?: string): AnalysisResult {
  return {
    quality_score: 0.5,
    primary_mood: null,
    secondary_mood: null,
    mood_intensity: 0,
    topic_labels: [],
    language_code: null,
    ai_status: status,
    ai_error: error,
  };
}

async function analyzeWithGemini(
  content: string,
  nob_type: string,
): Promise<AnalysisResult> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return defaultAnalysis("missing_api_key", "GEMINI_API_KEY not configured");
  }
  if (!content || content.trim().length === 0) {
    return defaultAnalysis("empty_content");
  }

  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

  const prompt =
    `Analyze this short social post and return JSON only.\n\n` +
    `Schema fields:\n` +
    `  score: float 0-1 (quality: originality, depth, clarity, authenticity; penalize spam/low effort/attention seeking)\n` +
    `  primary_mood: one of [${MOODS.join(", ")}]\n` +
    `  secondary_mood: one of [${MOODS.join(", ")}] or null\n` +
    `  mood_intensity: int 1-10\n` +
    `  topics: array of up to 3 short lowercase tags\n` +
    `  language: ISO 639-1 two-letter code (en, tr, de, ...)\n\n` +
    `Post type: ${nob_type}\nPost content: ${content}`;

  // Force structured JSON output via responseMimeType + responseSchema. This
  // removes the brittle markdown-stripping that previously made parsing fail
  // silently and leave every post stuck at the 0.5 fallback.
  const body = {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 512,
      responseMimeType: "application/json",
      responseSchema: {
        type: "object",
        properties: {
          score: { type: "number" },
          primary_mood: { type: "string", enum: MOODS },
          secondary_mood: { type: "string", enum: [...MOODS, "none"] },
          mood_intensity: { type: "integer" },
          topics: {
            type: "array",
            items: { type: "string" },
          },
          language: { type: "string" },
        },
        required: [
          "score",
          "primary_mood",
          "mood_intensity",
          "topics",
          "language",
        ],
      },
    },
  };

  let response: Response;
  try {
    response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      },
    );
  } catch (e) {
    return defaultAnalysis("gemini_fetch_failed", String(e));
  }

  if (!response.ok) {
    let errBody = "";
    try {
      errBody = await response.text();
    } catch (_) {
      // ignore
    }
    console.error("[nob-quality-check] gemini", response.status, errBody);
    return defaultAnalysis(`gemini_http_${response.status}`, errBody.slice(0, 500));
  }

  let data: unknown;
  try {
    data = await response.json();
  } catch (e) {
    return defaultAnalysis("gemini_json_decode_failed", String(e));
  }

  const candidates = (data as any)?.candidates as any[] | undefined;
  const rawText = candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  if (!rawText) {
    console.error("[nob-quality-check] empty rawText", JSON.stringify(data));
    // Surface the finishReason / safety block hints in ai_error so we can
    // tell "model returned nothing" apart from "model was filtered".
    const finishReason =
      candidates?.[0]?.finishReason ?? (data as any)?.promptFeedback?.blockReason ?? "unknown";
    return defaultAnalysis("gemini_empty_response", `finishReason=${finishReason}`);
  }

  let parsed: any;
  try {
    parsed = JSON.parse(rawText);
  } catch (e) {
    // responseMimeType should guarantee JSON, but fall back to a brace match.
    const match = rawText.match(/\{[\s\S]*\}/);
    if (match) {
      try {
        parsed = JSON.parse(match[0]);
      } catch (e2) {
        return defaultAnalysis("parse_failed", `${e}; fallback: ${e2}`);
      }
    } else {
      return defaultAnalysis("parse_failed", String(e));
    }
  }

  const score = Math.min(
    1.0,
    Math.max(0.0, typeof parsed.score === "number" ? parsed.score : 0.5),
  );
  const primary =
    typeof parsed.primary_mood === "string" && MOODS.includes(parsed.primary_mood)
      ? parsed.primary_mood
      : null;
  const secondary =
    typeof parsed.secondary_mood === "string" && MOODS.includes(parsed.secondary_mood)
      ? parsed.secondary_mood
      : null;
  const intensity =
    typeof parsed.mood_intensity === "number"
      ? Math.max(0, Math.min(10, Math.round(parsed.mood_intensity)))
      : 0;
  const topics = Array.isArray(parsed.topics)
    ? (parsed.topics as unknown[])
        .filter((t): t is string => typeof t === "string")
        .map((t) => t.toLowerCase().trim())
        .filter((t) => t.length > 0)
        .slice(0, 3)
    : [];
  const language =
    typeof parsed.language === "string" && parsed.language.length === 2
      ? parsed.language.toLowerCase()
      : null;

  return {
    quality_score: score,
    primary_mood: primary,
    secondary_mood: secondary,
    mood_intensity: intensity,
    topic_labels: topics,
    language_code: language,
    ai_status: "ok",
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS, status: 200 });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing authorization header" }),
      { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }

  try {
    const { post_id, content, nob_type } = await req.json();

    if (!post_id) {
      return new Response(
        JSON.stringify({ error: "Missing post_id" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    // Verify caller owns the post via RLS using their token. Under the
    // tightened posts_select_owner_only policy this only succeeds for the
    // post author, so it's also our authorization check.
    const supabaseAuth = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: post, error: postErr } = await supabaseAuth
      .from("posts")
      .select("id, user_id")
      .eq("id", post_id)
      .maybeSingle();

    if (postErr || !post) {
      return new Response(
        JSON.stringify({ error: "Post not found or not yours" }),
        { status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Pull author location for denormalized country/city columns. These are
    // only meaningful for the world mood map aggregation; the mask in
    // fetch_nob_lane prevents them from leaking out for anonymous posts.
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("from_country, city")
      .eq("id", post.user_id)
      .maybeSingle();

    const country_code = profile?.from_country ?? null;
    const city_cluster = profile?.city ?? null;

    const analysis = await analyzeWithGemini(content ?? "", nob_type ?? "thought");

    if (analysis.ai_status !== "ok") {
      console.warn(
        "[nob-quality-check]",
        post_id,
        analysis.ai_status,
        analysis.ai_error,
      );
    }

    // Persist ai_status alongside the analysis fields so failures are
    // queryable from the row instead of dying in 24h server logs. The
    // partial index posts_ai_status_failed_idx makes "find recent silent
    // failures" a single fast lookup.
    await supabaseAdmin
      .from("posts")
      .update({
        quality_score: analysis.quality_score,
        primary_mood: analysis.primary_mood,
        secondary_mood: analysis.secondary_mood,
        mood_intensity: analysis.mood_intensity,
        topic_labels: analysis.topic_labels,
        language_code: analysis.language_code,
        country_code,
        city_cluster,
        ai_status: analysis.ai_status,
        analyzed_at: new Date().toISOString(),
      })
      .eq("id", post_id);

    return new Response(
      JSON.stringify({
        ai_status: analysis.ai_status,
        ai_error: analysis.ai_error ?? null,
        score: analysis.quality_score,
        primary_mood: analysis.primary_mood,
        secondary_mood: analysis.secondary_mood,
        mood_intensity: analysis.mood_intensity,
        topics: analysis.topic_labels,
        language: analysis.language_code,
        country_code,
        city_cluster,
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("[nob-quality-check] error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }
});
