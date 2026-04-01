import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/room.dart';
import '../../services/gemini_service.dart';

const _violet = Color(0xFF9B6DFF);

const _topicOptions = [
  'Tech', 'Design', 'Startup', 'Music', 'Film',
  'Books', 'Travel', 'Food', 'Sports', 'Gaming',
  'Art', 'Science', 'Philosophy', 'Language', 'Other',
];

class EditRoomScreen extends ConsumerStatefulWidget {
  final Room room;
  const EditRoomScreen({super.key, required this.room});

  @override
  ConsumerState<EditRoomScreen> createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends ConsumerState<EditRoomScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final Set<String> _selectedTags;
  late int _maxParticipants;
  bool _submitting = false;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.room.title);
    _descCtrl = TextEditingController(text: widget.room.description ?? '');
    _selectedTags = {...widget.room.topicTags};
    _maxParticipants = widget.room.maxParticipants;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() { _submitting = true; _warning = null; });

    // AI re-validate
    final fullText = '$title ${_descCtrl.text.trim()}';
    try {
      final validation = await GeminiService.analyzeText(
        'Check if this chat room topic is promotional or spam. '
        'Reply ONLY with JSON: {"is_promotional": true/false, "quality_score": 0-100}. '
        'Text: "$fullText"',
      );
      if (validation['is_promotional'] == true) {
        setState(() { _warning = 'This looks promotional.'; _submitting = false; });
        return;
      }
    } catch (_) {}

    if (!isMockMode) {
      await Supabase.instance.client.from('rooms').update({
        'title': title,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'topic_tags': _selectedTags.toList(),
        'max_participants': _maxParticipants,
      }).eq('id', widget.room.id);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit Room'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              maxLength: 60,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Room topic'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _descCtrl,
              maxLength: 100,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const Text('TOPIC TAGS', style: TextStyle(color: AppColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.8)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _topicOptions.map((tag) {
                final selected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) { _selectedTags.remove(tag); }
                    else if (_selectedTags.length < 3) { _selectedTags.add(tag); }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: selected ? _violet.withValues(alpha: 0.12) : AppColors.elevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                      border: Border.all(color: selected ? _violet.withValues(alpha: 0.4) : AppColors.borderSubtle, width: 0.5),
                    ),
                    child: Text(tag, style: TextStyle(color: selected ? _violet : AppColors.textMuted, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Row(children: [
              const Text('Max participants', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const Spacer(),
              Text('$_maxParticipants', style: const TextStyle(color: _violet, fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            SliderTheme(
              data: SliderThemeData(activeTrackColor: _violet, inactiveTrackColor: AppColors.border, thumbColor: _violet),
              child: Slider(value: _maxParticipants.toDouble(), min: 5, max: 20, divisions: 15, onChanged: (v) => setState(() => _maxParticipants = v.round())),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_warning != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: Text(_warning!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _violet, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd))),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
