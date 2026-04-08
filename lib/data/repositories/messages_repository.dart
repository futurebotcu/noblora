import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';

class MessagesRepository {
  final SupabaseClient? _supabase;

  MessagesRepository({SupabaseClient? supabase}) : _supabase = supabase;

  // ---------------------------------------------------------------------------
  // Guard: reject sends to expired/closed matches
  // ---------------------------------------------------------------------------

  Future<void> _assertMatchActive(SupabaseClient db, String matchId) async {
    final row = await db.from('matches')
        .select('status, chat_expires_at')
        .eq('id', matchId)
        .maybeSingle();
    if (row == null) return;
    final status = row['status'] as String?;
    if (status == 'expired' || status == 'closed') {
      throw Exception('Cannot send: conversation has ended');
    }
    final expiresAt = row['chat_expires_at'] as String?;
    if (expiresAt != null && DateTime.tryParse(expiresAt)?.isBefore(DateTime.now().toUtc()) == true) {
      throw Exception('Cannot send: chat time has expired');
    }
  }

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
        .eq('user_id', currentUserId)
        .limit(500);

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
  /// Supabase realtime streams don't support LIMIT, so we trim client-side
  /// to avoid loading thousands of messages into memory.
  Stream<List<ChatMessage>> messagesStream(String conversationId) {
    final db = _supabase;
    if (isMockMode || db == null) return const Stream.empty();
    return db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) {
          final all = rows.map((r) => ChatMessage.fromJson(r)).toList();
          // Keep last 200 messages to prevent memory bloat
          if (all.length > 200) return all.sublist(all.length - 200);
          return all;
        });
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
    String? matchId,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    if (matchId != null) await _assertMatchActive(db, matchId);
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

    // Fetch only IDs to minimize data transfer
    var query = db
        .from('messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId);

    if (lastRead != null) {
      query = query.gt('created_at', lastRead);
    }

    final rows = await query;
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

  /// Mark all messages in a conversation as delivered (foundation for read receipts).
  /// Called when the recipient opens the chat. The DB columns delivered_at/read_at
  /// may not exist yet — this is safe to call regardless.
  Future<void> markDelivered({
    required String conversationId,
    required String userId,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    try {
      await db
          .from('messages')
          .update({'delivered_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .isFilter('delivered_at', null);
    } catch (e) {
      debugPrint('[messages] Mark delivered failed: $e');
    }
  }

  /// Mark all incoming messages in a conversation as read (sets read_at on
  /// individual message rows). Called when the recipient opens the chat.
  Future<void> markMessagesRead({
    required String conversationId,
    required String userId,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    try {
      await db
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('[messages] Mark read failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Media upload
  // ---------------------------------------------------------------------------

  /// Upload an image to chat-media bucket and return the public URL.
  Future<String?> uploadChatImage({
    required String conversationId,
    required String senderId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (isMockMode) return null;
    final db = _supabase;
    if (db == null) return null;
    final ext = mimeType.contains('png') ? 'png' : 'jpg';
    final path = '$conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await db.storage.from('chat-media').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType),
      );
      return db.storage.from('chat-media').getPublicUrl(path);
    } catch (e) {
      debugPrint('[messages] Image upload failed: $e');
      return null;
    }
  }

  /// Send a media message (image).
  Future<void> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderDisplayName,
    required String mode,
    required String mediaUrl,
    required String mediaType,
    String caption = '',
    String? matchId,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    if (matchId != null) await _assertMatchActive(db, matchId);
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_display_name': senderDisplayName,
      'content': caption.isNotEmpty ? caption : ' ',
      'mode': mode,
      'media_url': mediaUrl,
      'media_type': mediaType,
    });
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search messages in a conversation by text content.
  Future<List<ChatMessage>> searchMessages({
    required String conversationId,
    required String query,
  }) async {
    if (isMockMode) return [];
    final db = _supabase;
    if (db == null) return [];
    final escaped = query
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .ilike('content', '%$escaped%')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((r) => ChatMessage.fromJson(r)).toList();
  }

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  /// Add a reaction to a message.
  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    await db.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    }, onConflict: 'message_id,user_id,emoji');
  }

  /// Remove a reaction from a message.
  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    if (isMockMode) return;
    final db = _supabase;
    if (db == null) return;
    await db
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji);
  }

  /// Stream reactions for all messages in a conversation.
  Stream<List<MessageReaction>> reactionsStream(String conversationId) {
    final db = _supabase;
    if (isMockMode || db == null) return const Stream.empty();
    // Get message IDs in this conversation and stream their reactions
    return db
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) {
          return rows
              .map((r) => MessageReaction.fromJson(r))
              .toList();
        });
  }

  /// Fetch reactions for specific messages (batch).
  Future<Map<String, List<MessageReaction>>> fetchReactionsForMessages(
      List<String> messageIds) async {
    if (isMockMode || messageIds.isEmpty) return {};
    final db = _supabase;
    if (db == null) return {};
    final rows = await db
        .from('message_reactions')
        .select()
        .inFilter('message_id', messageIds);
    final result = <String, List<MessageReaction>>{};
    for (final r in rows as List) {
      final reaction = MessageReaction.fromJson(r);
      result.putIfAbsent(reaction.messageId, () => []).add(reaction);
    }
    return result;
  }
}
