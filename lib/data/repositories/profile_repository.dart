import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/profile.dart';

// ---------------------------------------------------------------------------
// public.profiles — query/write columns (LIVE schema):
//   id           — UUID PK = auth.users.id  ← ALL queries filter on this
//   full_name    — TEXT
//   current_mode — TEXT ('date' | 'bff')
//   date_bio / date_avatar_url
//   bff_bio / bff_avatar_url
//   noble_score  — INTEGER (read-only, set by backend)
//   updated_at   — TIMESTAMPTZ (managed by DB trigger)
// ---------------------------------------------------------------------------

const _mockProfile = Profile(
  id: 'mock-profile-uuid-001',
  userId: 'mock-golden-user-001',
  displayName: 'Golden User',
  gender: 'female',   // required — hasGender must be true in mock mode
  mode: 'date',
  nobleScore: 87,
  dateBio: 'Art lover & sunset chaser.',
  bffBio: 'Design Lead obsessed with minimalism.',
);

class ProfileRepository {
  final SupabaseClient? _supabase;

  ProfileRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<Profile?> fetchProfile(String userId) async {
    if (isMockMode) return _mockProfile;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final data = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Dedicated read methods (Dalga 5c2 — R9 final). Each one mirrors a
  // single former direct-client call site: column list, filter, and
  // maybeSingle preserved so callers' DTO mapping/cast logic stays intact.
  // ───────────────────────────────────────────────────────────────────────

  Future<List<String>?> fetchActiveModes(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('active_modes')
        .eq('id', userId)
        .maybeSingle();
    final raw = row?['active_modes'];
    if (raw is List) return raw.cast<String>();
    return null;
  }

  Future<({String? themeMode, String? accentColor})?> fetchAppearance(
      String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('theme_mode, accent_color')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return (
      themeMode: row['theme_mode'] as String?,
      accentColor: row['accent_color'] as String?,
    );
  }

  Future<({int photoCount, bool verifiedPhoto, String? nobTier})?>
      fetchInteractionGate(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('photo_count, verified_profile_photo, nob_tier')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return (
      photoCount: (row['photo_count'] as int?) ?? 0,
      verifiedPhoto: (row['verified_profile_photo'] as bool?) ?? false,
      nobTier: row['nob_tier'] as String?,
    );
  }

  Future<bool?> fetchMessagePreview(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('message_preview')
        .eq('id', userId)
        .maybeSingle();
    return row?['message_preview'] as bool?;
  }

  // `fetchAiWritingHelp` removed in R17B-fix(C) — AI Preferences UI was
  // removed in R17B, the only client reader (chat's _suggestBffOpener
  // gate) defaulted to `true` when there was no toggle to set it false,
  // making the read a phantom. AI BFF opener is now user-initiated by
  // tapping the button — that's the consent. Backend `ai_writing_help`
  // jsonb column is untouched; no writer or reader in V1 code paths.

  Future<({List<String> blocked, List<String> hidden})> fetchBlockedAndHidden(
      String userId) async {
    if (isMockMode) return (blocked: <String>[], hidden: <String>[]);
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('blocked_users, hidden_users')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return (blocked: <String>[], hidden: <String>[]);
    final blocked = [
      for (final id in (row['blocked_users'] as List<dynamic>? ?? []))
        id as String
    ];
    final hidden = [
      for (final id in (row['hidden_users'] as List<dynamic>? ?? []))
        id as String
    ];
    return (blocked: blocked, hidden: hidden);
  }

  Future<Map<String, dynamic>?> fetchNotificationPreferences(
      String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('notification_preferences')
        .eq('id', userId)
        .maybeSingle();
    return row?['notification_preferences'] as Map<String, dynamic>?;
  }

  /// Full row read for ProfileDraft.fromDbRow (edit_profile flow).
  /// Returns the raw row map; caller drives parsing.
  Future<Map<String, dynamic>?> fetchProfileDraftRow(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row;
  }

  /// Settings screen multi-column read (22 columns). Column list mirrors
  /// the original settings_screen.dart query verbatim.
  /// R17B-fix(C) — SELECT narrowed to only the columns the post-cleanup
  /// Settings UI actually reads. Phantom columns (calm_mode,
  /// show_last_active, show_status_badge, reach/signal/note_permission,
  /// notification_preferences, ai_writing_help, incognito_mode,
  /// dating_visible, bff_visible, blocked_users, hidden_users, city)
  /// were removed from the projection — their DB columns are untouched,
  /// but the Settings screen no longer pulls them across the wire.
  Future<Map<String, dynamic>?> fetchSettingsRow(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('message_preview, is_paused, '
            'is_verified, selfie_verified, photos_verified, verification_status')
        .eq('id', userId)
        .maybeSingle();
    return row;
  }

  Future<String?> fetchNobTier(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('nob_tier')
        .eq('id', userId)
        .maybeSingle();
    return row?['nob_tier'] as String?;
  }

  Future<bool?> fetchIsAdmin(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('is_admin')
        .eq('id', userId)
        .maybeSingle();
    return row?['is_admin'] as bool?;
  }

  /// Creates a minimal profile row with only confirmed-safe columns.
  /// Onboarding completion is determined by row existence, not a flag.
  Future<Profile> createProfile({
    required String userId,
    required String fullName,
    String? currentMode,
  }) async {
    if (isMockMode) {
      return _mockProfile.copyWith(
        displayName: fullName,
        mode: currentMode ?? 'date',
      );
    }
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final data = await client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      if (currentMode != null) 'current_mode': currentMode,
    }, onConflict: 'id').select().single();
    return Profile.fromJson(data);
  }

  Future<Profile> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    if (isMockMode) {
      // Apply updates so state-dependent getters (hasGender etc.) stay consistent
      return _mockProfile.copyWith(
        displayName: updates['full_name'] as String?,
        gender: updates['gender'] as String?,
        mode: updates['current_mode'] as String?,
      );
    }
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final data = await client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  /// Append `otherId` to the caller's `blocked_users` list (no-op if already present).
  /// Read-then-write — preserves existing list semantics; future tightening could
  /// move this to an atomic `array_append` SQL helper.
  Future<void> addToBlockList(String userId, String otherId) async {
    if (isMockMode) return;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('blocked_users')
        .eq('id', userId)
        .single();
    final list = List<String>.from((row['blocked_users'] as List<dynamic>?) ?? []);
    if (list.contains(otherId)) return;
    list.add(otherId);
    await client
        .from('profiles')
        .update({'blocked_users': list})
        .eq('id', userId);
  }

  // `addToHideList` removed in R17B-fix — Hide User has no user-facing
  // surface in V1 (the Settings list/unhide UI was removed in R17B and the
  // chat/match-detail menu entries were removed in the companion commit).
  // fetchBlockedAndHidden() is kept so feed_repository's discovery filter
  // can still exclude legacy hidden_users array entries from existing rows;
  // the column itself is untouched.

  /// Trigger a server-side maturity score recalculation for [userId]. Caller
  /// fires-and-forgets (no return; failures tolerated, score recomputed
  /// next session if this attempt is dropped).
  Future<void> recalculateMaturityScore(String userId) async {
    if (isMockMode) return;
    await _supabase!
        .rpc('calculate_maturity_score', params: {'p_user_id': userId});
  }

  /// Updates mode-specific bio and avatar — both column names are confirmed
  /// to exist in the real schema (date_bio, bff_bio).
  Future<void> updatePersona({
    required String userId,
    required String mode, // 'date' | 'bff'
    String? bio,
    String? avatarUrl,
  }) async {
    if (isMockMode) return;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final updates = <String, dynamic>{};
    if (bio != null) updates['${mode}_bio'] = bio;
    if (avatarUrl != null) updates['${mode}_avatar_url'] = avatarUrl;
    if (updates.isEmpty) return;
    await client.from('profiles').update(updates).eq('id', userId);
  }
}
