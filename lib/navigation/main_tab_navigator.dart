import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/mock_mode.dart';
import '../providers/auth_provider.dart';
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

  static final navigatorKey = GlobalKey<_MainTabNavigatorState>();

  /// Switch to a tab by index from anywhere in the app.
  static void switchTab(int index) {
    navigatorKey.currentState?._switchTo(index);
  }

  @override
  ConsumerState<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends ConsumerState<MainTabNavigator> {
  int _currentIndex = 0;
  // Tracks which tab indices have been visited — unvisited tabs are not built
  final Set<int> _visitedTabs = {0};

  void _switchTo(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  static const _baseTabs = [
    _TabItem(label: 'Discover', icon: Icons.explore_outlined, activeIcon: Icons.explore_outlined),
    _TabItem(label: 'Noblara', icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_outlined),
    _TabItem(label: 'Chats', icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_outline_rounded),
    _TabItem(label: 'Status', icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart_rounded),
    _TabItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_outline_rounded),
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
    ref.listen<NotificationState>(notificationProvider, (prev, next) async {
      final latest = next.latestUnread;
      if (latest == null) return;
      if (prev?.latestUnread?.id == latest.id) return;

      ref.read(notificationProvider.notifier).clearLatest();

      // Gate by notification category preferences
      if (!isMockMode) {
        try {
          final uid = ref.read(authProvider).userId;
          if (uid != null) {
            final row = await Supabase.instance.client.from('profiles')
                .select('notification_preferences').eq('id', uid).maybeSingle();
            final prefs = row?['notification_preferences'] as Map<String, dynamic>?;
            if (prefs != null) {
              final typeToCategory = {
                'new_match': 'new_match', 'bff_connected': 'new_match', 'connection_closed': 'new_match',
                'new_message': 'new_message', 'chat_opened': 'new_message',
                'signal_received': 'signals', 'note_received': 'notes',
                'bff_reach_out': 'bff_suggestion', 'event_farewell': 'event_activity',
                'video_proposed': 'new_match', 'video_confirmed': 'new_match',
              };
              final category = typeToCategory[latest.type];
              if (category != null && prefs[category] == false) return; // Suppressed by user
            }
          }
        } catch (_) {}
      }

      // Tier promotion → show celebration screen
      if (latest.type == 'tier_promoted') {
        final newTier = latest.data?['new_tier'] as String?;
        if (newTier != null && (newTier == 'noble' || newTier == 'explorer') && context.mounted) {
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

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isVideoProposed
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : context.borderColor,
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
                      style: TextStyle(
                        color: context.textMuted,
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(color: context.borderColor, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          elevation: 0,
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
