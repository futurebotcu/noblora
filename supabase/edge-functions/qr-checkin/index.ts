// ============================================================================
// QR CHECK-IN EDGE FUNCTION
// Handles meetup QR code generation and mutual scan verification
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type Action = 'generate' | 'scan' | 'get_status';

interface QrCheckinRequest {
  action: Action;
  meetup_id: string;
  token?: string; // For scan action
}

// Generate secure random token
function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let token = '';
  for (let i = 0; i < 48; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

// Simple hash function (use crypto in production)
async function hashToken(token: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
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

    const body: QrCheckinRequest = await req.json();

    if (!body.meetup_id) {
      return new Response(
        JSON.stringify({ error: 'Missing meetup_id' }),
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

    // Get meetup and verify participation
    const { data: meetup, error: meetupError } = await supabaseAdmin
      .from('meetups')
      .select('*, matches(*)')
      .eq('id', body.meetup_id)
      .single();

    if (meetupError || !meetup) {
      return new Response(
        JSON.stringify({ error: 'Meetup not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const match = meetup.matches;
    if (match.user_a !== user.id && match.user_b !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not a participant' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const otherUserId = match.user_a === user.id ? match.user_b : match.user_a;

    switch (body.action) {
      case 'generate': {
        // Check if already checked in
        const { data: existingCheckin } = await supabaseAdmin
          .from('qr_checkins')
          .select('id')
          .eq('meetup_id', body.meetup_id)
          .eq('user_id', user.id)
          .single();

        if (existingCheckin) {
          return new Response(
            JSON.stringify({ error: 'You have already checked in' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Generate token for this user
        const token = generateToken();
        const tokenHash = await hashToken(token);

        // Store token hash temporarily (will be validated on scan)
        // We use a simple approach: store in meetup_events
        await supabaseAdmin.from('meetup_events').insert({
          meetup_id: body.meetup_id,
          event_type: 'scheduled', // Reusing for token storage
          payload: {
            type: 'qr_token',
            user_id: user.id,
            token_hash: tokenHash,
            expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(), // 1 hour
          },
        });

        // The QR code should contain: meetup_id + token
        const qrData = JSON.stringify({
          meetup_id: body.meetup_id,
          token,
          user_id: user.id,
        });

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              qr_data: qrData,
              expires_in_sec: 3600,
              message: 'Show this QR code to your match',
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'scan': {
        if (!body.token) {
          return new Response(
            JSON.stringify({ error: 'Missing token' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Parse the scanned QR data
        let scannedData: { meetup_id: string; token: string; user_id: string };
        try {
          scannedData = JSON.parse(body.token);
        } catch {
          return new Response(
            JSON.stringify({ error: 'Invalid QR code format' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Verify meetup ID matches
        if (scannedData.meetup_id !== body.meetup_id) {
          return new Response(
            JSON.stringify({ error: 'QR code is for a different meetup' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Verify the scanned QR is from the other user
        if (scannedData.user_id !== otherUserId) {
          return new Response(
            JSON.stringify({ error: 'QR code is not from your match' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Verify token hash
        const scannedTokenHash = await hashToken(scannedData.token);
        const { data: tokenEvent } = await supabaseAdmin
          .from('meetup_events')
          .select('payload')
          .eq('meetup_id', body.meetup_id)
          .eq('payload->>type', 'qr_token')
          .eq('payload->>user_id', otherUserId)
          .eq('payload->>token_hash', scannedTokenHash)
          .single();

        if (!tokenEvent) {
          return new Response(
            JSON.stringify({ error: 'Invalid or expired QR code' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Check expiration
        const payload = tokenEvent.payload as { expires_at: string };
        if (new Date(payload.expires_at) < new Date()) {
          return new Response(
            JSON.stringify({ error: 'QR code has expired' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        // Record check-in for the scanner
        const { error: checkinError } = await supabaseAdmin
          .from('qr_checkins')
          .insert({
            meetup_id: body.meetup_id,
            user_id: user.id,
            token_hash: scannedTokenHash,
          });

        if (checkinError && !checkinError.message.includes('duplicate')) {
          throw checkinError;
        }

        // Also record for the scanned user (they showed their QR)
        await supabaseAdmin
          .from('qr_checkins')
          .upsert({
            meetup_id: body.meetup_id,
            user_id: otherUserId,
            token_hash: scannedTokenHash,
          });

        // Check if both have checked in
        const { data: checkins } = await supabaseAdmin
          .from('qr_checkins')
          .select('user_id')
          .eq('meetup_id', body.meetup_id);

        const bothCheckedIn = checkins?.length === 2;

        if (bothCheckedIn) {
          // Record meetup completion
          await supabaseAdmin.from('meetup_events').insert({
            meetup_id: body.meetup_id,
            event_type: 'completed',
            payload: { completed_at: new Date().toISOString() },
          });

          await supabaseAdmin.from('audit_log').insert({
            action: 'meetup_completed',
            payload: { meetup_id: body.meetup_id, match_id: meetup.match_id },
          });
        }

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              checked_in: true,
              both_checked_in: bothCheckedIn,
              message: bothCheckedIn
                ? 'Meetup confirmed! Both users have checked in.'
                : 'Check-in successful. Waiting for your match to check in.',
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_status':
      default: {
        // Get check-in status
        const { data: checkins } = await supabaseAdmin
          .from('qr_checkins')
          .select('user_id, checked_in_at')
          .eq('meetup_id', body.meetup_id);

        const myCheckin = checkins?.find(c => c.user_id === user.id);
        const otherCheckin = checkins?.find(c => c.user_id === otherUserId);
        const bothCheckedIn = !!myCheckin && !!otherCheckin;

        // Get completion event if exists
        const { data: completionEvent } = await supabaseAdmin
          .from('meetup_events')
          .select('payload')
          .eq('meetup_id', body.meetup_id)
          .eq('event_type', 'completed')
          .single();

        return new Response(
          JSON.stringify({
            success: true,
            data: {
              meetup,
              my_checkin: myCheckin,
              other_checkin: !!otherCheckin,
              both_checked_in: bothCheckedIn,
              meetup_completed: !!completionEvent,
            },
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

  } catch (error) {
    console.error('QR check-in error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
