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

      return new Response(
        JSON.stringify({ result: data.result ?? null }),
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
