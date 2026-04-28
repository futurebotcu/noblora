import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../core/services/toast_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/messages_provider.dart';
import '../../services/gemini_service.dart';

class EndConnectionScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;

  const EndConnectionScreen({
    super.key,
    required this.matchId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
  });

  @override
  ConsumerState<EndConnectionScreen> createState() => _EndConnectionState();
}

class _EndConnectionState extends ConsumerState<EndConnectionScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSend => _ctrl.text.trim().length >= 20;

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() => _loading = true);
    final message = _ctrl.text.trim();

    // AI validation
    try {
      final result = await GeminiService.analyzeText('''
You are reviewing a farewell message someone is sending before ending a connection on a premium dating app.

Message: "$message"

Check if this message:
1. Is at least somewhat meaningful (not just "bye" or random characters)
2. Does not contain insults, harassment, or hate speech
3. Is in a human language (not gibberish)

Respond with JSON only:
{"approved": true/false, "reason": "brief explanation if rejected"}
''');

      final approved = result['approved'] == true || result['mock'] == true;
      final reason = result['reason'] as String? ?? '';

      if (!approved) {
        if (!mounted) return;
        setState(() => _loading = false);
        ToastService.show(context, message: reason.isNotEmpty ? reason : 'Please write a more thoughtful message.', type: ToastType.error);
        return;
      }
    } catch (e) {
      debugPrint('[end] AI farewell check failed: $e');
      // AI check failed — allow but inform user
      if (mounted) {
        ToastService.show(context, message: 'AI check unavailable — message will be sent without review.', type: ToastType.system);
      }
    }

    // Send farewell message + close match
    try {
      if (!isMockMode) {
        // Send the farewell as a system message
        final match = ref.read(matchProvider).matches.where((m) => m.id == widget.matchId).firstOrNull;
        if (match?.conversationId != null) {
          final senderId = await ref.read(authRepositoryProvider).getCurrentUserId();
          await ref
              .read(messagesRepositoryProvider)
              .insertSystemMessageFromUser(
                conversationId: match!.conversationId!,
                senderId: senderId!,
                content: message,
                mode: match.mode,
              );
        }

        // Close the match
        await ref.read(matchRepositoryProvider).updateStatus(widget.matchId, 'closed');
      }

      // Reload matches
      await ref.read(matchProvider.notifier).load();

      if (!mounted) return;
      ToastService.show(context, message: 'Connection ended with grace.', type: ToastType.success);
      // Pop back to matches list
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/matches');
      // If we're still not at matches, just pop twice
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastService.show(context, message: 'Something went wrong. Try again.', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('End this connection', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text('Take a moment to close this chapter with intention.',
                  style: TextStyle(color: context.textMuted, fontSize: 14)),
              const SizedBox(height: AppSpacing.xxxl),

              // Avatar + name
              Center(child: Column(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.emerald600.withValues(alpha: 0.1),
                  backgroundImage: widget.otherUserPhotoUrl != null && widget.otherUserPhotoUrl!.startsWith('http')
                      ? NetworkImage(widget.otherUserPhotoUrl!) : null,
                  child: widget.otherUserPhotoUrl == null || !widget.otherUserPhotoUrl!.startsWith('http')
                      ? Text(initial, style: TextStyle(color: AppColors.emerald600, fontSize: 22, fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.otherUserName, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
              ])),
              const SizedBox(height: AppSpacing.xxxl),

              // Farewell text area
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: context.textPrimary, fontSize: 15, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Write a few kind words before you go (at least 20 characters). This will be shared with ${widget.otherUserName}.',
                    hintStyle: TextStyle(color: context.textDisabled, fontSize: 14),
                    hintMaxLines: 3,
                    filled: true,
                    fillColor: context.surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.emerald600)),
                  ),
                ),
              ),

              // Minimum length hint
              if (_ctrl.text.trim().isNotEmpty && !_canSend)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    '${20 - _ctrl.text.trim().length} more characters needed',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                ),

              // AI note
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
                child: Row(children: [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.emerald600.withValues(alpha: 0.6), size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Our AI ensures your message is respectful and genuine.',
                      style: TextStyle(color: context.textMuted, fontSize: 12))),
                ]),
              ),

              // Submit button
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: (_loading || !_canSend) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: context.bgColor,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: _loading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.bgColor))
                    : const Text('Send & End Connection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              )),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
