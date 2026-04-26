import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/message.dart';
import '../data/repositories/messages_repository.dart';
import 'auth_provider.dart';
import 'supabase_client_provider.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  if (isMockMode) return MessagesRepository();
  return MessagesRepository(supabase: ref.watch(supabaseClientProvider));
});

/// Stream provider for messages in a specific conversation.
/// autoDispose so each closed chat screen tears down its realtime subscription.
final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, conversationId) {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.messagesStream(conversationId);
});

/// Total unread message count for chat tab badge
final unreadMessageCountProvider = FutureProvider<int>((ref) async {
  if (isMockMode) return 0;
  final uid = ref.watch(authProvider).userId;
  if (uid == null) return 0;
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.totalUnreadCount(userId: uid);
});
