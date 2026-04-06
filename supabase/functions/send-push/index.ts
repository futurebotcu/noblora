// Supabase Edge Function: Send push notification via FCM HTTP v1
// Triggered by database trigger on notifications table insert
//
// Required secrets (set via Supabase dashboard → Edge Functions → Secrets):
//   FIREBASE_PROJECT_ID   — e.g. "noblara-12345"
//   FIREBASE_SERVICE_KEY  — Base64-encoded Firebase service account JSON

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PushPayload {
  user_id: string;
  title: string;
  body: string;
  type: string;
  data: Record<string, string>;
}

serve(async (req) => {
  try {
    // Verify auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response("Unauthorized", { status: 401 });
    }

    const payload: PushPayload = await req.json();
    const { user_id, title, body, type, data } = payload;

    if (!user_id || !title) {
      return new Response("Missing user_id or title", { status: 400 });
    }

    // Get user's FCM tokens from Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: tokens, error: tokenError } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", user_id);

    if (tokenError || !tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, reason: "no_tokens" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get Firebase access token via service account
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const serviceKeyB64 = Deno.env.get("FIREBASE_SERVICE_KEY");

    if (!firebaseProjectId || !serviceKeyB64) {
      return new Response(
        JSON.stringify({ sent: 0, reason: "firebase_not_configured" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const serviceKey = JSON.parse(atob(serviceKeyB64));
    const accessToken = await getFirebaseAccessToken(serviceKey);

    // Send to each token
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;
    let sent = 0;
    const invalidTokens: string[] = [];

    for (const { token } of tokens) {
      const message = {
        message: {
          token,
          notification: { title, body },
          data: { ...data, type, click_action: "FLUTTER_NOTIFICATION_CLICK" },
          android: {
            priority: "high" as const,
            notification: {
              channel_id: "noblara_messages",
              sound: "default",
            },
          },
        },
      };

      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      });

      if (res.ok) {
        sent++;
      } else {
        const err = await res.json();
        // Clean up invalid/unregistered tokens
        const errorCode = err?.error?.details?.[0]?.errorCode;
        if (
          errorCode === "UNREGISTERED" ||
          errorCode === "INVALID_ARGUMENT"
        ) {
          invalidTokens.push(token);
        }
      }
    }

    // Remove stale tokens
    if (invalidTokens.length > 0) {
      await supabase
        .from("push_tokens")
        .delete()
        .in("token", invalidTokens);
    }

    return new Response(
      JSON.stringify({ sent, cleaned: invalidTokens.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// Generate OAuth2 access token from Firebase service account
async function getFirebaseAccessToken(
  serviceAccount: Record<string, string>
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = btoa(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );

  const unsigned = `${header}.${claim}`;

  // Import private key and sign
  const pemKey = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemKey), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)));
  const jwt = `${unsigned}.${sig}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}
