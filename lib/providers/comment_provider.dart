import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/post_comment.dart';
import '../data/repositories/comment_repository.dart';
import 'auth_provider.dart';
import 'posts_provider.dart';
import 'realtime_provider.dart';
import 'supabase_client_provider.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  if (isMockMode) return CommentRepository();
  return CommentRepository(supabase: ref.watch(supabaseClientProvider));
});

class CommentsState {
  final List<PostComment> comments; // threaded: top-level with .replies
  final List<PostComment> chains;   // flat Soul Chain continuation links
  final bool isLoading;

  const CommentsState({
    this.comments = const [],
    this.chains = const [],
    this.isLoading = false,
  });

  int get totalCount {
    int count = chains.length;
    for (final c in comments) {
      count += 1 + c.replies.length;
    }
    return count;
  }

  CommentsState copyWith({
    List<PostComment>? comments,
    List<PostComment>? chains,
    bool? isLoading,
  }) =>
      CommentsState(
        comments: comments ?? this.comments,
        chains: chains ?? this.chains,
        isLoading: isLoading ?? this.isLoading,
      );
}

class CommentsNotifier extends StateNotifier<CommentsState> {
  final Ref _ref;
  final String postId;
  RealtimeChannel? _channel;

  CommentsNotifier(this._ref, this.postId) : super(const CommentsState()) {
    load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) {
      try {
        _ref.read(realtimeRepositoryProvider).unsubscribe(ch);
      } catch (e) {
        debugPrint('[comment] dispose channel: $e');
      }
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    if (isMockMode) return;
    try {
      // feed_events fan-out keeps comment refresh consistent with the wider
      // realtime stream; filter (post_id + comment_new) is encapsulated in
      // CommentRepository.subscribeToCommentEvents.
      _channel = _ref
          .read(commentRepositoryProvider)
          .subscribeToCommentEvents(postId, (_) => load());
    } catch (e) {
      debugPrint('[comments:realtime] subscribe failed: $e');
    }
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(commentRepositoryProvider);
      final bundle = await repo.fetchComments(postId);
      state = state.copyWith(
        comments: bundle.replies,
        chains: bundle.chains,
        isLoading: false,
      );
      // Sync absolute count back to feed posts state.
      final total = state.totalCount;
      _ref.read(postsProvider.notifier).setCommentCount(postId, total);
    } catch (e) {
      debugPrint('[comments:load] $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> add(
    String content, {
    String? parentId,
    String chainType = 'reply',
  }) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return false;
    final repo = _ref.read(commentRepositoryProvider);
    final comment = await repo.addComment(
      postId: postId,
      userId: uid,
      content: content,
      parentId: parentId,
      chainType: chainType,
    );
    if (comment != null) {
      // Reload to get proper thread structure (this also resyncs feed count)
      await load();
      return true;
    }
    return false;
  }

  Future<void> delete(String commentId) async {
    final repo = _ref.read(commentRepositoryProvider);
    await repo.deleteComment(commentId);
    await load(); // Reload + resync feed count
  }

  Future<({bool ok, String? error})> editComment(
      String commentId, String newContent) async {
    final repo = _ref.read(commentRepositoryProvider);
    final result =
        await repo.editComment(commentId: commentId, newContent: newContent);
    if (result.ok) await load();
    return result;
  }
}

final commentsProvider = StateNotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsState, String>((ref, postId) {
  return CommentsNotifier(ref, postId);
});
