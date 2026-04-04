import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/event.dart';
import '../../providers/event_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/interaction_gate_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../filters/filter_bottom_sheet.dart';
import 'event_card_widget.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';
import 'rooms_tab.dart';

const _violet = AppColors.violet;

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
          const _EventsTab(),
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

// ─── Events Tab (grid/list toggle) ───────────────────────────────

class _EventsTab extends ConsumerStatefulWidget {
  const _EventsTab();
  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {
  bool _listView = false;

  void _openDetail(String eventId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId)));
  }

  Future<void> _joinEvent(String eventId) async {
    final gate = ref.read(interactionGateProvider).valueOrNull ?? InteractionGate.loading;
    if (!gate.canSocialJoin) {
      if (mounted) showGatingPopup(context, 'Add a photo first', 'Upload a photo to join events and rooms.');
      return;
    }
    final result = await ref.read(eventListProvider.notifier).joinEvent(eventId);
    if (!mounted) return;
    ToastService.show(context, message: result == 'joined' ? 'You\'re going!' : result, type: result == 'joined' ? ToastType.event : ToastType.error);
  }

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
          Column(
            children: [
              // View toggle row
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    Text('${state.events.length} events', style: TextStyle(color: context.textMuted, fontSize: 12)),
                    const Spacer(),
                    _ViewToggle(isListView: _listView, onToggle: () => setState(() => _listView = !_listView)),
                  ],
                ),
              ),
              // Event list
              Expanded(
                child: RefreshIndicator(
                  color: _violet,
                  onRefresh: () => ref.read(eventListProvider.notifier).load(),
                  child: _listView
                      ? ListView.separated(
                          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxxxl + 60),
                          itemCount: state.events.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: context.borderSubtleColor, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                          itemBuilder: (context, i) {
                            final event = state.events[i];
                            return _EventListRow(
                              event: event,
                              onTap: () => _openDetail(event.id),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxxxl + 60),
                          itemCount: state.events.length,
                          itemBuilder: (context, i) {
                            final event = state.events[i];
                            return EventCardWidget(
                              event: event,
                              onTap: () => _openDetail(event.id),
                              onJoin: event.isFull ? null : () => _joinEvent(event.id),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        // FAB for creating events
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.xxl,
          child: FloatingActionButton(
            heroTag: 'create_event_fab',
            backgroundColor: _violet,
            onPressed: () async {
              final gate = ref.read(interactionGateProvider).valueOrNull ?? InteractionGate.loading;
              if (!gate.canSocialCreate) {
                if (context.mounted) {
                  showGatingPopup(context, 'Verify your photo',
                      'Verify your profile photo to host events and create rooms.',
                      type: GatePopupType.verifyPhoto);
                }
                return;
              }
              final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()));
              if (created == true) ref.read(eventListProvider.notifier).load();
            },
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ─── View Toggle Button ──────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool isListView;
  final VoidCallback onToggle;
  const _ViewToggle({required this.isListView, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderSubtleColor, width: 0.5),
        ),
        child: Icon(
          isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          color: context.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Compact List Row ────────────────────────────────────────────

class _EventListRow extends StatelessWidget {
  final NobEvent event;
  final VoidCallback onTap;
  const _EventListRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final day = event.eventDate.day.toString();
    final month = DateFormat.MMM().format(event.eventDate);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            // Date block
            SizedBox(
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(day, style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w700, height: 1)),
                  Text(month, style: TextStyle(color: AppColors.gold.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Title + location
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (event.locationText != null && event.locationText!.isNotEmpty)
                    Text(event.locationText!,
                        style: TextStyle(color: context.textMuted, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Attendee count pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${event.attendeeCount}', style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: context.textMuted, size: 18),
          ],
        ),
      ),
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
