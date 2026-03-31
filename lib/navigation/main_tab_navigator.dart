import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../features/admin/admin_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/noblara_feed/noblara_feed_screen.dart';
import '../features/status/status_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/tier_promotion_screen.dart';
import '../data/models/post.dart';
import '../providers/notification_provider.dart';
import '../providers/posts_provider.dart';

class MainTabNavigator extends ConsumerStatefulWidget {
  const MainTabNavigator({super.key});

  @override
  ConsumerState<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends ConsumerState<MainTabNavigator> {
  int _currentIndex = 0;
  // Tracks which tab indices have been visited — unvisited tabs are not built
  final Set<int> _visitedTabs = {0};

  static const _baseTabs = [
    _TabItem(label: 'Discover', icon: Icons.explore_outlined, activeIcon: Icons.explore),
    _TabItem(label: 'Noblara', icon: Icons.article_outlined, activeIcon: Icons.article),
    _TabItem(label: 'Chats', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble),
    _TabItem(label: 'Status', icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart),
    _TabItem(label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  static const _adminTab = _TabItem(
    label: 'Admin',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings_rounded,
  );

  static const _baseScreens = [
    FeedScreen(),
    NoblaraFeedScreen(),
    MatchesScreen(),
    StatusScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        ref.watch(isAdminProvider).maybeWhen(data: (v) => v, orElse: () => false);
    final tabs = isAdmin ? [..._baseTabs, _adminTab] : _baseTabs;
    final screens = isAdmin
        ? [..._baseScreens, const AdminScreen()]
        : _baseScreens;

    final notifState = ref.watch(notificationProvider);

    // Show in-app banner when a new notification arrives
    ref.listen<NotificationState>(notificationProvider, (prev, next) {
      final latest = next.latestUnread;
      if (latest == null) return;
      if (prev?.latestUnread?.id == latest.id) return;

      ref.read(notificationProvider.notifier).clearLatest();

      // Tier promotion → show celebration screen
      if (latest.type == 'tier_promoted') {
        final newTier = latest.data?['new_tier'] as String?;
        if (newTier != null && (newTier == 'noble' || newTier == 'explorer')) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TierPromotionScreen(
                newTier: NobTier.fromString(newTier),
              ),
            ),
          );
          return;
        }
      }

      final isVideoProposed = latest.type == 'video_proposed' ||
          latest.type == 'video_confirmed';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isVideoProposed
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              Icon(
                isVideoProposed
                    ? Icons.videocam_rounded
                    : Icons.notifications_rounded,
                color: AppColors.gold,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      latest.body,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isVideoProposed)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    setState(() => _currentIndex = 2); // Go to Chats tab
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('View',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      );
    });

    final unreadCount = notifState.unreadCount;

    // Clamp index when admin tab appears/disappears
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Stack(
        children: screens.asMap().entries.map((entry) {
          final i = entry.key;
          final screen = entry.value;
          final isActive = i == safeIndex;
          if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
          return Offstage(
            offstage: !isActive,
            child: TickerMode(enabled: isActive, child: screen),
          );
        }).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() {
          _currentIndex = i;
          _visitedTabs.add(i);
        }),
        items: tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          // Show badge only on "Chats" tab (index 2)
          final showBadge = i == 2 && unreadCount > 0;
          return BottomNavigationBarItem(
            icon: showBadge
                ? Badge(
                    label: Text('$unreadCount'),
                    backgroundColor: AppColors.error,
                    child: Icon(t.icon),
                  )
                : Icon(t.icon),
            activeIcon: showBadge
                ? Badge(
                    label: Text('$unreadCount'),
                    backgroundColor: AppColors.error,
                    child: Icon(t.activeIcon),
                  )
                : Icon(t.activeIcon),
            label: t.label,
          );
        }).toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
