import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/message.dart';
import '../data/repositories/messages_repository.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  if (isMockMode) return MessagesRepository();
  return MessagesRepository(supabase: Supabase.instance.client);
});

/// Stream provider for messages in a specific conversation.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.messagesStream(conversationId);
});
