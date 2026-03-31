import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

class WhoLikedItem {
  final String userId;
  final String name;
  final String? photoUrl;
  final String mode;

  const WhoLikedItem({
    required this.userId,
    required this.name,
    this.photoUrl,
    this.mode = 'date',
  });
}

class SuperLikeRepository {
  final SupabaseClient? _supabase;

  SuperLikeRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Send a super like to [receiverId]. Decrements super_likes_remaining.
  Future<void> sendSuperLike({
    required String senderId,
    required String receiverId,
  }) async {
    if (isMockMode) return;
    final client = _supabase!;
    await client.from('super_likes').upsert({
      'sender_id': senderId,
      'receiver_id': receiverId,
    });
    // Decrement remaining
    await client.rpc('decrement_super_likes', params: {'uid': senderId});
  }

  /// Users who swiped right on [userId] (no existing match required).
  Future<List<WhoLikedItem>> fetchWhoLikedMe(String userId) async {
    if (isMockMode) return _mockItems('liked_me');
    final client = _supabase!;
    final swipeRows = await client
        .from('swipes')
        .select('swiper_id, mode')
        .eq('swiped_id', userId)
        .inFilter('direction', ['right', 'super']);
    return _enrichWithProfiles(client, swipeRows, idKey: 'swiper_id');
  }

  /// Users [userId] swiped right on.
  Future<List<WhoLikedItem>> fetchILiked(String userId) async {
    if (isMockMode) return _mockItems('i_liked');
    final client = _supabase!;
    final swipeRows = await client
        .from('swipes')
        .select('swiped_id, mode')
        .eq('swiper_id', userId)
        .inFilter('direction', ['right', 'super']);
    return _enrichWithProfiles(client, swipeRows, idKey: 'swiped_id');
  }

  /// Super likes received by [userId].
  Future<List<WhoLikedItem>> fetchSuperLikesReceived(String userId) async {
    if (isMockMode) return _mockItems('super');
    final client = _supabase!;
    final rows = await client
        .from('super_likes')
        .select('sender_id')
        .eq('receiver_id', userId);
    final ids = rows.map((r) => r['sender_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await client
        .from('profiles')
        .select('id, display_name, date_avatar_url')
        .inFilter('id', ids);
    final profileMap = {
      for (final p in profiles) p['id'] as String: p,
    };
    return ids.map((id) {
      final p = profileMap[id];
      return WhoLikedItem(
        userId: id,
        name: p?['display_name'] as String? ?? 'Someone',
        photoUrl: p?['date_avatar_url'] as String?,
        mode: 'date',
      );
    }).toList();
  }

  /// Fetches profiles for a list of swipe rows and returns WhoLikedItems.
  Future<List<WhoLikedItem>> _enrichWithProfiles(
    SupabaseClient client,
    List<Map<String, dynamic>> swipeRows, {
    required String idKey,
  }) async {
    if (swipeRows.isEmpty) return [];
    final ids = swipeRows.map((r) => r[idKey] as String).toList();
    final profiles = await client
        .from('profiles')
        .select('id, display_name, date_avatar_url')
        .inFilter('id', ids);
    final profileMap = {
      for (final p in profiles) p['id'] as String: p,
    };
    return swipeRows.map((r) {
      final id = r[idKey] as String;
      final p = profileMap[id];
      return WhoLikedItem(
        userId: id,
        name: p?['display_name'] as String? ?? 'Someone',
        photoUrl: p?['date_avatar_url'] as String?,
        mode: r['mode'] as String? ?? 'date',
      );
    }).toList();
  }

  /// Deletes the swipe record for the last swiped card (rewind).
  Future<void> deleteSwipe({
    required String swiperId,
    required String targetId,
  }) async {
    if (isMockMode) return;
    await _supabase!
        .from('swipes')
        .delete()
        .eq('swiper_id', swiperId)
        .eq('swiped_id', targetId);
  }

  /// Increment profile_views for [profileUserId].
  Future<void> incrementProfileViews(String profileUserId) async {
    if (isMockMode) return;
    await _supabase!.rpc('increment_profile_views', params: {'uid': profileUserId});
  }

  List<WhoLikedItem> _mockItems(String seed) => [
        WhoLikedItem(
          userId: 'mock-$seed-1',
          name: seed == 'super' ? 'Sofia' : 'Emma',
          photoUrl: null,
          mode: 'date',
        ),
        WhoLikedItem(
          userId: 'mock-$seed-2',
          name: seed == 'i_liked' ? 'Mia' : 'Lena',
          photoUrl: null,
          mode: 'bff',
        ),
      ];
}
