// ============================================================================
// VERIFY GENDER EDGE FUNCTION
// Handles gender verification submission for admin review
// NOTE: We do NOT use AI to infer gender - this is admin-reviewed only
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface GenderVerifyRequest {
  evidence_url: string; // URL to uploaded ID/selfie proof
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

    const body: GenderVerifyRequest = await req.json();

    if (!body.evidence_url) {
      return new Response(
        JSON.stringify({ error: 'Missing evidence_url' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

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

    // Check if user has a profile with gender claim
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('gender_claim')
      .eq('user_id', user.id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'Profile not found. Create profile first.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check for existing gender verification
    const { data: existing } = await supabaseAdmin
      .from('gender_verification')
      .select('status')
      .eq('user_id', user.id)
      .single();

    if (existing?.status === 'approved') {
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            status: 'approved',
            message: 'Gender verification already approved',
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (existing?.status === 'pending') {
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            status: 'pending',
            message: 'Gender verification already submitted and pending review',
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create or update gender verification record
    const { error: upsertError } = await supabaseAdmin
      .from('gender_verification')
      .upsert({
        user_id: user.id,
        status: 'pending',
        evidence_url: body.evidence_url,
        submitted_at: new Date().toISOString(),
        reviewed_at: null,
        reason: null,
      });

    if (upsertError) {
      throw upsertError;
    }

    // Create job for admin review
    await supabaseAdmin.from('jobs').insert({
      type: 'admin_review_gender',
      payload: {
        user_id: user.id,
        gender_claim: profile.gender_claim,
        evidence_url: body.evidence_url,
      },
      priority: 2,
    });

    // Log action
    await supabaseAdmin.from('audit_log').insert({
      actor: user.id,
      action: 'gender_submitted',
      target_user: user.id,
      payload: {
        gender_claim: profile.gender_claim,
        // Do not log evidence_url for privacy
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          status: 'pending',
          message: 'Gender verification submitted for admin review',
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Gender verification error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
