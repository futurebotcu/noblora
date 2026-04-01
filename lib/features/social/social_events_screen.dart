import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/event_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/interaction_gate_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../filters/filter_bottom_sheet.dart';
import 'event_card_widget.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'rooms_tab.dart';

const _violet = Color(0xFF9B6DFF);

class SocialEventsScreen extends ConsumerStatefulWidget {
  const SocialEventsScreen({super.key});

  @override
  ConsumerState<SocialEventsScreen> createState() => _SocialEventsScreenState();
}

class _SocialEventsScreenState extends ConsumerState<SocialEventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.lg,
        title: const ModeSwitcher(),
        actions: [
          _SocialFilterButton(ref: ref),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _PillTabBar(controller: _tabCtrl),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _EventsTab(ref: ref),
          const RoomsTab(),
        ],
      ),
    );
  }
}

// ─── Pill Tab Bar ─────────────────────────────────────────────────

class _PillTabBar extends StatelessWidget {
  final TabController controller;
  const _PillTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
            border: Border.all(color: context.borderSubtleColor, width: 0.5),
          ),
          child: Row(
            children: [
              _PillTab(
                label: 'Events',
                isActive: controller.index == 0,
                onTap: () => controller.animateTo(0),
              ),
              _PillTab(
                label: 'Rooms',
                isActive: controller.index == 1,
                onTap: () => controller.animateTo(1),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? _violet : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : context.textMuted,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Events Tab (existing content, extracted) ─────────────────────

class _EventsTab extends StatelessWidget {
  final WidgetRef ref;
  const _EventsTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventListProvider);

    return Stack(
      children: [
        if (state.isLoading && state.events.isEmpty)
          const Center(child: CircularProgressIndicator(color: _violet))
        else if (state.events.isEmpty)
          _EmptyEvents()
        else
          RefreshIndicator(
            color: _violet,
            onRefresh: () => ref.read(eventListProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxxxl + 60,
              ),
              itemCount: state.events.length,
              itemBuilder: (context, i) {
                final event = state.events[i];
                return EventCardWidget(
                  event: event,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(eventId: event.id),
                    ),
                  ),
                  onJoin: event.isFull
                      ? null
                      : () async {
                          final gate = ref
                                  .read(interactionGateProvider)
                                  .valueOrNull ??
                              const InteractionGate();
                          if (!gate.canSocialInteract) {
                            if (context.mounted) {
                              showGatingPopup(
                                  context, gate.blockReason('social'));
                            }
                            return;
                          }
                          final result = await ref
                              .read(eventListProvider.notifier)
                              .joinEvent(event.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result == 'joined'
                                  ? 'You\'re going!'
                                  : result),
                              backgroundColor: result == 'joined'
                                  ? _violet
                                  : context.surfaceColor,
                            ),
                          );
                        },
                );
              },
            ),
          ),
        // FAB for creating events
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.xxl,
          child: FloatingActionButton(
            heroTag: 'create_event_fab',
            backgroundColor: _violet,
            onPressed: () async {
              final gate = ref.read(interactionGateProvider).valueOrNull ??
                  const InteractionGate();
              if (!gate.canSocialInteract) {
                if (context.mounted) {
                  showGatingPopup(context, gate.blockReason('social'));
                }
                return;
              }
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateEventScreen()),
              );
              if (created == true) {
                ref.read(eventListProvider.notifier).load();
              }
            },
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _violet.withValues(alpha: 0.04),
                border: Border.all(color: _violet.withValues(alpha: 0.1)),
              ),
              child: Icon(
                Icons.event_outlined,
                color: _violet.withValues(alpha: 0.4),
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No events yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Be the first to create one!\nTap + to get started.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: context.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialFilterButton extends StatelessWidget {
  final WidgetRef ref;
  const _SocialFilterButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final count =
        ref.watch(filterProvider.select((f) => f.activeCount(NobleMode.social)));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          color: count > 0 ? _violet : context.textMuted,
          onPressed: () => FilterBottomSheet.show(context),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 16,
              height: 16,
              decoration:
                  const BoxDecoration(color: _violet, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: context.bgColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
