// ============================================================================
// GATING EDGE FUNCTION
// Returns what actions a user can perform based on verification & entry status
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface GatingStatus {
  isVerified: boolean;
  isEntryApproved: boolean;
  canLike: boolean;
  canSchedule: boolean;
  canChat: boolean;
  canMeetup: boolean;
  canPost: boolean;
  verification: {
    photosApproved: number;
    photosRequired: number;
    instagramVerified: boolean;
    genderVerified: boolean;
    overallStatus: string;
  };
  entry: {
    referralsVerified: number;
    referralsRequired: number;
    status: string;
  };
  restrictions: {
    isLimited: boolean;
    isBanned: boolean;
    reason: string | null;
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get auth token from request
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client with user's token
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    // Get current user
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userId = user.id;

    // Use service role for reading all required data
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Fetch all gating data in parallel
    const [
      verificationResult,
      entryResult,
      scoreResult,
      configResult,
      instagramResult,
      genderResult,
      photosResult,
    ] = await Promise.all([
      supabaseAdmin.from('verifications').select('*').eq('user_id', userId).single(),
      supabaseAdmin.from('entry_status').select('*').eq('user_id', userId).single(),
      supabaseAdmin.from('user_scores').select('*').eq('user_id', userId).single(),
      supabaseAdmin.from('config').select('key, value').in('key', ['bootstrap_mode_enabled']),
      supabaseAdmin.from('instagram').select('ig_media_verified').eq('user_id', userId).single(),
      supabaseAdmin.from('gender_verification').select('status').eq('user_id', userId).single(),
      supabaseAdmin.from('photos').select('approved, face_visible').eq('user_id', userId),
    ]);

    // Parse config
    const bootstrapMode = configResult.data?.find(c => c.key === 'bootstrap_mode_enabled')?.value === true ||
                          configResult.data?.find(c => c.key === 'bootstrap_mode_enabled')?.value === 'true';

    // Calculate photo stats
    const approvedPhotos = photosResult.data?.filter(p => p.approved && p.face_visible).length ?? 0;
    const photosRequired = 3;

    // Determine verification status
    const verification = verificationResult.data;
    const isVerified = verification?.status === 'approved';

    // Determine entry status
    const entry = entryResult.data;
    const isEntryApproved = entry?.status === 'approved' || entry?.admin_override || bootstrapMode;

    // Determine restrictions
    const score = scoreResult.data;
    const isBanned = score?.status === 'banned';
    const isLimited = score?.status === 'limited';

    // Build gating status
    const gatingStatus: GatingStatus = {
      isVerified,
      isEntryApproved,
      canLike: isVerified && isEntryApproved && !isBanned,
      canSchedule: isVerified && isEntryApproved && !isBanned,
      canChat: isVerified && isEntryApproved && !isBanned,
      canMeetup: isVerified && isEntryApproved && !isBanned,
      canPost: isVerified && isEntryApproved && !isBanned,
      verification: {
        photosApproved: approvedPhotos,
        photosRequired,
        instagramVerified: instagramResult.data?.ig_media_verified ?? false,
        genderVerified: genderResult.data?.status === 'approved',
        overallStatus: verification?.status ?? 'pending',
      },
      entry: {
        referralsVerified: entry?.verified_opposite_gender_count ?? 0,
        referralsRequired: entry?.required_opposite_gender ?? 1,
        status: entry?.status ?? 'pending',
      },
      restrictions: {
        isLimited,
        isBanned,
        reason: score?.ban_reason ?? null,
      },
    };

    return new Response(
      JSON.stringify({ success: true, data: gatingStatus }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Gating error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
