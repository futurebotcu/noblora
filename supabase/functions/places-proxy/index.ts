import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Sanity-check the apikey header is present and length-plausible.
// Real auth is enforced at the gateway via verify_jwt=true; the strict
// `key !== anonKey` equality check used to live here was removing
// legitimate Flutter SDK invokes (returned 401 because Supabase
// platform injects SUPABASE_ANON_KEY as a publishable_key whose
// shape differs from the legacy JWT the client sends, even though
// the gateway's JWT verification accepts both). Synced with the
// gemini-text v9 deployed pattern.
// See supabase/config.toml comment on nob-quality-check for the
// documented regression this avoids.
function validateApiKey(req: Request): boolean {
  const key = req.headers.get("apikey") ?? "";
  return key.length > 20;
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
    const { action, query, placeId } = await req.json();
    const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "Google Places API key not configured" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (action === "autocomplete") {
      if (!query || typeof query !== "string" || query.trim().length < 2) {
        return new Response(
          JSON.stringify({ predictions: [] }),
          { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(query)}&types=(cities)&key=${apiKey}`;
      const resp = await fetch(url);
      const data = await resp.json();

      return new Response(
        JSON.stringify({ predictions: data.predictions ?? [] }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (action === "details") {
      if (!placeId || typeof placeId !== "string") {
        return new Response(
          JSON.stringify({ error: "placeId required" }),
          { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(placeId)}&fields=geometry,address_components&key=${apiKey}`;
      const resp = await fetch(url);
      const data = await resp.json();

      // Enrich result with ISO 2-letter country code (short_name of type=country
      // address component). Used by R13 geo-awareness layer for swipe gating
      // (TH/VN/PH check). Long-name `country` already lives in
      // address_components and remains untouched for backward compat.
      let countryCode: string | null = null;
      const components = (data.result?.address_components ?? []) as Array<{
        types?: string[];
        short_name?: string;
      }>;
      for (const c of components) {
        if (c.types?.includes("country")) {
          countryCode = c.short_name ?? null;
          break;
        }
      }

      const enrichedResult = data.result
        ? { ...data.result, countryCode }
        : null;

      return new Response(
        JSON.stringify({ result: enrichedResult }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Invalid action. Use 'autocomplete' or 'details'." }),
      { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
