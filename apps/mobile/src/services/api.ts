// ============================================================================
// API SERVICE
// Wrapper around Supabase edge functions with error handling
// ============================================================================

import { supabase, isMockMode } from './supabase';
import { captureException } from './sentry';
import type { GatingStatus, ApiResponse } from '@noblara/shared';

const EDGE_FUNCTION_BASE = '/functions/v1';

interface FetchOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: unknown;
  timeout?: number;
}

async function callEdgeFunction<T>(
  functionName: string,
  options: FetchOptions = {}
): Promise<ApiResponse<T>> {
  const { method = 'POST', body, timeout = 30000 } = options;

  // Mock mode returns mock data
  if (isMockMode()) {
    console.log(`[API Mock] ${functionName}`, body);
    return getMockResponse(functionName, body);
  }

  try {
    const { data: { session } } = await supabase.auth.getSession();

    if (!session) {
      return {
        success: false,
        error: { code: 'AUTH_REQUIRED', message: 'Not authenticated' },
      };
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const { data, error } = await supabase.functions.invoke(functionName, {
      body: body ? JSON.stringify(body) : undefined,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    clearTimeout(timeoutId);

    if (error) {
      throw error;
    }

    return data as ApiResponse<T>;
  } catch (error) {
    captureException(error as Error, { functionName, body });

    return {
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: (error as Error).message || 'An error occurred',
      },
    };
  }
}

// Mock responses for development without Supabase
function getMockResponse<T>(functionName: string, _body?: unknown): ApiResponse<T> {
  const mockData: Record<string, unknown> = {
    gating: {
      isVerified: false,
      isEntryApproved: false,
      canLike: false,
      canSchedule: false,
      canChat: false,
      canMeetup: false,
      canPost: false,
      verification: {
        photosApproved: 0,
        photosRequired: 3,
        instagramVerified: false,
        genderVerified: false,
        overallStatus: 'pending',
      },
      entry: {
        referralsVerified: 0,
        referralsRequired: 1,
        status: 'pending',
      },
      restrictions: {
        isLimited: false,
        isBanned: false,
        reason: null,
      },
    } as GatingStatus,
    'verify-photo': { approved: true, analysis: { faceVisible: true, qualityScore: 85 } },
    'verify-instagram': { status: 'pending_review' },
    'verify-gender': { status: 'pending' },
    referrals: { entry_status: { status: 'pending', verified_opposite_gender_count: 0 }, my_codes: [] },
  };

  return {
    success: true,
    data: mockData[functionName] as T,
  };
}

// ============================================================================
// API FUNCTIONS
// ============================================================================

export const api = {
  // Gating
  getGatingStatus: () => callEdgeFunction<GatingStatus>('gating'),

  // Photo verification
  verifyPhoto: (photoId: string) =>
    callEdgeFunction('verify-photo', { body: { photo_id: photoId } }),

  // Instagram verification
  connectInstagram: (params: { ig_username?: string; proof_image_url?: string; oauth_code?: string }) =>
    callEdgeFunction('verify-instagram', { body: params }),

  // Gender verification
  submitGenderVerification: (evidenceUrl: string) =>
    callEdgeFunction('verify-gender', { body: { evidence_url: evidenceUrl } }),

  // Referrals
  createReferralCode: (inviteeGender: string) =>
    callEdgeFunction('referrals', {
      body: { action: 'create_code', invitee_gender_required: inviteeGender },
    }),

  redeemReferralCode: (code: string) =>
    callEdgeFunction('referrals', { body: { action: 'redeem_code', code } }),

  getReferralStatus: () =>
    callEdgeFunction('referrals', { body: { action: 'get_status' } }),

  // Scheduling
  proposeCall: (matchId: string, slots: Array<{ start: string; end: string }>) =>
    callEdgeFunction('scheduling', { body: { action: 'propose', match_id: matchId, slots } }),

  acceptCallProposal: (matchId: string, proposalId: string, selectedSlot: { start: string; end: string }) =>
    callEdgeFunction('scheduling', {
      body: { action: 'accept', match_id: matchId, proposal_id: proposalId, selected_slot: selectedSlot },
    }),

  getSchedulingStatus: (matchId: string) =>
    callEdgeFunction('scheduling', { body: { action: 'get_status', match_id: matchId } }),

  // Calls
  startCall: (matchId: string, idempotencyKey?: string) =>
    callEdgeFunction('calls', { body: { action: 'start', match_id: matchId, idempotency_key: idempotencyKey } }),

  endCall: (matchId: string) =>
    callEdgeFunction('calls', { body: { action: 'end', match_id: matchId } }),

  callHeartbeat: (matchId: string) =>
    callEdgeFunction('calls', { body: { action: 'heartbeat', match_id: matchId } }),

  submitCallDecision: (matchId: string, continueMatch: boolean) =>
    callEdgeFunction('calls', { body: { action: 'decide', match_id: matchId, continue_match: continueMatch } }),

  rateCall: (matchId: string, rating: number, flags?: Record<string, boolean>) =>
    callEdgeFunction('calls', { body: { action: 'rate', match_id: matchId, rating, flags } }),

  getCallStatus: (matchId: string) =>
    callEdgeFunction('calls', { body: { action: 'get_status', match_id: matchId } }),

  // QR Check-in
  generateQrToken: (meetupId: string) =>
    callEdgeFunction('qr-checkin', { body: { action: 'generate', meetup_id: meetupId } }),

  scanQrCode: (meetupId: string, token: string) =>
    callEdgeFunction('qr-checkin', { body: { action: 'scan', meetup_id: meetupId, token } }),

  getCheckinStatus: (meetupId: string) =>
    callEdgeFunction('qr-checkin', { body: { action: 'get_status', meetup_id: meetupId } }),
};
