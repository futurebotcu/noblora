// ============================================================================
// VERIFY PHOTO EDGE FUNCTION
// Analyzes uploaded photos using AI provider for face detection & quality
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface PhotoAnalysisResult {
  faceDetected: boolean;
  faceCount: number;
  faceVisible: boolean;
  qualityScore: number;
  isAppropriate: boolean;
  confidence: number;
}

// Mock AI analysis - replace with real provider in production
async function analyzePhoto(imageUrl: string): Promise<PhotoAnalysisResult> {
  // Simulate API latency
  await new Promise(resolve => setTimeout(resolve, 200));

  // Generate deterministic results based on URL hash
  const hash = imageUrl.split('').reduce((a, b) => {
    a = ((a << 5) - a) + b.charCodeAt(0);
    return a & a;
  }, 0);

  const absHash = Math.abs(hash);

  return {
    faceDetected: absHash % 10 < 8,
    faceCount: absHash % 10 < 8 ? 1 : 0,
    faceVisible: absHash % 10 < 7,
    qualityScore: 50 + (absHash % 50),
    isAppropriate: true,
    confidence: 0.85 + (absHash % 15) / 100,
  };
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

    // Parse request body
    const { photo_id } = await req.json();
    if (!photo_id) {
      return new Response(
        JSON.stringify({ error: 'Missing photo_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify user owns this photo
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

    // Get photo with service role
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: photo, error: photoError } = await supabaseAdmin
      .from('photos')
      .select('*')
      .eq('id', photo_id)
      .single();

    if (photoError || !photo) {
      return new Response(
        JSON.stringify({ error: 'Photo not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify ownership
    if (photo.user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'Not authorized' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Analyze photo
    const analysis = await analyzePhoto(photo.url);

    // Get quality threshold from config
    const { data: config } = await supabaseAdmin
      .from('config')
      .select('value')
      .eq('key', 'photo_min_quality')
      .single();

    const minQuality = parseInt(config?.value ?? '60', 10);

    // Determine if approved
    const approved = analysis.faceDetected &&
                     analysis.faceVisible &&
                     analysis.qualityScore >= minQuality &&
                     analysis.isAppropriate;

    // Update photo record
    const { error: updateError } = await supabaseAdmin
      .from('photos')
      .update({
        face_visible: analysis.faceVisible,
        quality_score: analysis.qualityScore,
        approved,
      })
      .eq('id', photo_id);

    if (updateError) {
      throw updateError;
    }

    // Create job to update verification status
    await supabaseAdmin.from('jobs').insert({
      type: 'update_verification_status',
      payload: { user_id: user.id },
      priority: 1,
    });

    // Log action
    await supabaseAdmin.from('audit_log').insert({
      action: approved ? 'photo_verified' : 'photo_rejected',
      target_user: user.id,
      payload: {
        photo_id,
        analysis,
        approved,
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          photo_id,
          approved,
          analysis,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Photo verification error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
