import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/event_provider.dart';
import '../../providers/filter_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../filters/filter_bottom_sheet.dart';
import 'event_card_widget.dart';
import 'event_detail_screen.dart';
import 'create_event_screen.dart';

const _violet = Color(0xFFAB47BC);

class SocialEventsScreen extends ConsumerStatefulWidget {
  const SocialEventsScreen({super.key});

  @override
  ConsumerState<SocialEventsScreen> createState() => _SocialEventsScreenState();
}

class _SocialEventsScreenState extends ConsumerState<SocialEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090610),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090610),
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.lg,
        title: const ModeSwitcher(),
        actions: [
          _SocialFilterButton(ref: ref),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _violet),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CreateEventScreen()),
              );
              if (created == true) ref.read(eventListProvider.notifier).load();
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: _violet))
          : state.events.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  color: _violet,
                  onRefresh: () => ref.read(eventListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xxxxl),
                    itemCount: state.events.length,
                    itemBuilder: (context, i) {
                      final event = state.events[i];
                      return EventCardWidget(
                        event: event,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id)),
                        ),
                        onJoin: event.isFull
                            ? null
                            : () async {
                                final result = await ref.read(eventListProvider.notifier).joinEvent(event.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result == 'joined' ? 'You\'re going!' : result),
                                    backgroundColor: result == 'joined' ? _violet : AppColors.surface,
                                  ),
                                );
                              },
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_outlined, color: _violet.withValues(alpha: 0.3), size: 72),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Be the first to create one!\nTap + to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
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
    final count = ref.watch(filterProvider.select((f) => f.activeCount(NobleMode.social)));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          color: count > 0 ? _violet : AppColors.textMuted,
          onPressed: () => FilterBottomSheet.show(context),
        ),
        if (count > 0)
          Positioned(
            right: 4, top: 4,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: _violet, shape: BoxShape.circle),
              child: Center(
                child: Text('$count', style: const TextStyle(color: AppColors.bg, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
      ],
    );
  }
}
