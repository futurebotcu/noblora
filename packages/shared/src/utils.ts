// ============================================================================
// NOBLARA UTILITIES
// ============================================================================

import { MATCH_TIMING, REFERRAL_RULES, PHOTO_RULES } from './constants';
import type { Gender, VerificationStatus, EntryStatus } from './types';

// ============================================================================
// DATE/TIME UTILITIES
// ============================================================================

/**
 * Calculate the schedule-only window deadline (12h after match)
 */
export function getScheduleDeadline(matchCreatedAt: Date | string): Date {
  const matchDate = new Date(matchCreatedAt);
  return new Date(matchDate.getTime() + MATCH_TIMING.SCHEDULE_ONLY_WINDOW_HOURS * 60 * 60 * 1000);
}

/**
 * Calculate the meetup deadline (5 days after call)
 */
export function getMeetupDeadline(callEndedAt: Date | string): Date {
  const callDate = new Date(callEndedAt);
  return new Date(callDate.getTime() + MATCH_TIMING.MEETUP_DEADLINE_DAYS * 24 * 60 * 60 * 1000);
}

/**
 * Check if we're still in the schedule-only window
 */
export function isInScheduleWindow(scheduleDeadline: Date | string): boolean {
  return new Date() < new Date(scheduleDeadline);
}

/**
 * Check if meetup deadline has passed
 */
export function hasMeetupDeadlinePassed(meetupDeadline: Date | string | null): boolean {
  if (!meetupDeadline) return false;
  return new Date() > new Date(meetupDeadline);
}

/**
 * Format duration in seconds to MM:SS
 */
export function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

/**
 * Get relative time string (e.g., "2 hours ago")
 */
export function getRelativeTime(date: Date | string): string {
  const now = new Date();
  const then = new Date(date);
  const diffMs = now.getTime() - then.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);

  if (diffDay > 0) return `${diffDay}d ago`;
  if (diffHour > 0) return `${diffHour}h ago`;
  if (diffMin > 0) return `${diffMin}m ago`;
  return 'just now';
}

// ============================================================================
// REFERRAL CODE UTILITIES
// ============================================================================

/**
 * Generate a random referral code
 */
export function generateReferralCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed ambiguous chars
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Get the required referral gender for a user
 */
export function getRequiredReferralGender(userGender: Gender): Gender {
  switch (userGender) {
    case 'male':
      return 'female';
    case 'female':
      return 'male';
    case 'other':
      return 'other'; // For 'other', we allow either gender
  }
}

/**
 * Check if referral requirement is met
 */
export function isReferralRequirementMet(verifiedCount: number): boolean {
  return verifiedCount >= REFERRAL_RULES.REQUIRED_OPPOSITE_GENDER_REFERRALS;
}

// ============================================================================
// VERIFICATION UTILITIES
// ============================================================================

/**
 * Check if photo requirements are met
 */
export function arePhotoRequirementsMet(
  approvedPhotos: number,
  allHaveFaceVisible: boolean
): boolean {
  return approvedPhotos >= PHOTO_RULES.MIN_PHOTOS && allHaveFaceVisible;
}

/**
 * Calculate overall verification status
 */
export function calculateVerificationStatus(
  photosApproved: number,
  photosFaceVisible: boolean,
  instagramVerified: boolean,
  genderVerified: boolean
): VerificationStatus {
  const photosOk = arePhotoRequirementsMet(photosApproved, photosFaceVisible);

  if (photosOk && instagramVerified && genderVerified) {
    return 'approved';
  }

  // Check if any component is rejected
  // This would need actual rejection flags from DB
  return 'pending';
}

/**
 * Calculate entry status based on referral count
 */
export function calculateEntryStatus(
  verifiedOppositeGenderCount: number,
  required: number = REFERRAL_RULES.REQUIRED_OPPOSITE_GENDER_REFERRALS
): EntryStatus {
  if (verifiedOppositeGenderCount >= required) {
    return 'approved';
  }
  return 'pending';
}

// ============================================================================
// QR CODE UTILITIES
// ============================================================================

/**
 * Generate a secure QR check-in token
 */
export function generateQrToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let token = '';
  for (let i = 0; i < 48; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}

/**
 * Hash a token for storage (simple hash - use bcrypt/argon2 in production)
 */
export async function hashToken(token: string): Promise<string> {
  // In production, use a proper crypto library
  // This is a placeholder using Web Crypto API
  if (typeof crypto !== 'undefined' && crypto.subtle) {
    const encoder = new TextEncoder();
    const data = encoder.encode(token);
    const hash = await crypto.subtle.digest('SHA-256', data);
    return Array.from(new Uint8Array(hash))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }
  // Fallback for environments without crypto
  return token; // NOT SECURE - only for dev
}

// ============================================================================
// SCORING UTILITIES
// ============================================================================

/**
 * Calculate weighted average rating with credibility
 */
export function calculateWeightedScore(
  ratings: Array<{ rating: number; raterCredibility: number }>
): number {
  if (ratings.length === 0) return 3.0; // Default neutral score

  let weightedSum = 0;
  let totalWeight = 0;

  for (const r of ratings) {
    const weight = Math.max(0.1, r.raterCredibility);
    weightedSum += r.rating * weight;
    totalWeight += weight;
  }

  return totalWeight > 0 ? weightedSum / totalWeight : 3.0;
}

/**
 * Detect potential retaliation pattern
 */
export function detectRetaliationPattern(
  raterLowRatings: number,
  raterReceivedLowFromTarget: boolean
): boolean {
  // If rater frequently gives low ratings and just received a low rating from target
  return raterLowRatings > 3 && raterReceivedLowFromTarget;
}

// ============================================================================
// DISTANCE UTILITIES
// ============================================================================

/**
 * Calculate distance between two coordinates in kilometers (Haversine formula)
 */
export function calculateDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg: number): number {
  return deg * (Math.PI / 180);
}

// ============================================================================
// TEXT UTILITIES
// ============================================================================

/**
 * Sanitize user input text
 */
export function sanitizeText(text: string): string {
  return text
    .trim()
    .replace(/[\u0000-\u001F\u007F-\u009F]/g, '') // Remove control characters
    .substring(0, 10000); // Reasonable max length
}

/**
 * Check if text contains inappropriate content (basic check)
 */
export function containsBlockedContent(text: string): boolean {
  // This is a placeholder - use a proper content moderation service in production
  const blocked = ['spam', 'scam', 'http://', 'https://', 'whatsapp', 'telegram'];
  const lowerText = text.toLowerCase();
  return blocked.some(word => lowerText.includes(word));
}

// ============================================================================
// ID UTILITIES
// ============================================================================

/**
 * Generate a simple idempotency key
 */
export function generateIdempotencyKey(
  userId: string,
  action: string,
  timestamp?: number
): string {
  const ts = timestamp ?? Date.now();
  return `${userId}:${action}:${ts}`;
}

/**
 * Extract user IDs from a match (ordered)
 */
export function getMatchUserIds(_matchId: string, userA: string, userB: string): [string, string] {
  // Always return in consistent order
  return userA < userB ? [userA, userB] : [userB, userA];
}

// ============================================================================
// CALL UTILITIES
// ============================================================================

/**
 * Check if call duration meets minimum requirement
 */
export function isCallComplete(durationSec: number): boolean {
  return durationSec >= MATCH_TIMING.VIDEO_CALL_MIN_DURATION_SEC;
}

/**
 * Check if call should be force-ended
 */
export function shouldForceEndCall(durationSec: number): boolean {
  return durationSec >= MATCH_TIMING.VIDEO_CALL_MAX_DURATION_SEC;
}

/**
 * Get remaining call time
 */
export function getRemainingCallTime(durationSec: number): number {
  return Math.max(0, MATCH_TIMING.VIDEO_CALL_MAX_DURATION_SEC - durationSec);
}
