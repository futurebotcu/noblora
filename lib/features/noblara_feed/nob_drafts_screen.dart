import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../data/models/post.dart';
import '../../providers/posts_provider.dart';
import '../../core/services/toast_service.dart';
import 'nob_compose_screen.dart';

class NobDraftsScreen extends ConsumerWidget {
  const NobDraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(draftsProvider);

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'D R A F T S',
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
      body: draftsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.emerald600, strokeWidth: 1.5)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.error, fontSize: 13))),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  decoration: Premium.emptyStateDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [AppColors.emerald600.withValues(alpha: 0.10), AppColors.emerald600.withValues(alpha: 0.03)],
                          ),
                          border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.12), width: 0.5),
                        ),
                        child: Icon(Icons.drafts_outlined, color: AppColors.emerald600.withValues(alpha: 0.45), size: 26),
                      ),
                      const SizedBox(height: 24),
                      const Text('No drafts yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                      const SizedBox(height: 8),
                      const Text('Saved drafts will appear here', style: TextStyle(color: AppColors.nobObserver, fontSize: 14, height: 1.5)),
                    ],
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl),
            itemCount: drafts.length,
            itemBuilder: (_, i) => _DraftCard(post: drafts[i]),
          );
        },
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  final Post post;
  const _DraftCard({required this.post});

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
        border: Border.all(color: AppColors.nobBorder, width: 0.5),
        boxShadow: Premium.shadowMd,
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
              preview.isEmpty ? '(empty draft)' : preview,
              style: TextStyle(
                color: preview.isEmpty
                    ? AppColors.nobObserver
                    : AppColors.textPrimary,
                fontSize: 14,
                height: 1.55,
                fontStyle: preview.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Action row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.nobObserver,
                    side: const BorderSide(color: AppColors.nobBorder),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: 8),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NobComposeScreen()),
                  ),
                  child: const Text('Edit'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald600,
                    foregroundColor: AppColors.nobBackground,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: 8),
                    minimumSize: Size.zero,
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  onPressed: () => _publish(context, ref),
                  child: const Text('Publish'),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      ref.read(postsProvider.notifier).deletePost(post.id),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final canPublish =
        await ref.read(postsProvider.notifier).canPublishToday(post.nobType);
    if (!context.mounted) return;
    if (!canPublish) {
      ToastService.show(context, message: 'You need at least 20 characters to publish', type: ToastType.error);
      return;
    }
    final ok = await ref.read(postsProvider.notifier).publishDraft(post.id);
    if (!context.mounted) return;
    if (ok) {
      ToastService.show(context, message: 'Published!', type: ToastType.success);
      Navigator.pop(context);
    }
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
