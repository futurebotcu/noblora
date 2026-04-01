import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';

/// Full-screen searchable multi-select list (for countries, languages, etc.)
class SearchableMultiSelectScreen extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> selected;
  final String? searchHint;

  const SearchableMultiSelectScreen({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    this.searchHint,
  });

  /// Opens the screen and returns updated selection
  static Future<List<String>?> show(
    BuildContext context, {
    required String title,
    required List<String> items,
    required List<String> selected,
    String? searchHint,
  }) {
    return Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchableMultiSelectScreen(
          title: title,
          items: items,
          selected: selected,
          searchHint: searchHint,
        ),
      ),
    );
  }

  @override
  State<SearchableMultiSelectScreen> createState() => _State();
}

class _State extends State<SearchableMultiSelectScreen> {
  late List<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  List<String> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items.where((i) => i.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text('Done (${_selected.length})', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.searchHint ?? 'Search...',
                hintStyle: TextStyle(color: context.textDisabled),
                prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 20),
                filled: true,
                fillColor: context.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), borderSide: BorderSide.none),
              ),
            ),
          ),
          // Selected chips
          if (_selected.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                itemCount: _selected.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => Chip(
                  label: Text(_selected[i], style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.gold),
                  onDeleted: () => setState(() => _selected.remove(_selected[i])),
                  backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCircle)),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final isSelected = _selected.contains(item);
                return ListTile(
                  title: Text(item, style: TextStyle(color: context.textPrimary, fontSize: 14)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 22)
                      : Icon(Icons.circle_outlined, color: context.borderColor, size: 22),
                  onTap: () {
                    setState(() {
                      isSelected ? _selected.remove(item) : _selected.add(item);
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
