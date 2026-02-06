// ============================================================================
// SCHEDULING EDGE FUNCTION
// Handles call proposal and booking flow
// Enforces: 12h schedule-only window, women-first proposal rule
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type Action = 'propose' | 'accept' | 'get_status';

interface TimeSlot {
  start: string;
  end: string;
}

interface SchedulingRequest {
  action: Action;
  match_id: string;
  slots?: TimeSlot[]; // For propose
  proposal_id?: string; // For accept
  selected_slot?: TimeSlot; // For accept
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

    const body: SchedulingRequest = await req.json();

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

    // Verify user is match participant
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
        JSON.stringify({ error: 'Not a participant in this match' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const matchState = match.match_state;
    if (!matchState) {
      return new Response(
        JSON.stringify({ error: 'Match state not found' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if match is closed
    if (matchState.closed) {
      return new Response(
        JSON.stringify({ error: 'Match is closed' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get user's profile for gender check
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('gender_claim')
      .eq('user_id', user.id)
      .single();

    // Get config
    const { data: configs } = await supabaseAdmin
      .from('config')
      .select('key, value')
      .in('key', ['male_counter_proposal_enabled']);

    const maleCounterEnabled = configs?.find(c => c.key === 'male_counter_proposal_enabled')?.value === true ||
                               configs?.find(c => c.key === 'male_counter_proposal_enabled')?.value === 'true';

    switch (body.action) {
      case 'propose': {
        if (!body.slots || body.slots.length === 0) {
          return new Response(
            JSON.stringify({ error: 'At least one time slot is required' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check if in schedule window
        const scheduleDeadline = new Date(matchState.schedule_deadline);
        if (new Date() >= scheduleDeadline) {
          return new Response(
            JSON.stringify({ error: 'Schedule window has expired' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check women-first rule
        const { data: existingProposals } = await supabaseAdmin
          .from('call_proposals')
          .select('proposer, profiles!call_proposals_proposer_fkey(gender_claim)')
          .eq('match_id', body.match_id);

        const hasFemaleProposal = existingProposals?.some(
          p => (p.profiles as { gender_claim: string })?.gender_claim === 'female'
        );

        if (profile?.gender_claim === 'male' && !hasFemaleProposal && !maleCounterEnabled) {
          return new Response(
            JSON.stringify({ error: 'Women must propose first in this match' }),
            { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Create proposal
        const { data: proposal, error: proposalError } = await supabaseAdmin
          .from('call_proposals')
          .insert({
            match_id: body.match_id,
            proposer: user.id,
            slots: body.slots,
            expires_at: matchState.schedule_deadline,
          })
          .select()
          .single();

        if (proposalError) throw proposalError;

        // Log action
        await supabaseAdmin.from('audit_log').insert({
          actor: user.id,
          action: 'call_scheduled',
          payload: { match_id: body.match_id, proposal_id: proposal.id },
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: { proposal },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'accept': {
        if (!body.proposal_id || !body.selected_slot) {
          return new Response(
            JSON.stringify({ error: 'Missing proposal_id or selected_slot' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Get proposal
        const { data: proposal, error: proposalError } = await supabaseAdmin
          .from('call_proposals')
          .select('*')
          .eq('id', body.proposal_id)
          .eq('match_id', body.match_id)
          .single();

        if (proposalError || !proposal) {
          return new Response(
            JSON.stringify({ error: 'Proposal not found' }),
            { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Can't accept own proposal
        if (proposal.proposer === user.id) {
          return new Response(
            JSON.stringify({ error: 'Cannot accept your own proposal' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check if slot is valid
        const slots = proposal.slots as TimeSlot[];
        const isValidSlot = slots.some(
          s => s.start === body.selected_slot?.start && s.end === body.selected_slot?.end
        );

        if (!isValidSlot) {
          return new Response(
            JSON.stringify({ error: 'Selected slot is not in the proposal' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check if booking already exists
        const { data: existingBooking } = await supabaseAdmin
          .from('call_bookings')
          .select('id')
          .eq('match_id', body.match_id)
          .single();

        if (existingBooking) {
          return new Response(
            JSON.stringify({ error: 'Call already booked for this match' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Create booking
        const { data: booking, error: bookingError } = await supabaseAdmin
          .from('call_bookings')
          .insert({
            match_id: body.match_id,
            proposal_id: body.proposal_id,
            scheduled_at: body.selected_slot.start,
            duration_sec: 300, // 5 minutes max
          })
          .select()
          .single();

        if (bookingError) throw bookingError;

        // Mark proposal as accepted
        await supabaseAdmin
          .from('call_proposals')
          .update({ accepted: true })
          .eq('id', body.proposal_id);

        return new Response(
          JSON.stringify({
            success: true,
            data: { booking },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_status':
      default: {
        // Get all proposals for this match
        const { data: proposals } = await supabaseAdmin
          .from('call_proposals')
          .select('*')
          .eq('match_id', body.match_id)
          .order('created_at', { ascending: false });

        // Get booking if exists
        const { data: booking } = await supabaseAdmin
          .from('call_bookings')
          .select('*')
          .eq('match_id', body.match_id)
          .single();

        const now = new Date();
        const scheduleDeadline = new Date(matchState.schedule_deadline);

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              match_state: matchState,
              in_schedule_window: now < scheduleDeadline,
              time_remaining_ms: Math.max(0, scheduleDeadline.getTime() - now.getTime()),
              proposals,
              booking,
              can_propose: now < scheduleDeadline && !booking,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

  } catch (error) {
    console.error('Scheduling error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
