import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/event_provider.dart';
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
        title: Row(
          children: [
            const Icon(Icons.explore_rounded, color: _violet, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Noble Social',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _violet,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
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
