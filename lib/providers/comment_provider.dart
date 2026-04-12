import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/post_comment.dart';
import '../data/repositories/comment_repository.dart';
import 'auth_provider.dart';
import 'posts_provider.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  if (isMockMode) return CommentRepository();
  return CommentRepository(supabase: Supabase.instance.client);
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
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
    super.dispose();
  }

  void _subscribeRealtime() {
    if (isMockMode) return;
    try {
      // Subscribe to feed_events for any comment_new event tied to this post.
      // post_comments has open SELECT RLS so we could also stream that table
      // directly, but going through feed_events keeps everything consistent
      // with the wider realtime fan-out.
      _channel = Supabase.instance.client
          .channel('detail:comments:$postId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'feed_events',
            callback: (payload) {
              final row = payload.newRecord;
              if (row['post_id'] != postId) return;
              if (row['event_type'] != 'comment_new') return;
              load();
            },
          )
          .subscribe();
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
