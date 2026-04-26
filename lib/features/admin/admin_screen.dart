import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/admin_provider.dart';
import '../../providers/posts_provider.dart';

// ---------------------------------------------------------------------------
// Admin data models
// ---------------------------------------------------------------------------

class _VerificationItem {
  final String userId;
  final String displayName;
  final String type; // 'photo' | 'gender' | 'instagram'
  final String status;
  final String? photoUrl;
  final DateTime createdAt;

  const _VerificationItem({
    required this.userId,
    required this.displayName,
    required this.type,
    required this.status,
    this.photoUrl,
    required this.createdAt,
  });
}

class _AdminStats {
  final int totalUsers;
  final int pendingVerifications;
  final int activeMatches;
  final int postsToday;

  const _AdminStats({
    this.totalUsers = 0,
    this.pendingVerifications = 0,
    this.activeMatches = 0,
    this.postsToday = 0,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _adminStatsProvider = FutureProvider<_AdminStats>((ref) async {
  if (isMockMode) {
    return const _AdminStats(
      totalUsers: 42,
      pendingVerifications: 5,
      activeMatches: 12,
      postsToday: 8,
    );
  }
  final stats = await ref.read(adminRepositoryProvider).fetchStats();
  return _AdminStats(
    totalUsers: stats.totalUsers,
    pendingVerifications: stats.pendingVerifications,
    activeMatches: stats.activeMatches,
    postsToday: stats.postsToday,
  );
});

final _pendingVerificationsProvider =
    FutureProvider<List<_VerificationItem>>((ref) async {
  if (isMockMode) {
    return [
      _VerificationItem(
        userId: 'mock-u1',
        displayName: 'Zeynep K.',
        type: 'photo',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _VerificationItem(
        userId: 'mock-u2',
        displayName: 'Ali M.',
        type: 'gender',
        status: 'manual_review',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];
  }
  final rows = await ref.read(adminRepositoryProvider).fetchPendingVerifications();
  return rows
      .map((r) => _VerificationItem(
            userId: r['user_id'] as String,
            displayName: r['display_name'] as String,
            type: 'photo',
            status: r['status'] as String,
            photoUrl: r['photo_url'] as String?,
            createdAt: DateTime.parse(r['created_at'] as String),
          ))
      .toList();
});

// ---------------------------------------------------------------------------
// Admin Screen
// ---------------------------------------------------------------------------

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.emerald500, size: 20),
            SizedBox(width: AppSpacing.sm),
            Text('Admin',
                style: TextStyle(
                    color: AppColors.emerald500, fontWeight: FontWeight.w700)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.emerald500,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.emerald500,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Verifications'),
            Tab(text: 'Posts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OverviewTab(),
          _VerificationsTab(),
          _PostsModerationTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview tab
// ---------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.emerald500)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error))),
      data: (stats) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _StatCard(
                    label: 'Total Users',
                    value: stats.totalUsers,
                    icon: Icons.people_rounded,
                    color: AppColors.emerald500),
                _StatCard(
                    label: 'Pending Reviews',
                    value: stats.pendingVerifications,
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning),
                _StatCard(
                    label: 'Active Matches',
                    value: stats.activeMatches,
                    icon: Icons.favorite_rounded,
                    color: AppColors.emerald500),
                _StatCard(
                    label: 'Posts Today',
                    value: stats.postsToday,
                    icon: Icons.article_rounded,
                    color: const Color(0xFF9C27B0)),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const Text(
              'Quick Actions',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  side: const BorderSide(color: AppColors.border)),
              leading: const Icon(Icons.refresh_rounded, color: AppColors.emerald500),
              title: const Text('Refresh Stats',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              onTap: () => ref.invalidate(_adminStatsProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$value',
            style: TextStyle(
                color: color, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verifications tab
// ---------------------------------------------------------------------------

class _VerificationsTab extends ConsumerWidget {
  const _VerificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_pendingVerificationsProvider);

    return listAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.emerald500)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error))),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.emerald500, size: 48),
                SizedBox(height: AppSpacing.lg),
                Text('All caught up!',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: items.length,
          itemBuilder: (_, i) => _VerificationCard(
            item: items[i],
            onApprove: () => _approve(context, ref, items[i]),
            onReject: () => _reject(context, ref, items[i]),
          ),
        );
      },
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, _VerificationItem item) async {
    await ref.read(adminRepositoryProvider).approvePhotoVerification(item.userId);
    ref.invalidate(_pendingVerificationsProvider);
    ref.invalidate(_adminStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.displayName} approved'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, _VerificationItem item) async {
    await ref.read(adminRepositoryProvider).rejectPhotoVerification(item.userId);
    ref.invalidate(_pendingVerificationsProvider);
    ref.invalidate(_adminStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rejected'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }
}

class _VerificationCard extends StatelessWidget {
  final _VerificationItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _VerificationCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(item.createdAt);
    final ago = diff.inHours < 1
        ? '${diff.inMinutes}m ago'
        : '${diff.inHours}h ago';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.photoUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.surfaceAlt,
                      child: const Icon(Icons.person_rounded,
                          color: AppColors.textDisabled),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.textDisabled),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          ago,
                          style: const TextStyle(
                              color: AppColors.textDisabled, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald500,
                    foregroundColor: AppColors.textOnEmerald,
                  ),
                  onPressed: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Posts moderation tab
// ---------------------------------------------------------------------------

class _PostsModerationTab extends ConsumerWidget {
  const _PostsModerationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: _loadRecentPosts(ref),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.emerald500));
        }
        final posts = snap.data ?? <Map<String, dynamic>>[];
        if (posts.isEmpty) {
          return const Center(
            child: Text('No posts to moderate.',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final p = posts[i];
            return _PostModerationCard(
              postId: p['id'] as String,
              content: p['content'] as String,
              authorName: p['author'] as String? ?? 'Unknown',
              onDelete: () async {
                await ref.read(postRepositoryProvider).deletePost(p['id'] as String);
                // ignore: use_build_context_synchronously
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post removed')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecentPosts(WidgetRef ref) async {
    return ref.read(adminRepositoryProvider).fetchRecentPosts();
  }
}

class _PostModerationCard extends StatelessWidget {
  final String postId;
  final String content;
  final String authorName;
  final VoidCallback onDelete;

  const _PostModerationCard({
    required this.postId,
    required this.content,
    required this.authorName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            authorName,
            style: const TextStyle(
                color: AppColors.emerald500,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            content,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.4),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 16),
              label: const Text('Remove',
                  style: TextStyle(color: AppColors.error, fontSize: 12)),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
