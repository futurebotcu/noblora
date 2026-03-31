import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/bff_suggestion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bff_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/note_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../filters/filter_bottom_sheet.dart';
import 'bff_suggestion_card.dart';

const _teal = Color(0xFF26C6DA);

class BffScreen extends ConsumerStatefulWidget {
  const BffScreen({super.key});

  @override
  ConsumerState<BffScreen> createState() => _BffScreenState();
}

class _BffScreenState extends ConsumerState<BffScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bffProvider.notifier).load();
      // Trigger real suggestion generation
      ref.read(bffProvider.notifier).generateSuggestions();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bffProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060E0E),
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.lg,
        title: const ModeSwitcher(),
        actions: [
          _FilterButton(ref: ref),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.read(bffProvider.notifier).load(),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _teal,
          labelColor: _teal,
          unselectedLabelColor: AppColors.textMuted,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: 'Suggestions${state.suggestions.isNotEmpty ? ' (${state.suggestions.length})' : ''}'),
            Tab(text: 'Reach Outs${state.reachOuts.isNotEmpty ? ' (${state.reachOuts.length})' : ''}'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Tab 1: AI Suggestions ──
          _SuggestionsTab(state: state),
          // ── Tab 2: Reach Outs Received ──
          _ReachOutsTab(reachOuts: state.reachOuts),
        ],
      ),
    );
  }
}

// ─── Suggestions Tab ─────────────────────────────────────────────────

class _SuggestionsTab extends ConsumerWidget {
  final BffState state;
  const _SuggestionsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }
    if (state.suggestions.isEmpty) return _EmptyState();

    return RefreshIndicator(
      color: _teal,
      onRefresh: () => ref.read(bffProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xxxxl),
        itemCount: state.suggestions.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _HeaderBanner();
          final sug = state.suggestions[i - 1];
          return BffSuggestionCard(
            suggestion: sug,
            onConnect: () => _onAction(context, ref, sug.id, 'connect'),
            onPass: () => _onAction(context, ref, sug.id, 'pass'),
            onReachOut: () async {
              final sent = await ref.read(bffProvider.notifier).sendReachOut(sug.otherUserId(ref.read(authProvider).userId ?? ''));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(sent ? 'Reached out!' : 'Limit reached'),
                backgroundColor: sent ? _teal : AppColors.surface,
              ));
            },
            onNote: () => _showNoteDialog(context, ref, sug),
          );
        },
      ),
    );
  }

  void _showNoteDialog(BuildContext context, WidgetRef ref, BffSuggestion sug) {
    final ctrl = TextEditingController();
    final uid = ref.read(authProvider).userId ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Note to ${sug.otherUserName ?? 'user'}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl, maxLength: 280, maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Write something thoughtful...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              ref.read(noteInboxProvider.notifier).sendNote(
                receiverId: sug.otherUserId(uid),
                targetType: 'profile',
                targetId: sug.otherUserId(uid),
                content: text,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note sent'), backgroundColor: _teal),
              );
            },
            child: const Text('Send', style: TextStyle(color: _teal)),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String id, String action) async {
    final result = await ref.read(bffProvider.notifier).actOnSuggestion(id, action);
    if (!context.mounted) return;
    final message = switch (result) {
      'connected' => 'Connected! Check your chats.',
      'waiting' => action == 'connect' ? 'Nice! Waiting for them too.' : 'Passed.',
      'passed' => 'Passed.',
      _ => 'Done.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: result == 'connected' ? _teal : AppColors.surface),
    );
  }
}

// ─── Reach Outs Tab ──────────────────────────────────────────────────

class _ReachOutsTab extends ConsumerWidget {
  final List<Map<String, dynamic>> reachOuts;
  const _ReachOutsTab({required this.reachOuts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reachOuts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_rounded, color: _teal.withValues(alpha: 0.3), size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text('No reach outs yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text('When someone reaches out, you\'ll see them here.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: reachOuts.length,
      itemBuilder: (context, i) {
        final ro = reachOuts[i];
        final profile = ro['profiles'] as Map<String, dynamic>?;
        final name = profile?['display_name'] as String? ?? 'Someone';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _teal.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _teal.withValues(alpha: 0.2),
                child: Text(name[0].toUpperCase(), style: const TextStyle(color: _teal, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('reached out to you', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                onPressed: () async {
                  final roId = ro['id'] as String;
                  final repo = ref.read(bffRepositoryProvider);
                  final result = await repo.acceptReachOut(roId);
                  if (!context.mounted) return;
                  final msg = result['result'] == 'connected'
                      ? 'Connected! Check your chats.'
                      : (result['error'] as String? ?? 'Error');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: result['result'] == 'connected' ? _teal : AppColors.surface),
                  );
                  ref.read(bffProvider.notifier).load();
                },
                child: const Text('Connect'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: _teal.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: _teal.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'AI finds people you might vibe with. Both of you see this at the same time.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
              ),
            ),
          ],
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
            Icon(Icons.people_outline_rounded, color: _teal.withValues(alpha: 0.3), size: 72),
            const SizedBox(height: AppSpacing.xxl),
            Text('No suggestions yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text('Our AI is finding people you might get along with.\nCheck back soon!',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final WidgetRef ref;
  const _FilterButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(filterProvider.select((f) => f.activeCount(NobleMode.bff)));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          color: count > 0 ? _teal : AppColors.textMuted,
          onPressed: () => FilterBottomSheet.show(context),
        ),
        if (count > 0)
          Positioned(
            right: 4, top: 4,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
              child: Center(child: Text('$count', style: const TextStyle(color: AppColors.bg, fontSize: 9, fontWeight: FontWeight.w800))),
            ),
          ),
      ],
    );
  }
}
