import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/note.dart';

class NoteRepository {
  final SupabaseClient? _supabase;

  NoteRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Check if user can send a note (tier limit)
  Future<bool> canSendNote(String userId) async {
    if (isMockMode) return true;
    final result =
        await _supabase!.rpc('check_note_limit', params: {'p_user_id': userId});
    return result as bool? ?? false;
  }

  /// Send a note to a profile or post. Checks permission first.
  Future<bool> sendNote({
    required String senderId,
    required String receiverId,
    required String targetType, // 'profile' | 'post'
    required String targetId,
    required String content,
  }) async {
    if (isMockMode) return true;

    // Check interaction eligibility (use 'date' as default mode for notes)
    final eligible = await _supabase!.rpc('can_user_interact', params: {'p_user_id': senderId, 'p_mode': 'date'});
    if (eligible != true) return false;

    // Check if target allows notes from this sender
    final allowed = await _supabase.rpc('can_reach_user', params: {
      'p_sender_id': senderId,
      'p_target_id': receiverId,
      'p_action': 'note',
    });
    if (allowed != true) return false;

    await _supabase.from('notes').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'target_type': targetType,
      'target_id': targetId,
      'content': content,
    });

    // Increment note counters
    await _supabase
        .rpc('increment_note_count', params: {'p_user_id': senderId});

    // Notify receiver
    await _supabase.from('notifications').insert({
      'user_id': receiverId,
      'type': 'note_received',
      'title': 'You received a note',
      'body': 'Someone left you a note.',
      'data': {
        'sender_id': senderId,
        'target_type': targetType,
        'target_id': targetId,
      },
    });
    return true;
  }

  /// Fetch notes received by [userId].
  Future<List<Note>> fetchReceivedNotes(String userId) async {
    if (isMockMode) {
      return [
        Note(
          id: 'mock-note-1',
          senderId: 'mock-user-1',
          receiverId: userId,
          targetType: 'profile',
          targetId: userId,
          content: 'Hey, loved your profile!',
          isRead: false,
          createdAt: DateTime.now(),
          senderName: 'Lena',
        ),
      ];
    }
    final rows = await _supabase!
        .from('notes')
        .select()
        .eq('receiver_id', userId)
        .order('created_at', ascending: false);

    // Enrich with sender profile info
    final senderIds = rows.map((r) => r['sender_id'] as String).toSet().toList();
    final profiles = senderIds.isEmpty ? <Map<String, dynamic>>[] : await _supabase
        .from('profiles')
        .select('id, display_name, date_avatar_url')
        .inFilter('id', senderIds);
    final profileMap = {for (final p in profiles) p['id'] as String: p};

    return rows.map((r) {
      final senderId = r['sender_id'] as String;
      final profile = profileMap[senderId];
      return Note(
        id: r['id'] as String,
        senderId: senderId,
        receiverId: r['receiver_id'] as String,
        targetType: r['target_type'] as String? ?? 'profile',
        targetId: r['target_id'] as String,
        content: r['content'] as String,
        isRead: r['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(r['created_at'] as String),
        senderName: profile?['display_name'] as String?,
        senderPhotoUrl: profile?['date_avatar_url'] as String?,
      );
    }).toList();
  }

  /// Mark a note as read.
  Future<void> markRead(String noteId) async {
    if (isMockMode) return;
    await _supabase!
        .from('notes')
        .update({'is_read': true})
        .eq('id', noteId);
  }

  /// Delete a sent note (only sender can delete).
  Future<void> deleteNote({required String noteId, required String senderId}) async {
    if (isMockMode) return;
    await _supabase!
        .from('notes')
        .delete()
        .eq('id', noteId)
        .eq('sender_id', senderId);
  }
}
