import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../providers/room_provider.dart';
import '../../services/gemini_service.dart';

const _accent = AppColors.emerald700;

const _topicOptions = [
  'Tech', 'Design', 'Startup', 'Music', 'Film',
  'Books', 'Travel', 'Food', 'Sports', 'Gaming',
  'Art', 'Science', 'Philosophy', 'Language', 'Other',
];

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _selectedTags = <String>{};
  int _maxParticipants = 10;
  bool _submitting = false;
  String? _warning;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    if (_selectedTags.isEmpty) {
      setState(() => _warning = 'Select at least one topic tag.');
      return;
    }

    setState(() {
      _submitting = true;
      _warning = null;
    });

    // AI quality check
    int qualityScore = 50;
    final fullText = '$title ${_descCtrl.text.trim()}';
    try {
      final validation = await GeminiService.analyzeText(
        'Check if this chat room topic is promotional or spam. '
        'Promotional keywords: discount, sale, campaign, follow us, müşteri, indirim, kampanya. '
        'Reply ONLY with JSON: {"is_promotional": true/false, "quality_score": 0-100}. '
        'Text: "$fullText"',
      );
      if (validation['is_promotional'] == true) {
        setState(() {
          _warning = 'This looks promotional. Rooms must be real topics.';
          _submitting = false;
        });
        return;
      }
      final aiScore = (validation['quality_score'] as num?)?.toInt();
      if (aiScore != null) qualityScore = aiScore;
      if (qualityScore < 40) {
        setState(() {
          _warning = 'Topic quality too low. Try a more specific, genuine topic.';
          _submitting = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[room] AI validation failed: $e');
      // AI check failed — allow creation with default score
    }

    try {
      await ref.read(roomListProvider.notifier).createRoom(
            title: title,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            topicTags: _selectedTags.toList(),
            maxParticipants: _maxParticipants,
            qualityScore: qualityScore,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ToastService.show(context, message: 'Failed to create room', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Create Room'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleCtrl,
              maxLength: 60,
              style: TextStyle(color: context.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Room topic',
                hintText: 'What do you want to talk about?',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Description
            TextField(
              controller: _descCtrl,
              maxLength: 100,
              style: TextStyle(color: context.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief context for your room',
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Topic tags
            Text(
              'TOPIC TAGS',
              style: TextStyle(
                color: context.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Select up to 3',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _topicOptions.map((tag) {
                final selected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedTags.remove(tag);
                      } else if (_selectedTags.length < 3) {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _accent.withValues(alpha: 0.12)
                          : context.elevatedColor,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCircle),
                      border: Border.all(
                        color: selected
                            ? _accent.withValues(alpha: 0.4)
                            : context.borderSubtleColor,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: selected ? _accent : context.textMuted,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // Max participants slider
            Row(
              children: [
                Text(
                  'Max participants',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '$_maxParticipants',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _accent,
                inactiveTrackColor: context.borderColor,
                thumbColor: _accent,
                overlayColor: _accent.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _maxParticipants.toDouble(),
                min: 5,
                max: 20,
                divisions: 15,
                onChanged: (v) =>
                    setState(() => _maxParticipants = v.round()),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Warning
            if (_warning != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _warning!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // Submit
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: _submitting ? null : Premium.emeraldGlow(intensity: 0.6),
              ),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Room',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
