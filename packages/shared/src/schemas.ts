// ============================================================================
// NOBLARA ZOD SCHEMAS
// ============================================================================

import { z } from 'zod';
import {
  MODES,
  GENDERS,
  VERIFICATION_STATUS,
  ENTRY_STATUS,
  SCORE_STATUS,
  SUBSCRIPTION_TIERS,
  PHOTO_RULES,
  POST_RULES,
  FILTER_DEFAULTS,
} from './constants';

// ============================================================================
// ENUM SCHEMAS
// ============================================================================

export const ModeSchema = z.enum([MODES.DATING, MODES.BFF]);
export const GenderSchema = z.enum([GENDERS.FEMALE, GENDERS.MALE, GENDERS.OTHER]);
export const VerificationStatusSchema = z.enum([
  VERIFICATION_STATUS.PENDING,
  VERIFICATION_STATUS.APPROVED,
  VERIFICATION_STATUS.REJECTED,
]);
export const EntryStatusSchema = z.enum([
  ENTRY_STATUS.PENDING,
  ENTRY_STATUS.APPROVED,
  ENTRY_STATUS.REJECTED,
]);
export const ScoreStatusSchema = z.enum([
  SCORE_STATUS.OK,
  SCORE_STATUS.LIMITED,
  SCORE_STATUS.BANNED,
]);
export const SubscriptionTierSchema = z.enum([
  SUBSCRIPTION_TIERS.FREE,
  SUBSCRIPTION_TIERS.PREMIUM,
]);

// ============================================================================
// INPUT SCHEMAS
// ============================================================================

export const CreateProfileSchema = z.object({
  mode: ModeSchema,
  gender_claim: GenderSchema,
  birth_year: z
    .number()
    .int()
    .min(1900)
    .max(new Date().getFullYear() - FILTER_DEFAULTS.MIN_AGE),
  city: z.string().max(100).optional(),
  bio: z.string().max(500).optional(),
});

export const UpdateProfileSchema = z.object({
  mode: ModeSchema.optional(),
  city: z.string().max(100).optional(),
  bio: z.string().max(500).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

export const TimeSlotSchema = z.object({
  start: z.string().datetime(),
  end: z.string().datetime(),
});

export const CreateReferralCodeSchema = z.object({
  invitee_gender_required: GenderSchema,
});

export const RedeemReferralCodeSchema = z.object({
  code: z.string().min(6).max(20).regex(/^[A-Z0-9]+$/),
});

export const ScheduleCallSchema = z.object({
  match_id: z.string().uuid(),
  slots: z.array(TimeSlotSchema).min(1).max(5),
});

export const AcceptCallSchema = z.object({
  match_id: z.string().uuid(),
  proposal_id: z.string().uuid(),
  selected_slot: TimeSlotSchema,
});

export const RatingFlagsSchema = z.object({
  inappropriate: z.boolean().optional(),
  no_show: z.boolean().optional(),
  fake_profile: z.boolean().optional(),
  rude: z.boolean().optional(),
  other: z.string().max(200).optional(),
});

export const RateCallSchema = z.object({
  match_id: z.string().uuid(),
  rating: z.number().int().min(1).max(5),
  flags: RatingFlagsSchema.optional(),
});

export const PostCallDecisionSchema = z.object({
  match_id: z.string().uuid(),
  continue_match: z.boolean(),
});

export const SendMessageSchema = z.object({
  match_id: z.string().uuid(),
  body: z.string().min(1).max(2000),
});

export const ScheduleMeetupSchema = z.object({
  match_id: z.string().uuid(),
  scheduled_at: z.string().datetime(),
  location_text: z.string().max(200).optional(),
});

export const QrCheckinSchema = z.object({
  meetup_id: z.string().uuid(),
  token: z.string().min(32).max(64),
});

export const CreatePostSchema = z.object({
  body: z.string().min(1).max(POST_RULES.MAX_BODY_LENGTH),
});

export const ReportSchema = z.object({
  target: z.string().uuid(),
  reason: z.string().min(10).max(500),
  evidence_urls: z.array(z.string().url()).max(5).optional(),
});

export const ReportPostSchema = z.object({
  post_id: z.string().uuid(),
  reason: z.string().min(10).max(500),
});

export const FeedFiltersSchema = z.object({
  mode: ModeSchema,
  min_age: z.number().int().min(FILTER_DEFAULTS.MIN_AGE).optional(),
  max_age: z.number().int().max(FILTER_DEFAULTS.MAX_AGE).optional(),
  max_distance_km: z.number().int().min(1).max(FILTER_DEFAULTS.MAX_DISTANCE_KM).optional(),
  cursor: z.string().optional(),
  limit: z.number().int().min(1).max(50).default(20),
});

// ============================================================================
// PHOTO UPLOAD SCHEMA
// ============================================================================

export const PhotoUploadSchema = z.object({
  order_index: z.number().int().min(0).max(PHOTO_RULES.MAX_PHOTOS - 1),
});

// ============================================================================
// INSTAGRAM VERIFICATION SCHEMA
// ============================================================================

export const InstagramConnectSchema = z.object({
  // OAuth flow will populate this, or manual entry for fallback
  ig_username: z.string().min(1).max(30).optional(),
  access_token: z.string().optional(), // From OAuth
});

export const InstagramManualProofSchema = z.object({
  ig_username: z.string().min(1).max(30),
  proof_image_url: z.string().url(), // Screenshot of profile with specific text
});

// ============================================================================
// GENDER VERIFICATION SCHEMA
// ============================================================================

export const GenderVerificationSchema = z.object({
  gender_claim: GenderSchema,
  evidence_url: z.string().url(), // ID or selfie proof upload URL
});

// ============================================================================
// ADMIN SCHEMAS
// ============================================================================

export const AdminActionSchema = z.object({
  action: z.enum([
    'approve_photo',
    'reject_photo',
    'approve_instagram',
    'reject_instagram',
    'approve_gender',
    'reject_gender',
    'approve_verification',
    'reject_verification',
    'approve_entry',
    'reject_entry',
    'limit_user',
    'ban_user',
    'unban_user',
    'shadowban_user',
  ]),
  target_user: z.string().uuid(),
  reason: z.string().max(500).optional(),
});

export const AdminConfigUpdateSchema = z.object({
  key: z.string().min(1).max(100),
  value: z.unknown(),
});

// ============================================================================
// VALIDATION HELPERS
// ============================================================================

export function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}

export function safeValidateInput<T>(
  schema: z.ZodSchema<T>,
  data: unknown
): { success: true; data: T } | { success: false; error: z.ZodError } {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

// Age calculation helper
export function calculateAge(birthYear: number): number {
  return new Date().getFullYear() - birthYear;
}

export function isValidAge(birthYear: number): boolean {
  const age = calculateAge(birthYear);
  return age >= FILTER_DEFAULTS.MIN_AGE && age <= FILTER_DEFAULTS.MAX_AGE;
}
