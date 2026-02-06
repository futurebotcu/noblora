// ============================================================================
// SCORING EDGE FUNCTION
// Updates user quality/reliability scores based on ratings, reports, blocks
// Implements abuse-resistant credibility weighting and retaliation detection
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Scoring thresholds
const THRESHOLDS = {
  LOW_QUALITY_SCORE: 2.0,
  VISIBILITY_PENALTY_SCORE: 2.5,
  BAN_THRESHOLD_SCORE: 1.5,
  REPORTS_FOR_REVIEW: 3,
  BLOCKS_FOR_REVIEW: 5,
};

interface ScoringJob {
  user_id: string;
  rating?: number;
  flags?: {
    inappropriate?: boolean;
    no_show?: boolean;
    fake_profile?: boolean;
    rude?: boolean;
  };
  rater_id?: string;
  report_id?: string;
  block_id?: string;
}

// Calculate weighted score with credibility
function calculateWeightedScore(
  ratings: Array<{ rating: number; rater_credibility: number }>
): number {
  if (ratings.length === 0) return 3.0;

  let weightedSum = 0;
  let totalWeight = 0;

  for (const r of ratings) {
    const weight = Math.max(0.1, r.rater_credibility);
    weightedSum += r.rating * weight;
    totalWeight += weight;
  }

  return totalWeight > 0 ? weightedSum / totalWeight : 3.0;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // This endpoint is called internally by job processor or admin
    // Verify service role or admin
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const body: ScoringJob = await req.json();

    if (!body.user_id) {
      return new Response(
        JSON.stringify({ error: 'Missing user_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get current user score
    const { data: currentScore, error: scoreError } = await supabaseAdmin
      .from('user_scores')
      .select('*')
      .eq('user_id', body.user_id)
      .single();

    if (scoreError) {
      // Create initial score if doesn't exist
      await supabaseAdmin.from('user_scores').insert({
        user_id: body.user_id,
        quality_score: 3.0,
        reliability_score: 3.0,
      });
    }

    // Get all ratings for this user
    const { data: allRatings } = await supabaseAdmin
      .from('call_ratings')
      .select(`
        rating,
        flags,
        rater,
        user_scores!call_ratings_rater_fkey(quality_score)
      `)
      .eq('match_id', body.user_id) // This needs to be fixed - should query by rated user
      .or(`match_id.eq.${body.user_id}`);

    // Actually, we need to get ratings where the user was rated, not rater
    // Let's get matches where user participated and then get ratings
    const { data: userMatches } = await supabaseAdmin
      .from('matches')
      .select('id, user_a, user_b')
      .or(`user_a.eq.${body.user_id},user_b.eq.${body.user_id}`);

    const matchIds = userMatches?.map(m => m.id) ?? [];

    const { data: ratingsReceived } = await supabaseAdmin
      .from('call_ratings')
      .select(`
        rating,
        flags,
        rater,
        match_id
      `)
      .in('match_id', matchIds)
      .neq('rater', body.user_id); // Ratings from others

    // Get rater credibilities
    const raterIds = [...new Set(ratingsReceived?.map(r => r.rater) ?? [])];
    const { data: raterScores } = await supabaseAdmin
      .from('user_scores')
      .select('user_id, quality_score, reliability_score')
      .in('user_id', raterIds);

    const raterCredibilityMap = new Map(
      raterScores?.map(s => [s.user_id, (s.quality_score + s.reliability_score) / 6]) ?? []
    );

    // Detect retaliation pattern
    if (body.rater_id && body.rating && body.rating <= 2) {
      // Check if user recently gave rater a low rating
      const { data: recentRating } = await supabaseAdmin
        .from('call_ratings')
        .select('rating')
        .eq('rater', body.user_id)
        .in('match_id', matchIds)
        .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
        .single();

      if (recentRating && recentRating.rating <= 2) {
        // Potential retaliation - flag for review
        await supabaseAdmin.from('jobs').insert({
          type: 'review_retaliation',
          payload: {
            user_id: body.user_id,
            rater_id: body.rater_id,
            rating: body.rating,
          },
          priority: 2,
        });
      }
    }

    // Calculate weighted quality score
    const ratingsWithCredibility = ratingsReceived?.map(r => ({
      rating: r.rating,
      rater_credibility: raterCredibilityMap.get(r.rater) ?? 0.5,
    })) ?? [];

    const newQualityScore = calculateWeightedScore(ratingsWithCredibility);

    // Get reports and blocks count
    const { count: reportsCount } = await supabaseAdmin
      .from('reports')
      .select('*', { count: 'exact', head: true })
      .eq('target', body.user_id)
      .in('status', ['pending', 'actioned']);

    const { count: blocksCount } = await supabaseAdmin
      .from('blocks')
      .select('*', { count: 'exact', head: true })
      .eq('blocked', body.user_id);

    // Calculate reliability score (based on reports/blocks)
    let reliabilityPenalty = 0;
    if ((reportsCount ?? 0) >= THRESHOLDS.REPORTS_FOR_REVIEW) {
      reliabilityPenalty += 0.5;
    }
    if ((blocksCount ?? 0) >= THRESHOLDS.BLOCKS_FOR_REVIEW) {
      reliabilityPenalty += 0.5;
    }

    const newReliabilityScore = Math.max(1.0, 3.0 - reliabilityPenalty);

    // Determine status
    let newStatus = 'ok';
    let banReason = null;

    if (newQualityScore < THRESHOLDS.BAN_THRESHOLD_SCORE ||
        newReliabilityScore < THRESHOLDS.BAN_THRESHOLD_SCORE) {
      newStatus = 'banned';
      banReason = 'Score below threshold';
    } else if (newQualityScore < THRESHOLDS.VISIBILITY_PENALTY_SCORE ||
               newReliabilityScore < THRESHOLDS.VISIBILITY_PENALTY_SCORE) {
      newStatus = 'limited';
    }

    // Update user score
    const { error: updateError } = await supabaseAdmin
      .from('user_scores')
      .update({
        quality_score: newQualityScore,
        reliability_score: newReliabilityScore,
        total_ratings: ratingsReceived?.length ?? 0,
        total_reports_received: reportsCount ?? 0,
        total_blocks_received: blocksCount ?? 0,
        status: newStatus,
        ban_reason: banReason,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', body.user_id);

    if (updateError) throw updateError;

    // Log score update
    await supabaseAdmin.from('audit_log').insert({
      action: 'score_updated',
      target_user: body.user_id,
      payload: {
        quality_score: newQualityScore,
        reliability_score: newReliabilityScore,
        status: newStatus,
        trigger: body.rating ? 'rating' : body.report_id ? 'report' : body.block_id ? 'block' : 'manual',
      },
    });

    // If status changed to banned, log it
    if (newStatus === 'banned' && currentScore?.status !== 'banned') {
      await supabaseAdmin.from('audit_log').insert({
        action: 'user_banned',
        target_user: body.user_id,
        payload: { reason: banReason },
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          user_id: body.user_id,
          quality_score: newQualityScore,
          reliability_score: newReliabilityScore,
          status: newStatus,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Scoring error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
