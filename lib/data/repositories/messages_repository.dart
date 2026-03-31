import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/message.dart';

class MessagesRepository {
  final SupabaseClient? _supabase;

  MessagesRepository({SupabaseClient? supabase}) : _supabase = supabase;

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  /// Get or create a 1-on-1 alliance conversation between two users.
  /// Returns the conversation id.
  Future<String> getOrCreateAlliance({
    required String currentUserId,
    required String otherUserId,
    required String mode,
  }) async {
    if (isMockMode) return 'mock-conv-${otherUserId.hashCode}';
    final db = _supabase;
    if (db == null) return 'no-client';

    // Check if any shared alliance conversation already exists
    final existing = await db
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', currentUserId);

    final existingIds =
        (existing as List).map((e) => e['conversation_id'] as String).toSet();

    if (existingIds.isNotEmpty) {
      final other = await db
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', otherUserId)
          .inFilter('conversation_id', existingIds.toList());

      final matches = other as List;
      if (matches.isNotEmpty) {
        return matches.first['conversation_id'] as String;
      }
    }

    // Create new conversation
    final conv = await db.from('conversations').insert({
      'type': 'alliance',
      'mode': mode,
    }).select().single();
    final convId = conv['id'] as String;

    await db.from('conversation_participants').insert([
      {'conversation_id': convId, 'user_id': currentUserId},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);
    return convId;
  }

  /// Get or create a group circle conversation for a Social table.
  Future<String> getOrCreateCircle({
    required String tableId,
    required String currentUserId,
  }) async {
    if (isMockMode) return 'mock-circle-$tableId';
    final db = _supabase;
    if (db == null) return 'no-client';

    final existing = await db
        .from('conversations')
        .select()
        .eq('type', 'circle')
        .eq('table_id', tableId)
        .maybeSingle();

    if (existing != null) {
      final convId = existing['id'] as String;
      await db.from('conversation_participants').upsert(
        {'conversation_id': convId, 'user_id': currentUserId},
        onConflict: 'conversation_id,user_id',
      );
      return convId;
    }

    final conv = await db.from('conversations').insert({
      'type': 'circle',
      'mode': 'social',
      'table_id': tableId,
    }).select().single();
    final convId = conv['id'] as String;

    await db.from('conversation_participants').insert({
      'conversation_id': convId,
      'user_id': currentUserId,
    });
    return convId;
  }

  // ---------------------------------------------------------------------------
  // Real-time stream
  // ---------------------------------------------------------------------------

  /// Live stream of messages, ordered oldest → newest.
  Stream<List<ChatMessage>> messagesStream(String conversationId) {
    final db = _supabase;
    if (isMockMode || db == null) return const Stream.empty();
    return db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map((r) => ChatMessage.fromJson(r)).toList());
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderDisplayName,
    required String content,
    required String mode,
    bool isSystem = false,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': isSystem ? null : senderId,
      'sender_display_name': senderDisplayName,
      'content': content,
      'mode': mode,
      'is_system': isSystem,
    });
  }

  // ---------------------------------------------------------------------------
  // Unread counts
  // ---------------------------------------------------------------------------

  Future<int> unreadCount({
    required String conversationId,
    required String userId,
  }) async {
    if (isMockMode) return 0;
    final db = _supabase;
    if (db == null) return 0;

    final cp = await db
        .from('conversation_participants')
        .select('last_read_at')
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .maybeSingle();

    if (cp == null) return 0;
    final lastRead = cp['last_read_at'] as String?;

    final query = db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId);

    final rows = lastRead != null
        ? await query.gt('created_at', lastRead)
        : await query;

    return (rows as List).length;
  }

  Future<void> markRead({
    required String conversationId,
    required String userId,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    await db.from('conversation_participants').update({
      'last_read_at': DateTime.now().toIso8601String(),
    }).eq('conversation_id', conversationId).eq('user_id', userId);
  }
}
