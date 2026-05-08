import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/post.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/echo_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/supabase_client_provider.dart';
import 'nob_detail_screen.dart';

// ---------------------------------------------------------------------------
// MyNobsScreen — own posts only, visible to the owner
// (anonim sistemde başka kullanıcının profil feed'i yoktur, bu sadece sahibe görünür)
// ---------------------------------------------------------------------------

/// View another user's published Nobs (public, non-anonymous only).
final _userNobsProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, userId) async {
  final repo = ref.watch(postRepositoryProvider);
  return repo.fetchLastNobs(userId, limit: 30);
});

final _myNobsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final uid = ref.watch(authProvider).userId;
  if (uid == null) return [];
  final repo = ref.watch(postRepositoryProvider);
  final posts = await repo.fetchLastNobs(uid, limit: 100);
  if (posts.isEmpty) return posts;

  // Enrich with comment + echo counts so the UI shows real numbers
  final commentRepo = isMockMode
      ? CommentRepository()
      : CommentRepository(supabase: ref.watch(supabaseClientProvider));
  final echoRepo = isMockMode
      ? EchoRepository()
      : EchoRepository(supabase: ref.watch(supabaseClientProvider));

  final ids = posts.map((p) => p.id).toList();
  // Parallelize all enrichment queries instead of sequential awaits
  final results = await Future.wait([
    commentRepo.commentCountsBatch(ids),
    echoRepo.echoCountsBatch(ids),
    echoRepo.userEchoedPostIds(userId: uid, postIds: ids),
    repo.getOwnReactionCountsBatch(ids, uid),
  ]);
  final commentCounts = results[0] as Map<String, int>;
  final echoCounts = results[1] as Map<String, int>;
  final myEchoes = results[2] as Set<String>;
  final ownReactionCountsMap = results[3] as Map<String, Map<String, int>>;

  return posts.map((p) => p.copyWith(
        commentCount: commentCounts[p.id] ?? 0,
        echoCount: echoCounts[p.id] ?? 0,
        hasEchoed: myEchoes.contains(p.id),
        ownCounts: ownReactionCountsMap[p.id],
      )).toList();
});

class MyNobsScreen extends ConsumerWidget {
  /// When null, shows current user's Nobs.
  /// When set, shows another user's public Nobs.
  final String? userId;
  final String? userName;
  const MyNobsScreen({super.key, this.userId, this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOther = userId != null;
    final async = isOther
        ? ref.watch(_userNobsProvider(userId!))
        : ref.watch(_myNobsProvider);
    final title = isOther ? (userName ?? 'Nobs') : 'My Nobs';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.emerald600)),
        error: (_, __) => Center(child: Text('Could not load.', style: TextStyle(color: context.textMuted))),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_outlined, color: context.textMuted, size: 36),
                    const SizedBox(height: 16),
                    Text('You haven\'t posted yet',
                        style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text("Your Nobs land here. Only you can see this page.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.emerald600,
            onRefresh: () => ref.refresh(_myNobsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: posts.length,
              itemBuilder: (_, i) {
                final p = posts[i];
                return _MyNobItem(post: p);
              },
            ),
          );
        },
      ),
    );
  }
}

class _MyNobItem extends StatelessWidget {
  final Post post;
  const _MyNobItem({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => NobDetailScreen(post: post),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderSubtleColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(post.isThought ? 'THOUGHT' : 'MOMENT',
                      style: const TextStyle(color: AppColors.emerald600, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
                const SizedBox(width: 8),
                Text(_ago(post.publishedAt ?? post.createdAt),
                    style: TextStyle(color: context.textMuted, fontSize: 11)),
                if (post.isAnonymous) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.emerald600.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.visibility_off_rounded, color: AppColors.emerald600, size: 9),
                        SizedBox(width: 3),
                        Text('ANONYMOUS', style: TextStyle(color: AppColors.emerald600, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (post.isThought && post.content.isNotEmpty)
              Text(post.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.5)),
            if (post.isMoment && post.photoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(imageUrl: post.photoUrl!, fit: BoxFit.cover, memCacheWidth: 720),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.waving_hand_outlined, color: context.textMuted, size: 13),
                const SizedBox(width: 3),
                Text('${post.appreciateCount}',
                    style: TextStyle(color: context.textMuted, fontSize: 11)),
                const SizedBox(width: 14),
                Icon(Icons.chat_bubble_outline_rounded, color: context.textMuted, size: 13),
                const SizedBox(width: 3),
                Text('${post.commentCount}', style: TextStyle(color: context.textMuted, fontSize: 11)),
                const SizedBox(width: 14),
                Icon(Icons.graphic_eq_rounded, color: context.textMuted, size: 13),
                const SizedBox(width: 3),
                Text('${post.echoCount}', style: TextStyle(color: context.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
