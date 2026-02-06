// ============================================================================
// CALLS EDGE FUNCTION
// Handles video call start/end, duration tracking, and post-call decisions
// Enforces: 3-5 minute call duration, chat unlock on mutual continue
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type Action = 'start' | 'end' | 'heartbeat' | 'decide' | 'rate' | 'get_status';

interface CallsRequest {
  action: Action;
  match_id: string;
  idempotency_key?: string;
  continue_match?: boolean; // For decide
  rating?: number; // For rate (1-5)
  flags?: {
    inappropriate?: boolean;
    no_show?: boolean;
    fake_profile?: boolean;
    rude?: boolean;
    other?: string;
  };
}

const MIN_CALL_DURATION = 180; // 3 minutes
const MAX_CALL_DURATION = 300; // 5 minutes

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

    const body: CallsRequest = await req.json();

    if (!body.match_id) {
      return new Response(
        JSON.stringify({ error: 'Missing match_id' }),
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

    // Get match and verify participation
    const { data: match, error: matchError } = await supabaseAdmin
      .from('matches')
      .select('*, match_state(*)')
      .eq('id', body.match_id)
      .single();

    if (matchError || !match) {
      return new Response(
        JSON.stringify({ error: 'Match not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (match.user_a !== user.id && match.user_b !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not a participant' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const matchState = match.match_state;
    const isUserA = match.user_a === user.id;

    switch (body.action) {
      case 'start': {
        // Idempotency check
        if (body.idempotency_key) {
          const { data: existing } = await supabaseAdmin
            .from('audit_log')
            .select('id')
            .eq('action', 'call_started')
            .eq('payload->>idempotency_key', body.idempotency_key)
            .single();

          if (existing) {
            return new Response(
              JSON.stringify({ success: true, data: { already_started: true } }),
              { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          }
        }

        // Check if call already started
        if (matchState.call_started_at) {
          return new Response(
            JSON.stringify({ error: 'Call already started' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check if booking exists
        const { data: booking } = await supabaseAdmin
          .from('call_bookings')
          .select('*')
          .eq('match_id', body.match_id)
          .single();

        if (!booking) {
          return new Response(
            JSON.stringify({ error: 'No call booking found. Schedule first.' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Start the call
        const { error: updateError } = await supabaseAdmin
          .from('match_state')
          .update({
            call_started_at: new Date().toISOString(),
          })
          .eq('match_id', body.match_id);

        if (updateError) throw updateError;

        // Log action
        await supabaseAdmin.from('audit_log').insert({
          actor: user.id,
          action: 'call_started',
          payload: { match_id: body.match_id, idempotency_key: body.idempotency_key },
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              started_at: new Date().toISOString(),
              max_duration_sec: MAX_CALL_DURATION,
              min_duration_sec: MIN_CALL_DURATION,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'end': {
        if (!matchState.call_started_at) {
          return new Response(
            JSON.stringify({ error: 'Call not started' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        if (matchState.call_ended_at) {
          return new Response(
            JSON.stringify({ error: 'Call already ended' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const startTime = new Date(matchState.call_started_at);
        const endTime = new Date();
        const durationSec = Math.floor((endTime.getTime() - startTime.getTime()) / 1000);

        // Enforce max duration
        const actualDuration = Math.min(durationSec, MAX_CALL_DURATION);
        const callCompleted = actualDuration >= MIN_CALL_DURATION;

        // Calculate meetup deadline (5 days from call end)
        const meetupDeadline = new Date(endTime.getTime() + 5 * 24 * 60 * 60 * 1000);

        const { error: updateError } = await supabaseAdmin
          .from('match_state')
          .update({
            call_ended_at: endTime.toISOString(),
            call_duration_sec: actualDuration,
            call_completed: callCompleted,
            meetup_deadline: meetupDeadline.toISOString(),
          })
          .eq('match_id', body.match_id);

        if (updateError) throw updateError;

        // Log action
        await supabaseAdmin.from('audit_log').insert({
          actor: user.id,
          action: 'call_ended',
          payload: {
            match_id: body.match_id,
            duration_sec: actualDuration,
            call_completed: callCompleted,
          },
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              duration_sec: actualDuration,
              call_completed: callCompleted,
              meetup_deadline: meetupDeadline.toISOString(),
              message: callCompleted
                ? 'Call completed. Both users must decide to continue.'
                : 'Call too short. Minimum 3 minutes required for chat unlock.',
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'heartbeat': {
        // Used to track ongoing call - client sends periodically
        if (!matchState.call_started_at || matchState.call_ended_at) {
          return new Response(
            JSON.stringify({ error: 'No active call' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const startTime = new Date(matchState.call_started_at);
        const elapsed = Math.floor((Date.now() - startTime.getTime()) / 1000);
        const shouldForceEnd = elapsed >= MAX_CALL_DURATION;

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              elapsed_sec: elapsed,
              remaining_sec: Math.max(0, MAX_CALL_DURATION - elapsed),
              should_force_end: shouldForceEnd,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'decide': {
        if (body.continue_match === undefined) {
          return new Response(
            JSON.stringify({ error: 'Missing continue_match decision' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        if (!matchState.call_completed) {
          return new Response(
            JSON.stringify({ error: 'Call not completed (min 3 minutes required)' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Update the appropriate user's decision
        const updateField = isUserA ? 'user_a_continue' : 'user_b_continue';
        const { error: updateError } = await supabaseAdmin
          .from('match_state')
          .update({ [updateField]: body.continue_match })
          .eq('match_id', body.match_id);

        if (updateError) throw updateError;

        // Check if both have decided
        const { data: updatedState } = await supabaseAdmin
          .from('match_state')
          .select('user_a_continue, user_b_continue')
          .eq('match_id', body.match_id)
          .single();

        const bothDecided = updatedState?.user_a_continue !== null &&
                           updatedState?.user_b_continue !== null;
        const bothContinue = updatedState?.user_a_continue === true &&
                            updatedState?.user_b_continue === true;

        if (bothDecided) {
          if (bothContinue) {
            // Unlock chat
            await supabaseAdmin
              .from('match_state')
              .update({ chat_unlocked: true })
              .eq('match_id', body.match_id);

            await supabaseAdmin.from('audit_log').insert({
              action: 'chat_unlocked',
              payload: { match_id: body.match_id },
            });
          } else {
            // Close match
            await supabaseAdmin
              .from('match_state')
              .update({
                closed: true,
                closed_reason: 'One or both users declined to continue',
              })
              .eq('match_id', body.match_id);

            await supabaseAdmin.from('audit_log').insert({
              action: 'match_closed',
              payload: { match_id: body.match_id, reason: 'user_declined' },
            });
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              your_decision: body.continue_match,
              both_decided: bothDecided,
              chat_unlocked: bothContinue,
              match_closed: bothDecided && !bothContinue,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'rate': {
        if (!body.rating || body.rating < 1 || body.rating > 5) {
          return new Response(
            JSON.stringify({ error: 'Rating must be between 1 and 5' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        if (!matchState.call_completed) {
          return new Response(
            JSON.stringify({ error: 'Cannot rate before call is completed' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check if already rated
        const { data: existingRating } = await supabaseAdmin
          .from('call_ratings')
          .select('id')
          .eq('match_id', body.match_id)
          .eq('rater', user.id)
          .single();

        if (existingRating) {
          return new Response(
            JSON.stringify({ error: 'You have already rated this call' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Create rating
        const { error: ratingError } = await supabaseAdmin
          .from('call_ratings')
          .insert({
            match_id: body.match_id,
            rater: user.id,
            rating: body.rating,
            flags: body.flags,
          });

        if (ratingError) throw ratingError;

        // Create job to update user scores
        const otherUserId = isUserA ? match.user_b : match.user_a;
        await supabaseAdmin.from('jobs').insert({
          type: 'update_user_score',
          payload: {
            user_id: otherUserId,
            rating: body.rating,
            flags: body.flags,
            rater_id: user.id,
          },
          priority: 1,
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: { message: 'Rating submitted' },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_status':
      default: {
        const { data: booking } = await supabaseAdmin
          .from('call_bookings')
          .select('*')
          .eq('match_id', body.match_id)
          .single();

        const { data: myRating } = await supabaseAdmin
          .from('call_ratings')
          .select('rating')
          .eq('match_id', body.match_id)
          .eq('rater', user.id)
          .single();

        let elapsedSec = null;
        let remainingSec = null;
        if (matchState.call_started_at && !matchState.call_ended_at) {
          const startTime = new Date(matchState.call_started_at);
          elapsedSec = Math.floor((Date.now() - startTime.getTime()) / 1000);
          remainingSec = Math.max(0, MAX_CALL_DURATION - elapsedSec);
        }

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              match_state: matchState,
              booking,
              call_active: !!matchState.call_started_at && !matchState.call_ended_at,
              elapsed_sec: elapsedSec,
              remaining_sec: remainingSec,
              min_duration_sec: MIN_CALL_DURATION,
              max_duration_sec: MAX_CALL_DURATION,
              your_decision: isUserA ? matchState.user_a_continue : matchState.user_b_continue,
              has_rated: !!myRating,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

  } catch (error) {
    console.error('Calls error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
