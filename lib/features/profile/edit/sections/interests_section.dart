import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';

class InterestsSection extends ConsumerStatefulWidget {
  const InterestsSection({super.key});
  @override
  ConsumerState<InterestsSection> createState() => _State();
}

class _State extends ConsumerState<InterestsSection> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: ProfileOptions.interestCategories.length + 1, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(editProfileProvider).draft;
    final categories = ProfileOptions.interestCategories;
    final allItems = categories.values.expand((v) => v).toList();

    return EditSectionShell(
      title: 'Interests',
      description: 'Select what you enjoy. Pin your top 5 favorites.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search interests...', hintStyle: TextStyle(color: context.textDisabled),
                prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 20),
                filled: true, fillColor: context.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), borderSide: BorderSide.none),
              ),
            ),
          ),
          // Selected count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Row(children: [
              Text('${d.interests.length} selected', style: TextStyle(color: context.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (d.interests.isNotEmpty)
                GestureDetector(
                  onTap: () => ref.read(editProfileProvider.notifier).updateDraft((d) { d.interests = []; return d; }),
                  child: Text('Clear all', style: TextStyle(color: context.textMuted, fontSize: 12)),
                ),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Tabs
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: context.accent,
            labelColor: context.accent,
            unselectedLabelColor: context.textMuted,
            dividerColor: Colors.transparent,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'All'),
              ...categories.keys.map((k) => Tab(text: k)),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildGrid(context, _filter(allItems), d.interests),
                ...categories.values.map((items) => _buildGrid(context, _filter(items), d.interests)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _filter(List<String> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((i) => i.toLowerCase().contains(q)).toList();
  }

  Widget _buildGrid(BuildContext context, List<String> items, List<String> selected) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: items.map((item) {
          final active = selected.contains(item);
          return GestureDetector(
            onTap: () => ref.read(editProfileProvider.notifier).updateDraft((d) {
              final l = List<String>.from(d.interests);
              active ? l.remove(item) : l.add(item);
              d.interests = l;
              return d;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? context.accent.withValues(alpha: 0.12) : context.surfaceColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                border: Border.all(color: active ? context.accent.withValues(alpha: 0.5) : context.borderColor, width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (active) ...[Icon(Icons.check_rounded, size: 14, color: context.accent), const SizedBox(width: 4)],
                Text(item, style: TextStyle(color: active ? context.accent : context.textMuted, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
