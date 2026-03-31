import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/event_provider.dart';

const _violet = Color(0xFFAB47BC);

class EventCheckinScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventCheckinScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventCheckinScreen> createState() => _EventCheckinScreenState();
}

class _EventCheckinScreenState extends ConsumerState<EventCheckinScreen> {
  bool? _wasReal;
  bool? _hostGood;
  bool? _noshow;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_wasReal == null || _hostGood == null || _noshow == null) return;

    setState(() => _submitting = true);
    await ref.read(eventDetailProvider(widget.eventId).notifier).submitCheckin(
          wasReal: _wasReal!,
          hostRating: _hostGood!,
          noshow: _noshow!,
        );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for your feedback!'), backgroundColor: _violet),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Post-Event Check-in'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick feedback',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Your answers are private and never shown publicly.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: AppSpacing.xxxl),

              _Question(
                text: 'Was the event real?',
                value: _wasReal,
                onChanged: (v) => setState(() => _wasReal = v),
              ),
              const SizedBox(height: AppSpacing.xxl),

              _Question(
                text: 'How was the Host?',
                value: _hostGood,
                onChanged: (v) => setState(() => _hostGood = v),
                yesLabel: '\uD83D\uDC4D',
                noLabel: '\uD83D\uDC4E',
              ),
              const SizedBox(height: AppSpacing.xxl),

              _Question(
                text: 'Did anyone not show up?',
                value: _noshow,
                onChanged: (v) => setState(() => _noshow = v),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  ),
                  onPressed: (_wasReal != null && _hostGood != null && _noshow != null && !_submitting) ? _submit : null,
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  final String text;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final String yesLabel;
  final String noLabel;

  const _Question({
    required this.text,
    required this.value,
    required this.onChanged,
    this.yesLabel = 'Yes',
    this.noLabel = 'No',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _chip(yesLabel, value == true, () => onChanged(true)),
            const SizedBox(width: AppSpacing.md),
            _chip(noLabel, value == false, () => onChanged(false)),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? _violet.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: selected ? _violet : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? _violet : AppColors.textMuted, fontSize: 16)),
      ),
    );
  }
}
