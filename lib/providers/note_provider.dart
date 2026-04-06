import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import 'auth_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  if (isMockMode) return NoteRepository();
  return NoteRepository(supabase: Supabase.instance.client);
});

class NoteInboxState {
  final List<Note> notes;
  final bool isLoading;

  const NoteInboxState({this.notes = const [], this.isLoading = false});

  NoteInboxState copyWith({List<Note>? notes, bool? isLoading}) =>
      NoteInboxState(notes: notes ?? this.notes, isLoading: isLoading ?? this.isLoading);
}

class NoteInboxNotifier extends StateNotifier<NoteInboxState> {
  final Ref _ref;

  NoteInboxNotifier(this._ref) : super(const NoteInboxState());

  Future<void> load() async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(noteRepositoryProvider);
      final notes = await repo.fetchReceivedNotes(uid);
      state = state.copyWith(notes: notes, isLoading: false);
    } catch (e) {
      debugPrint('[notes] Load failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> sendNote({
    required String receiverId,
    required String targetType,
    required String targetId,
    required String content,
  }) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return false;
    final repo = _ref.read(noteRepositoryProvider);
    final canSend = await repo.canSendNote(uid);
    if (!canSend) return false;
    await repo.sendNote(
      senderId: uid,
      receiverId: receiverId,
      targetType: targetType,
      targetId: targetId,
      content: content,
    );
    return true;
  }

  Future<void> markRead(String noteId) async {
    final repo = _ref.read(noteRepositoryProvider);
    await repo.markRead(noteId);
    state = state.copyWith(
      notes: state.notes.map((n) =>
        n.id == noteId ? Note(
          id: n.id, senderId: n.senderId, receiverId: n.receiverId,
          targetType: n.targetType, targetId: n.targetId, content: n.content,
          isRead: true, createdAt: n.createdAt,
          senderName: n.senderName, senderPhotoUrl: n.senderPhotoUrl,
        ) : n
      ).toList(),
    );
  }
}

final noteInboxProvider =
    StateNotifierProvider<NoteInboxNotifier, NoteInboxState>((ref) {
  return NoteInboxNotifier(ref);
});
