import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../edit_profile_provider.dart';
import '../profile_draft.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';

class PromptsSection extends ConsumerStatefulWidget {
  const PromptsSection({super.key});
  @override
  ConsumerState<PromptsSection> createState() => _State();
}

class _State extends ConsumerState<PromptsSection> {
  @override
  Widget build(BuildContext context) {
    final d = ref.watch(editProfileProvider).draft;
    // Ensure at least 3 prompt slots
    while (d.prompts.length < 3) {
      d.prompts = [...d.prompts, const PromptAnswer(question: '', answer: '')];
    }

    return EditSectionShell(
      title: 'Prompts & Highlights',
      description: 'Answer 3 prompts to show your personality.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < 3; i++) ...[
            _PromptCard(
              index: i,
              prompt: d.prompts[i],
              onChanged: (p) {
                ref.read(editProfileProvider.notifier).updateDraft((d) {
                  final list = List<PromptAnswer>.from(d.prompts);
                  list[i] = p;
                  d.prompts = list;
                  return d;
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final int index;
  final PromptAnswer prompt;
  final ValueChanged<PromptAnswer> onChanged;

  const _PromptCard({required this.index, required this.prompt, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Prompt ${index + 1}', style: TextStyle(color: context.accent, fontSize: 11, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => _pickQuestion(context),
                child: Text(prompt.question.isEmpty ? 'Choose question' : 'Change',
                  style: TextStyle(color: context.textMuted, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (prompt.question.isNotEmpty) ...[
            Text(prompt.question, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: TextEditingController(text: prompt.answer),
              onChanged: (v) => onChanged(PromptAnswer(question: prompt.question, answer: v)),
              maxLength: 200,
              maxLines: 3,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Your answer...',
                hintStyle: TextStyle(color: context.textDisabled),
                counterStyle: TextStyle(color: context.textDisabled, fontSize: 10),
                filled: true, fillColor: context.bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.accent)),
              ),
            ),
          ] else
            GestureDetector(
              onTap: () => _pickQuestion(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(children: [
                  Icon(Icons.add_rounded, color: context.textMuted, size: 24),
                  const SizedBox(height: 4),
                  Text('Tap to choose a question', style: TextStyle(color: context.textMuted, fontSize: 12)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _pickQuestion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: AppSpacing.lg),
            Text('Choose a question', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: ProfileOptions.promptQuestions.length,
                itemBuilder: (ctx, i) {
                  final q = ProfileOptions.promptQuestions[i];
                  return ListTile(
                    title: Text(q, style: TextStyle(color: context.textPrimary, fontSize: 14)),
                    trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(PromptAnswer(question: q, answer: prompt.answer));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
