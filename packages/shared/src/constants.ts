// ============================================================================
// NOBLARA CONSTANTS
// ============================================================================

// Mode Types
export const MODES = {
  DATING: 'dating',
  BFF: 'bff',
} as const;

// Gender Types
export const GENDERS = {
  FEMALE: 'female',
  MALE: 'male',
  OTHER: 'other',
} as const;

// Verification Status
export const VERIFICATION_STATUS = {
  PENDING: 'pending',
  APPROVED: 'approved',
  REJECTED: 'rejected',
} as const;

// Entry Status
export const ENTRY_STATUS = {
  PENDING: 'pending',
  APPROVED: 'approved',
  REJECTED: 'rejected',
} as const;

// User Score Status
export const SCORE_STATUS = {
  OK: 'ok',
  LIMITED: 'limited',
  BANNED: 'banned',
} as const;

// Subscription Tiers
export const SUBSCRIPTION_TIERS = {
  FREE: 'free',
  PREMIUM: 'premium',
} as const;

// ============================================================================
// BUSINESS RULES - These are enforced server-side
// ============================================================================

// Photo Requirements
export const PHOTO_RULES = {
  MIN_PHOTOS: 3,
  MAX_PHOTOS: 6,
  MIN_QUALITY_SCORE: 60,
  FACE_VISIBLE_REQUIRED: true,
} as const;

// Referral Requirements
export const REFERRAL_RULES = {
  REQUIRED_OPPOSITE_GENDER_REFERRALS: 1,
} as const;

// Match Flow Timing
export const MATCH_TIMING = {
  SCHEDULE_ONLY_WINDOW_HOURS: 12,
  VIDEO_CALL_MIN_DURATION_SEC: 180, // 3 minutes
  VIDEO_CALL_MAX_DURATION_SEC: 300, // 5 minutes
  MEETUP_DEADLINE_DAYS: 5,
} as const;

// Social Posts
export const POST_RULES = {
  MAX_BODY_LENGTH: 150,
  POSTS_PER_DAY: 1,
} as const;

// Scoring Thresholds
export const SCORING_THRESHOLDS = {
  LOW_QUALITY_SCORE: 2.0,
  VISIBILITY_PENALTY_SCORE: 2.5,
  BAN_THRESHOLD_SCORE: 1.5,
  REPORTS_FOR_REVIEW: 3,
  BLOCKS_FOR_REVIEW: 5,
} as const;

// Rate Limiting
export const RATE_LIMITS = {
  AUTH_ATTEMPTS_PER_HOUR: 10,
  REFERRAL_CODES_PER_DAY: 5,
  CODE_REDEMPTIONS_PER_HOUR: 3,
  MESSAGES_PER_MINUTE: 20,
  LIKES_PER_HOUR: 100,
  REPORTS_PER_DAY: 10,
} as const;

// Filter Defaults
export const FILTER_DEFAULTS = {
  MIN_AGE: 18,
  MAX_AGE: 99,
  DEFAULT_AGE_RANGE: [18, 45] as const,
  DEFAULT_DISTANCE_KM: 50,
  MAX_DISTANCE_KM: 500,
} as const;

// API Response Codes
export const ERROR_CODES = {
  // Auth errors
  AUTH_REQUIRED: 'AUTH_REQUIRED',
  AUTH_INVALID: 'AUTH_INVALID',

  // Verification errors
  NOT_VERIFIED: 'NOT_VERIFIED',
  VERIFICATION_PENDING: 'VERIFICATION_PENDING',
  VERIFICATION_REJECTED: 'VERIFICATION_REJECTED',

  // Entry errors
  NOT_ENTRY_APPROVED: 'NOT_ENTRY_APPROVED',
  REFERRAL_REQUIRED: 'REFERRAL_REQUIRED',

  // Match errors
  SCHEDULE_WINDOW_ACTIVE: 'SCHEDULE_WINDOW_ACTIVE',
  CALL_NOT_COMPLETED: 'CALL_NOT_COMPLETED',
  CHAT_NOT_UNLOCKED: 'CHAT_NOT_UNLOCKED',
  MATCH_CLOSED: 'MATCH_CLOSED',
  MEETUP_DEADLINE_PASSED: 'MEETUP_DEADLINE_PASSED',

  // Permission errors
  BLOCKED: 'BLOCKED',
  BANNED: 'BANNED',
  RATE_LIMITED: 'RATE_LIMITED',

  // Validation errors
  INVALID_INPUT: 'INVALID_INPUT',
  ALREADY_EXISTS: 'ALREADY_EXISTS',
  NOT_FOUND: 'NOT_FOUND',

  // Server errors
  INTERNAL_ERROR: 'INTERNAL_ERROR',
} as const;

// Audit Log Actions
export const AUDIT_ACTIONS = {
  // User actions
  USER_CREATED: 'user_created',
  USER_UPDATED: 'user_updated',
  USER_DELETED: 'user_deleted',

  // Verification actions
  PHOTO_SUBMITTED: 'photo_submitted',
  PHOTO_VERIFIED: 'photo_verified',
  PHOTO_REJECTED: 'photo_rejected',
  IG_CONNECTED: 'ig_connected',
  IG_VERIFIED: 'ig_verified',
  IG_MANUAL_VERIFIED: 'ig_manual_verified',
  GENDER_SUBMITTED: 'gender_submitted',
  GENDER_VERIFIED: 'gender_verified',
  GENDER_REJECTED: 'gender_rejected',
  VERIFICATION_APPROVED: 'verification_approved',
  VERIFICATION_REJECTED: 'verification_rejected',

  // Entry actions
  REFERRAL_CODE_CREATED: 'referral_code_created',
  REFERRAL_CODE_REDEEMED: 'referral_code_redeemed',
  REFERRAL_VERIFIED: 'referral_verified',
  ENTRY_APPROVED: 'entry_approved',
  ENTRY_REJECTED: 'entry_rejected',

  // Match actions
  LIKE_SENT: 'like_sent',
  MATCH_CREATED: 'match_created',
  CALL_SCHEDULED: 'call_scheduled',
  CALL_STARTED: 'call_started',
  CALL_ENDED: 'call_ended',
  CHAT_UNLOCKED: 'chat_unlocked',
  MATCH_CLOSED: 'match_closed',

  // Meetup actions
  MEETUP_SCHEDULED: 'meetup_scheduled',
  QR_CHECKIN: 'qr_checkin',
  MEETUP_COMPLETED: 'meetup_completed',

  // Safety actions
  REPORT_SUBMITTED: 'report_submitted',
  REPORT_REVIEWED: 'report_reviewed',
  BLOCK_CREATED: 'block_created',
  SCORE_UPDATED: 'score_updated',
  USER_LIMITED: 'user_limited',
  USER_BANNED: 'user_banned',
  USER_UNBANNED: 'user_unbanned',

  // Admin actions
  ADMIN_OVERRIDE: 'admin_override',
  CONFIG_UPDATED: 'config_updated',
} as const;

// Config Keys
export const CONFIG_KEYS = {
  BOOTSTRAP_MODE_ENABLED: 'bootstrap_mode_enabled',
  MALE_COUNTER_PROPOSAL_ENABLED: 'male_counter_proposal_enabled',
  VIDEO_CALL_REQUIRED: 'video_call_required',
  ADMIN_USERS: 'admin_users',
  PHOTO_MIN_QUALITY: 'photo_min_quality',
  SCORE_PENALTY_THRESHOLDS: 'score_penalty_thresholds',
  RATE_LIMIT_OVERRIDES: 'rate_limit_overrides',
} as const;
