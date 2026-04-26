import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// Admin-only data access — moderation queue, dashboard counts, and post
/// removal. Server-side RLS enforces `is_admin = true`; this class only
/// centralises the call paths so the screen can drop its direct supabase
/// usage. Mock mode short-circuits to safe no-ops or sample shapes.
class AdminRepository {
  final SupabaseClient? _supabase;

  AdminRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// 4 parallel COUNT-only fetches behind the admin dashboard.
  Future<({
    int totalUsers,
    int pendingVerifications,
    int activeMatches,
    int postsToday,
  })> fetchStats() async {
    if (isMockMode) {
      return (
        totalUsers: 0,
        pendingVerifications: 0,
        activeMatches: 0,
        postsToday: 0,
      );
    }
    final db = _supabase!;
    final results = await Future.wait([
      db.from('profiles').select('id'),
      db.from('photo_verifications').select('id').eq('status', 'pending'),
      db.from('matches').select('id').inFilter(
          'status', ['pending_video', 'video_scheduled', 'chatting']),
      db.from('posts').select('id').gte(
          'created_at',
          DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String()),
    ]);
    return (
      totalUsers: (results[0] as List).length,
      pendingVerifications: (results[1] as List).length,
      activeMatches: (results[2] as List).length,
      postsToday: (results[3] as List).length,
    );
  }

  /// Pending or manual-review photo verifications, joined with the user's
  /// `display_name`. Returns raw rows enriched with a `display_name` key —
  /// the caller maps to its own DTO. Empty list in mock mode (the admin
  /// screen carries its own mock fixtures at the provider level).
  Future<List<Map<String, dynamic>>> fetchPendingVerifications() async {
    if (isMockMode) return const [];
    final db = _supabase!;
    final rows = await db
        .from('photo_verifications')
        .select('user_id, status, photo_url, created_at')
        .inFilter('status', ['pending', 'manual_review'])
        .order('created_at')
        .limit(50);
    if (rows.isEmpty) return const [];

    final userIds = rows.map((r) => r['user_id'] as String).toList();
    final profiles = await db
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final profileMap = {
      for (final p in profiles)
        p['id'] as String: p['display_name'] as String? ?? 'Unknown'
    };

    return rows
        .map((r) => {
              'user_id': r['user_id'],
              'status': r['status'],
              'photo_url': r['photo_url'],
              'created_at': r['created_at'],
              'display_name': profileMap[r['user_id']] ?? 'Unknown',
            })
        .toList();
  }

  /// Mark a photo verification approved AND set the user's `photo_verified`
  /// flag. Two sequential UPDATEs — preserves original behaviour: if the
  /// first fails, the second never runs.
  Future<void> approvePhotoVerification(String userId) async {
    if (isMockMode) return;
    final db = _supabase!;
    await db
        .from('photo_verifications')
        .update({'status': 'approved'}).eq('user_id', userId);
    await db
        .from('profiles')
        .update({'photo_verified': true}).eq('id', userId);
  }

  Future<void> rejectPhotoVerification(String userId) async {
    if (isMockMode) return;
    await _supabase!
        .from('photo_verifications')
        .update({'status': 'rejected'}).eq('user_id', userId);
  }

  /// Most-recent posts for moderation, enriched with author display_name.
  /// Returns merged `Map<String, dynamic>` with `id`, `content`, `author`
  /// keys — drop-in shape for the existing `_PostModerationCard` caller.
  Future<List<Map<String, dynamic>>> fetchRecentPosts({int limit = 30}) async {
    if (isMockMode) {
      return [
        {'id': 'mock-p1', 'content': 'Hello Noblara!', 'author': 'Ali'},
        {'id': 'mock-p2', 'content': 'Great community here.', 'author': 'Zeynep'},
      ];
    }
    final db = _supabase!;
    final rows = await db
        .from('posts')
        .select('id, content, user_id, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    if (rows.isEmpty) return const [];

    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = await db
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final nameMap = {
      for (final p in profiles)
        p['id'] as String: p['display_name'] as String? ?? 'Unknown'
    };

    return rows
        .map((r) => {
              'id': r['id'],
              'content': r['content'],
              'author': nameMap[r['user_id']] ?? 'Unknown',
            })
        .toList();
  }
}
