import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/profile.dart';

// ---------------------------------------------------------------------------
// public.profiles — query/write columns (LIVE schema):
//   id           — UUID PK = auth.users.id  ← ALL queries filter on this
//   full_name    — TEXT
//   current_mode — TEXT ('date' | 'bff' | 'social')
//   date_bio / date_avatar_url
//   bff_bio / bff_avatar_url
//   social_bio / social_avatar_url
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
  socialBio: 'Rooftop dinners and jazz bars.',
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

  Future<Map<String, dynamic>?> fetchAiWritingHelp(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('ai_writing_help')
        .eq('id', userId)
        .maybeSingle();
    return row?['ai_writing_help'] as Map<String, dynamic>?;
  }

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

  Future<bool?> fetchLeaveEventChatAuto(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('leave_event_chat_auto')
        .eq('id', userId)
        .maybeSingle();
    return row?['leave_event_chat_auto'] as bool?;
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
  Future<Map<String, dynamic>?> fetchSettingsRow(String userId) async {
    if (isMockMode) return null;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('notification_preferences, incognito_mode, calm_mode, '
            'dating_visible, bff_visible, social_visible, '
            'show_last_active, show_status_badge, message_preview, '
            'reach_permission, signal_permission, note_permission, '
            'city, is_paused, leave_event_chat_auto, '
            'ai_writing_help, '
            'is_verified, selfie_verified, photos_verified, verification_status, '
            'blocked_users, hidden_users')
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

  /// Append `otherId` to the caller's `hidden_users` list (no-op if already present).
  Future<void> addToHideList(String userId, String otherId) async {
    if (isMockMode) return;
    final client = _supabase;
    if (client == null) throw Exception('Supabase client not initialized');
    final row = await client
        .from('profiles')
        .select('hidden_users')
        .eq('id', userId)
        .single();
    final list = List<String>.from((row['hidden_users'] as List<dynamic>?) ?? []);
    if (list.contains(otherId)) return;
    list.add(otherId);
    await client
        .from('profiles')
        .update({'hidden_users': list})
        .eq('id', userId);
  }

  /// Trigger a server-side maturity score recalculation for [userId]. Caller
  /// fires-and-forgets (no return; failures tolerated, score recomputed
  /// next session if this attempt is dropped).
  Future<void> recalculateMaturityScore(String userId) async {
    if (isMockMode) return;
    await _supabase!
        .rpc('calculate_maturity_score', params: {'p_user_id': userId});
  }

  /// Updates mode-specific bio and avatar — both column names are confirmed
  /// to exist in the real schema (date_bio, bff_bio, social_bio, etc.).
  Future<void> updatePersona({
    required String userId,
    required String mode, // 'date' | 'bff' | 'social'
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
