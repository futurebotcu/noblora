import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/bff_provider.dart';
import 'bff_suggestion_card.dart';

const _teal = Color(0xFF26C6DA);

class BffScreen extends ConsumerStatefulWidget {
  const BffScreen({super.key});

  @override
  ConsumerState<BffScreen> createState() => _BffScreenState();
}

class _BffScreenState extends ConsumerState<BffScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bffProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bffProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060E0E),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.people_rounded, color: _teal, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Noble BFF',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: () => ref.read(bffProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _teal),
            )
          : state.suggestions.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  color: _teal,
                  onRefresh: () => ref.read(bffProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.xxxxl,
                    ),
                    itemCount: state.suggestions.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _HeaderBanner();
                      final sug = state.suggestions[i - 1];
                      return BffSuggestionCard(
                        suggestion: sug,
                        onConnect: () => _onAction(sug.id, 'connect'),
                        onPass: () => _onAction(sug.id, 'pass'),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _onAction(String suggestionId, String action) async {
    final result =
        await ref.read(bffProvider.notifier).actOnSuggestion(suggestionId, action);

    if (!mounted) return;
    final message = switch (result) {
      'connected' => 'Connected! Check your chats.',
      'waiting' => action == 'connect'
          ? 'Nice! Waiting for them to connect too.'
          : 'Passed.',
      'passed' => 'Passed.',
      _ => 'Done.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result == 'connected' ? _teal : AppColors.surface,
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: _teal.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: _teal.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'AI finds people you might vibe with. Both of you see this at the same time.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
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
            Icon(Icons.people_outline_rounded,
                color: _teal.withValues(alpha: 0.3), size: 72),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No suggestions yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Our AI is finding people you might get along with.\nCheck back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
