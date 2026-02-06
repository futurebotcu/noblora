// ============================================================================
// VERIFY INSTAGRAM EDGE FUNCTION
// Handles Instagram OAuth and manual verification fallback
// NOTE: Instagram username is NEVER exposed to other users
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface InstagramVerifyRequest {
  // OAuth flow
  oauth_code?: string;
  redirect_uri?: string;

  // Manual proof flow (fallback)
  ig_username?: string;
  proof_image_url?: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body: InstagramVerifyRequest = await req.json();

    // Verify user
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Check for existing Instagram record
    const { data: existing } = await supabaseAdmin
      .from('instagram')
      .select('*')
      .eq('user_id', user.id)
      .single();

    // OAuth flow (placeholder - implement when IG API credentials available)
    if (body.oauth_code) {
      const igClientId = Deno.env.get('INSTAGRAM_CLIENT_ID');
      const igClientSecret = Deno.env.get('INSTAGRAM_CLIENT_SECRET');

      if (!igClientId || !igClientSecret) {
        // Fall back to manual verification
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Instagram OAuth not configured',
            fallback: 'manual_proof',
            message: 'Please use manual verification: upload a screenshot of your IG profile',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // TODO: Implement actual Instagram OAuth flow
      // 1. Exchange code for access token
      // 2. Fetch user profile to get username
      // 3. Fetch user media to verify face photos exist
      // 4. Store encrypted tokens

      return new Response(
        JSON.stringify({
          success: false,
          error: 'Instagram OAuth not implemented',
          fallback: 'manual_proof',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Manual proof flow
    if (body.ig_username && body.proof_image_url) {
      // Validate username format
      if (!/^[a-zA-Z0-9._]+$/.test(body.ig_username) || body.ig_username.length > 30) {
        return new Response(
          JSON.stringify({ error: 'Invalid Instagram username format' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Store Instagram record (pending verification)
      const { error: upsertError } = await supabaseAdmin
        .from('instagram')
        .upsert({
          user_id: user.id,
          ig_username: body.ig_username,
          ig_connected: true,
          ig_connected_at: new Date().toISOString(),
          ig_media_verified: false, // Pending admin review
        });

      if (upsertError) {
        throw upsertError;
      }

      // Create job for admin review
      await supabaseAdmin.from('jobs').insert({
        type: 'admin_review_instagram',
        payload: {
          user_id: user.id,
          ig_username: body.ig_username,
          proof_image_url: body.proof_image_url,
        },
        priority: 2,
      });

      // Log action
      await supabaseAdmin.from('audit_log').insert({
        actor: user.id,
        action: 'ig_connected',
        target_user: user.id,
        payload: {
          ig_username: body.ig_username,
          method: 'manual_proof',
        },
      });

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            status: 'pending_review',
            message: 'Your Instagram verification is pending admin review',
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Return current status
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          connected: existing?.ig_connected ?? false,
          verified: existing?.ig_media_verified ?? false,
          // NOTE: We do NOT return ig_username to the client
          // Other users only see a "verified" badge
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Instagram verification error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
