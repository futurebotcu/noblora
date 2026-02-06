// ============================================================================
// REFERRALS EDGE FUNCTION
// Handles referral code creation, redemption, and entry gate updates
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type Action = 'create_code' | 'redeem_code' | 'get_status';

interface ReferralRequest {
  action: Action;
  invitee_gender_required?: string; // For create_code
  code?: string; // For redeem_code
}

// Generate random referral code
function generateCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
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

    const body: ReferralRequest = await req.json();

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

    // Get user's profile
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('gender_claim')
      .eq('user_id', user.id)
      .single();

    if (!profile) {
      return new Response(
        JSON.stringify({ error: 'Profile not found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    switch (body.action) {
      case 'create_code': {
        // Verified users can create referral codes
        const { data: verification } = await supabaseAdmin
          .from('verifications')
          .select('status')
          .eq('user_id', user.id)
          .single();

        if (verification?.status !== 'approved') {
          return new Response(
            JSON.stringify({ error: 'You must be verified to create referral codes' }),
            { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Rate limit: max 5 codes per day
        const { count } = await supabaseAdmin
          .from('referral_codes')
          .select('*', { count: 'exact', head: true })
          .eq('created_by', user.id)
          .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

        if ((count ?? 0) >= 5) {
          return new Response(
            JSON.stringify({ error: 'Maximum 5 referral codes per day' }),
            { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Determine invitee gender (opposite of user's gender for entry gate)
        const inviteeGender = body.invitee_gender_required ||
          (profile.gender_claim === 'male' ? 'female' :
           profile.gender_claim === 'female' ? 'male' : 'other');

        // Generate unique code
        let code = generateCode();
        let attempts = 0;
        while (attempts < 10) {
          const { data: existing } = await supabaseAdmin
            .from('referral_codes')
            .select('code')
            .eq('code', code)
            .single();

          if (!existing) break;
          code = generateCode();
          attempts++;
        }

        // Create code
        const { error: insertError } = await supabaseAdmin
          .from('referral_codes')
          .insert({
            code,
            created_by: user.id,
            inviter_gender: profile.gender_claim,
            invitee_gender_required: inviteeGender,
          });

        if (insertError) throw insertError;

        // Log action
        await supabaseAdmin.from('audit_log').insert({
          actor: user.id,
          action: 'referral_code_created',
          payload: { code, invitee_gender_required: inviteeGender },
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: { code, invitee_gender_required: inviteeGender },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'redeem_code': {
        if (!body.code) {
          return new Response(
            JSON.stringify({ error: 'Missing code' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check if user already used a referral
        const { data: existingReferral } = await supabaseAdmin
          .from('referrals')
          .select('id')
          .eq('referred', user.id)
          .single();

        if (existingReferral) {
          return new Response(
            JSON.stringify({ error: 'You have already used a referral code' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Get the code
        const { data: referralCode, error: codeError } = await supabaseAdmin
          .from('referral_codes')
          .select('*')
          .eq('code', body.code.toUpperCase())
          .eq('is_active', true)
          .single();

        if (codeError || !referralCode) {
          return new Response(
            JSON.stringify({ error: 'Invalid or inactive referral code' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check gender requirement
        if (referralCode.invitee_gender_required !== profile.gender_claim &&
            referralCode.invitee_gender_required !== 'other') {
          return new Response(
            JSON.stringify({
              error: `This code is for ${referralCode.invitee_gender_required} users only`,
            }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Can't use own code
        if (referralCode.created_by === user.id) {
          return new Response(
            JSON.stringify({ error: 'Cannot use your own referral code' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Create referral record
        const { error: referralError } = await supabaseAdmin
          .from('referrals')
          .insert({
            referrer: referralCode.created_by,
            referred: user.id,
            code_used: body.code.toUpperCase(),
          });

        if (referralError) throw referralError;

        // Decrement uses remaining
        await supabaseAdmin
          .from('referral_codes')
          .update({
            uses_remaining: referralCode.uses_remaining - 1,
            is_active: referralCode.uses_remaining > 1,
          })
          .eq('code', body.code.toUpperCase());

        // Log action
        await supabaseAdmin.from('audit_log').insert({
          actor: user.id,
          action: 'referral_code_redeemed',
          payload: { code: body.code.toUpperCase(), referrer: referralCode.created_by },
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: { message: 'Referral code redeemed successfully' },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_status':
      default: {
        // Get entry status
        const { data: entryStatus } = await supabaseAdmin
          .from('entry_status')
          .select('*')
          .eq('user_id', user.id)
          .single();

        // Get referrals made by user
        const { data: referralsMade } = await supabaseAdmin
          .from('referrals')
          .select(`
            id,
            referred,
            created_at,
            referred_verified_at,
            profiles!referrals_referred_fkey(gender_claim)
          `)
          .eq('referrer', user.id);

        // Get referral used by user
        const { data: referralUsed } = await supabaseAdmin
          .from('referrals')
          .select('referrer, code_used, created_at')
          .eq('referred', user.id)
          .single();

        // Get user's referral codes
        const { data: myCodes } = await supabaseAdmin
          .from('referral_codes')
          .select('code, invitee_gender_required, is_active, uses_remaining, created_at')
          .eq('created_by', user.id)
          .order('created_at', { ascending: false });

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              entry_status: entryStatus,
              referrals_made: referralsMade?.map(r => ({
                id: r.id,
                referred_verified: !!r.referred_verified_at,
                created_at: r.created_at,
              })),
              referral_used: referralUsed,
              my_codes: myCodes,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

  } catch (error) {
    console.error('Referrals error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
