import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/super_like_repository.dart';
import '../../providers/status_provider.dart';

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(statusProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        titleSpacing: AppSpacing.lg,
        title: const Text(
          'Status',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.read(statusProvider.notifier).refresh(),
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => ref.read(statusProvider.notifier).refresh(),
                child: const Text('Retry', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(statusProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxxl),
            children: [
              _ActivitySection(data: data),
              const SizedBox(height: AppSpacing.xxxl),
              _WhoLikesYouSection(data: data),
              const SizedBox(height: AppSpacing.xxxl),
              _BoostSection(data: data),
              const SizedBox(height: AppSpacing.xxxl),
              _SuperLikeSection(data: data),
              const SizedBox(height: AppSpacing.xxxl),
              _RewindSection(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header helper
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Section 1: Your Activity
// ---------------------------------------------------------------------------

class _ActivitySection extends StatelessWidget {
  final StatusData data;
  const _ActivitySection({required this.data});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (icon: Icons.visibility_rounded, value: data.profileViews, label: 'Profile Views', color: AppColors.gold),
      (icon: Icons.favorite_rounded, value: data.matchCount, label: 'Matches', color: const Color(0xFFEF5350)),
      (icon: Icons.thumb_up_rounded, value: data.reactionCount, label: 'Reactions', color: const Color(0xFF26C6DA)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Your Activity'),
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) {
              final c = cards[i];
              return Container(
                width: 120,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: c.color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(c.icon, color: c.color, size: 20),
                    Text(
                      '${c.value}',
                      style: TextStyle(
                        color: c.color,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(c.label,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section 2: Who Likes You
// ---------------------------------------------------------------------------

class _WhoLikesYouSection extends StatefulWidget {
  final StatusData data;
  const _WhoLikesYouSection({required this.data});

  @override
  State<_WhoLikesYouSection> createState() => _WhoLikesYouSectionState();
}

class _WhoLikesYouSectionState extends State<_WhoLikesYouSection>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Who Likes You'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tab,
                  labelColor: AppColors.gold,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.gold,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: 'Liked You (${d.likedMe.length})'),
                    Tab(text: 'You Liked (${d.iLiked.length})'),
                    Tab(text: 'Super ★ (${d.superLikesReceived.length})'),
                  ],
                ),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _WhoLikedList(items: d.likedMe),
                      _WhoLikedList(items: d.iLiked),
                      _WhoLikedList(items: d.superLikesReceived, isSuperLike: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WhoLikedList extends StatelessWidget {
  final List<WhoLikedItem> items;
  final bool isSuperLike;
  const _WhoLikedList({required this.items, this.isSuperLike = false});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No one yet', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      itemBuilder: (_, i) => _WhoLikedTile(item: items[i], isSuperLike: isSuperLike),
    );
  }
}

class _WhoLikedTile extends StatelessWidget {
  final WhoLikedItem item;
  final bool isSuperLike;
  const _WhoLikedTile({required this.item, this.isSuperLike = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Avatar
          SizedBox(
            width: 44,
            height: 44,
            child: ClipOval(
              child: item.photoUrl != null
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Image.network(
                        item.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _FallbackAvatar(name: item.name),
                      ),
                    )
                  : _FallbackAvatar(name: item.name),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.mode == 'bff' ? 'BFF' : 'Date',
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (isSuperLike)
            const Icon(Icons.star_rounded, color: Color(0xFF42A5F5), size: 18),
        ],
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String name;
  const _FallbackAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gold.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 3: Boost
// ---------------------------------------------------------------------------

class _BoostSection extends ConsumerStatefulWidget {
  final StatusData data;
  const _BoostSection({required this.data});

  @override
  ConsumerState<_BoostSection> createState() => _BoostSectionState();
}

class _BoostSectionState extends ConsumerState<_BoostSection> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_BoostSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final until = widget.data.boostActiveUntil;
    if (until != null && until.isAfter(DateTime.now())) {
      _remaining = until.difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final r = widget.data.boostActiveUntil!.difference(DateTime.now());
        if (!mounted) return;
        if (r.isNegative) {
          _timer?.cancel();
          setState(() => _remaining = Duration.zero);
        } else {
          setState(() => _remaining = r);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.data.isBoostActive && _remaining > Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Boost'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isActive
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'Boost Active' : 'Boost Your Profile',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isActive
                            ? 'You\'re being shown first · ${_fmt(_remaining)} left'
                            : 'Be shown first for 30 minutes · Free daily',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (!isActive)
                  GestureDetector(
                    onTap: () => ref.read(statusProvider.notifier).activateBoost(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCircle),
                      ),
                      child: const Text(
                        'Boost',
                        style: TextStyle(
                          color: AppColors.bg,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section 4: Super Like
// ---------------------------------------------------------------------------

class _SuperLikeSection extends StatelessWidget {
  final StatusData data;
  const _SuperLikeSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Super Like'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFF42A5F5), size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Super Likes Remaining',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${data.superLikesRemaining} / 3 today · Tap ★ on a card to super like',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Big remaining count
                Text(
                  '${data.superLikesRemaining}',
                  style: const TextStyle(
                    color: Color(0xFF42A5F5),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section 5: Rewind
// ---------------------------------------------------------------------------

class _RewindSection extends StatelessWidget {
  final StatusData data;
  const _RewindSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Rewind'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.undo_rounded,
                      color: AppColors.warning, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rewinds Remaining',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${data.rewindsRemaining} / 3 today · Tap ↩ in feed to undo',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${data.rewindsRemaining}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
