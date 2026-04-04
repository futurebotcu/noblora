import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/premium.dart';

/// Common shell for every edit section screen.
class EditSectionShell extends StatelessWidget {
  final String title;
  final String? description;
  final VoidCallback onSave;
  final bool saving;
  final Widget child;

  const EditSectionShell({
    super.key,
    required this.title,
    this.description,
    required this.onSave,
    this.saving = false,
    required this.child,
  });

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
        title: Text(title, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: saving ? null : onSave,
            child: Text('Save', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.lg),
              child: Text(description!, style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4)),
            ),
          Expanded(child: child),
          // Sticky save button
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: context.borderColor.withValues(alpha: 0.3), width: 0.5)),
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: saving ? null : Premium.emeraldGlow(intensity: 0.5),
              ),
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: context.onAccent,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                child: saving
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.onAccent))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header label
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

/// Text field with consistent styling
class EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;

  const EditField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        style: TextStyle(color: context.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.textMuted, fontSize: 13),
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: context.surfaceColor,
          counterStyle: TextStyle(color: context.textDisabled, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.accent)),
        ),
      ),
    );
  }
}
