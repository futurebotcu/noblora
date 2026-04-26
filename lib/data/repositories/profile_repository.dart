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
