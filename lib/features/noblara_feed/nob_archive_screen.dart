import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';
import '../../providers/posts_provider.dart';

class NobArchiveScreen extends ConsumerWidget {
  const NobArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedNobsProvider);

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'A R C H I V E',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.nobBorder),
        ),
      ),
      body: archivedAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.noblaraGold, strokeWidth: 1.5)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 13))),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.nobSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.nobBorder),
                    ),
                    child: const Icon(Icons.archive_outlined,
                        color: AppColors.nobObserver, size: 22),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Nothing archived.',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Archived Nobs will appear here.',
                    style: TextStyle(
                        color: AppColors.nobObserver, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl),
            itemCount: posts.length,
            itemBuilder: (_, i) => _ArchivedCard(post: posts[i]),
          );
        },
      ),
    );
  }
}

class _ArchivedCard extends ConsumerWidget {
  final Post post;
  const _ArchivedCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isThought = post.nobType == 'thought';
    final preview =
        isThought ? post.content : (post.caption ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.nobSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.nobBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.nobSurfaceAlt,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.nobBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isThought
                            ? Icons.format_quote_rounded
                            : Icons.image_outlined,
                        size: 10,
                        color: AppColors.nobObserver,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isThought ? 'THOUGHT' : 'MOMENT',
                        style: const TextStyle(
                          color: AppColors.nobObserver,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _ago(post.createdAt),
                  style: const TextStyle(
                      color: AppColors.nobObserver, fontSize: 10),
                ),
              ],
            ),
          ),

          // Preview text
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Text(
              preview.isEmpty ? '(empty)' : preview,
              style: TextStyle(
                color: preview.isEmpty
                    ? AppColors.nobObserver
                    : AppColors.textPrimary,
                fontSize: 14,
                height: 1.55,
                fontStyle:
                    preview.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Action row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () async {
                    final repo = ref.read(postRepositoryProvider);
                    await repo.unarchivePost(post.id);
                    ref.invalidate(archivedNobsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Restored to feed'),
                          backgroundColor: AppColors.nobSurface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.noblaraGold.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                          color:
                              AppColors.noblaraGold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.unarchive_outlined,
                            size: 13, color: AppColors.noblaraGold),
                        SizedBox(width: AppSpacing.xs),
                        Text(
                          'Restore',
                          style: TextStyle(
                            color: AppColors.noblaraGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return '${d.inMinutes}m ago';
  }
}
