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

    // Check if target allows notes from this sender
    final allowed = await _supabase!.rpc('can_reach_user', params: {
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
        .select('*, profiles!notes_sender_id_fkey(display_name, date_avatar_url)')
        .eq('receiver_id', userId)
        .order('created_at', ascending: false);

    return rows.map((r) {
      final profile = r['profiles'] as Map<String, dynamic>?;
      return Note(
        id: r['id'] as String,
        senderId: r['sender_id'] as String,
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
}
