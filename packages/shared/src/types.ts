// ============================================================================
// NOBLARA TYPE DEFINITIONS
// ============================================================================

import {
  MODES,
  GENDERS,
  VERIFICATION_STATUS,
  ENTRY_STATUS,
  SCORE_STATUS,
  SUBSCRIPTION_TIERS,
  ERROR_CODES,
  AUDIT_ACTIONS,
} from './constants';

// ============================================================================
// ENUMS / UNION TYPES
// ============================================================================

export type Mode = (typeof MODES)[keyof typeof MODES];
export type Gender = (typeof GENDERS)[keyof typeof GENDERS];
export type VerificationStatus = (typeof VERIFICATION_STATUS)[keyof typeof VERIFICATION_STATUS];
export type EntryStatus = (typeof ENTRY_STATUS)[keyof typeof ENTRY_STATUS];
export type ScoreStatus = (typeof SCORE_STATUS)[keyof typeof SCORE_STATUS];
export type SubscriptionTier = (typeof SUBSCRIPTION_TIERS)[keyof typeof SUBSCRIPTION_TIERS];
export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES];
export type AuditAction = (typeof AUDIT_ACTIONS)[keyof typeof AUDIT_ACTIONS];

// ============================================================================
// DATABASE ENTITY TYPES
// ============================================================================

// Profile
export interface Profile {
  user_id: string;
  mode: Mode;
  gender_claim: Gender;
  birth_year: number;
  city: string | null;
  bio: string | null;
  latitude: number | null;
  longitude: number | null;
  created_at: string;
  updated_at: string;
}

// Photo
export interface Photo {
  id: string;
  user_id: string;
  url: string;
  order_index: number;
  face_visible: boolean;
  quality_score: number;
  approved: boolean;
  created_at: string;
}

// Instagram
export interface Instagram {
  user_id: string;
  ig_username: string;
  ig_connected: boolean;
  ig_connected_at: string | null;
  ig_media_verified: boolean;
  ig_verified_at: string | null;
  oldest_face_media_ts: string | null;
}

// Gender Verification
export interface GenderVerification {
  user_id: string;
  status: VerificationStatus;
  reason: string | null;
  evidence_url: string | null;
  submitted_at: string;
  reviewed_at: string | null;
}

// Verification (overall status)
export interface Verification {
  user_id: string;
  status: VerificationStatus;
  reason: string | null;
  updated_at: string;
}

// Referral Code
export interface ReferralCode {
  code: string;
  created_by: string;
  inviter_gender: Gender;
  invitee_gender_required: Gender;
  created_at: string;
  is_active: boolean;
}

// Referral
export interface Referral {
  id: string;
  referrer: string;
  referred: string;
  created_at: string;
  referred_verified_at: string | null;
}

// Entry Status
export interface EntryStatusRecord {
  user_id: string;
  status: EntryStatus;
  required_opposite_gender: number;
  verified_opposite_gender_count: number;
  updated_at: string;
}

// Like
export interface Like {
  id: string;
  from_user: string;
  to_user: string;
  mode: Mode;
  created_at: string;
}

// Match
export interface Match {
  id: string;
  user_a: string;
  user_b: string;
  mode: Mode;
  created_at: string;
}

// Match State
export interface MatchState {
  match_id: string;
  schedule_deadline: string;
  call_required: boolean;
  call_completed: boolean;
  call_started_at: string | null;
  call_ended_at: string | null;
  call_duration_sec: number | null;
  chat_unlocked: boolean;
  meetup_deadline: string | null;
  closed: boolean;
}

// Call Proposal
export interface CallProposal {
  id: string;
  match_id: string;
  proposer: string;
  slots: TimeSlot[];
  created_at: string;
  expires_at: string;
}

export interface TimeSlot {
  start: string; // ISO timestamp
  end: string;
}

// Call Booking
export interface CallBooking {
  id: string;
  match_id: string;
  scheduled_at: string;
  duration_sec: number;
  created_at: string;
}

// Call Rating
export interface CallRating {
  id: string;
  match_id: string;
  rater: string;
  rating: number; // 1-5
  flags: RatingFlags | null;
  created_at: string;
}

export interface RatingFlags {
  inappropriate?: boolean;
  no_show?: boolean;
  fake_profile?: boolean;
  rude?: boolean;
  other?: string;
}

// Message
export interface Message {
  id: string;
  match_id: string;
  from_user: string;
  body: string;
  created_at: string;
}

// Block
export interface Block {
  id: string;
  blocker: string;
  blocked: string;
  created_at: string;
}

// Report
export interface Report {
  id: string;
  reporter: string;
  target: string;
  reason: string;
  evidence_urls: string[] | null;
  status: 'pending' | 'reviewed' | 'actioned' | 'dismissed';
  created_at: string;
  reviewed_at: string | null;
}

// Meetup
export interface Meetup {
  id: string;
  match_id: string;
  scheduled_at: string;
  location_text: string | null;
  created_at: string;
}

// QR Check-in
export interface QrCheckin {
  id: string;
  meetup_id: string;
  user_id: string;
  token_hash: string;
  checked_in_at: string;
}

// Meetup Event
export interface MeetupEvent {
  id: string;
  meetup_id: string;
  event_type: 'scheduled' | 'checkin' | 'completed' | 'cancelled';
  payload: Record<string, unknown> | null;
  created_at: string;
}

// Post
export interface Post {
  id: string;
  user_id: string;
  body: string;
  created_at: string;
  day_key: string; // YYYY-MM-DD
}

// Post Report
export interface PostReport {
  id: string;
  reporter: string;
  post_id: string;
  reason: string;
  created_at: string;
}

// Subscription
export interface Subscription {
  user_id: string;
  tier: SubscriptionTier;
  expires_at: string | null;
  updated_at: string;
}

// User Score
export interface UserScore {
  user_id: string;
  quality_score: number;
  reliability_score: number;
  status: ScoreStatus;
  ban_reason: string | null;
  updated_at: string;
}

// Audit Log
export interface AuditLog {
  id: string;
  actor: string | null;
  action: AuditAction;
  target_user: string | null;
  payload: Record<string, unknown> | null;
  created_at: string;
}

// Config
export interface Config {
  key: string;
  value: unknown;
  updated_at: string;
}

// ============================================================================
// API TYPES
// ============================================================================

// User Gating Status (returned by gating edge function)
export interface GatingStatus {
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
    overallStatus: VerificationStatus;
  };
  entry: {
    referralsVerified: number;
    referralsRequired: number;
    status: EntryStatus;
  };
  restrictions: {
    isLimited: boolean;
    isBanned: boolean;
    reason: string | null;
  };
}

// Profile Card (for feed display)
export interface ProfileCard {
  user_id: string;
  bio: string | null;
  age: number;
  city: string | null;
  distance_km: number | null;
  photos: string[];
  instagram_verified: boolean;
  mode: Mode;
}

// Match Detail
export interface MatchDetail {
  match: Match;
  state: MatchState;
  other_user: ProfileCard;
  can_schedule: boolean;
  can_call: boolean;
  can_chat: boolean;
  can_meetup: boolean;
}

// Chat Thread
export interface ChatThread {
  match_id: string;
  other_user: ProfileCard;
  last_message: Message | null;
  unread_count: number;
}

// API Response wrapper
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: ErrorCode;
    message: string;
  };
}

// Pagination
export interface PaginatedResponse<T> {
  items: T[];
  cursor: string | null;
  has_more: boolean;
}

// ============================================================================
// INPUT TYPES
// ============================================================================

export interface CreateProfileInput {
  mode: Mode;
  gender_claim: Gender;
  birth_year: number;
  city?: string;
  bio?: string;
}

export interface UpdateProfileInput {
  mode?: Mode;
  city?: string;
  bio?: string;
  latitude?: number;
  longitude?: number;
}

export interface CreateReferralCodeInput {
  invitee_gender_required: Gender;
}

export interface RedeemReferralCodeInput {
  code: string;
}

export interface ScheduleCallInput {
  match_id: string;
  slots: TimeSlot[];
}

export interface AcceptCallInput {
  match_id: string;
  proposal_id: string;
  selected_slot: TimeSlot;
}

export interface RateCallInput {
  match_id: string;
  rating: number;
  flags?: RatingFlags;
}

export interface PostCallDecisionInput {
  match_id: string;
  continue_match: boolean;
}

export interface SendMessageInput {
  match_id: string;
  body: string;
}

export interface ScheduleMeetupInput {
  match_id: string;
  scheduled_at: string;
  location_text?: string;
}

export interface QrCheckinInput {
  meetup_id: string;
  token: string;
}

export interface CreatePostInput {
  body: string;
}

export interface ReportInput {
  target: string;
  reason: string;
  evidence_urls?: string[];
}

export interface ReportPostInput {
  post_id: string;
  reason: string;
}

// Filter inputs
export interface FeedFilters {
  mode: Mode;
  min_age?: number;
  max_age?: number;
  max_distance_km?: number;
  cursor?: string;
  limit?: number;
}

// ============================================================================
// ADMIN TYPES
// ============================================================================

export interface AdminVerificationQueue {
  type: 'photo' | 'instagram' | 'gender';
  items: AdminVerificationItem[];
  total: number;
}

export interface AdminVerificationItem {
  user_id: string;
  submitted_at: string;
  evidence_url?: string;
  profile: Profile;
  photos?: Photo[];
}

export interface AdminUserDetail {
  profile: Profile;
  photos: Photo[];
  instagram: Instagram | null;
  gender_verification: GenderVerification | null;
  verification: Verification | null;
  entry_status: EntryStatusRecord | null;
  score: UserScore | null;
  subscription: Subscription | null;
  referrals_made: Referral[];
  referral_used: Referral | null;
  reports_received: Report[];
  reports_made: Report[];
  blocks_received: number;
  recent_audit_logs: AuditLog[];
}

export interface AdminAction {
  action:
    | 'approve_photo'
    | 'reject_photo'
    | 'approve_instagram'
    | 'reject_instagram'
    | 'approve_gender'
    | 'reject_gender'
    | 'approve_verification'
    | 'reject_verification'
    | 'approve_entry'
    | 'reject_entry'
    | 'limit_user'
    | 'ban_user'
    | 'unban_user'
    | 'shadowban_user';
  target_user: string;
  reason?: string;
}

export interface AdminConfigUpdate {
  key: string;
  value: unknown;
}
