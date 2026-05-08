import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../providers/note_provider.dart';

class NoteInboxScreen extends ConsumerStatefulWidget {
  const NoteInboxScreen({super.key});

  @override
  ConsumerState<NoteInboxScreen> createState() => _NoteInboxScreenState();
}

class _NoteInboxScreenState extends ConsumerState<NoteInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noteInboxProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteInboxProvider);

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notes', style: TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.w700)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald600))
          : state.notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                      decoration: Premium.emptyStateDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [AppColors.emerald600.withValues(alpha: 0.10), AppColors.emerald600.withValues(alpha: 0.03)],
                              ),
                              border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.12), width: 0.5),
                            ),
                            child: Icon(Icons.mail_outline_rounded, color: AppColors.emerald600.withValues(alpha: 0.45), size: 26),
                          ),
                          const SizedBox(height: 24),
                          Text('No notes yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                          const SizedBox(height: 8),
                          const Text('When someone sends you a note\nyou\'ll see it here',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.nobObserver, fontSize: 14, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.emerald600,
                  onRefresh: () => ref.read(noteInboxProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: state.notes.length,
                    itemBuilder: (context, i) {
                      final note = state.notes[i];
                      return GestureDetector(
                        onTap: () {
                          if (!note.isRead) {
                            ref.read(noteInboxProvider.notifier).markRead(note.id);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.nobSurface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: note.isRead
                                  ? AppColors.nobBorder
                                  : AppColors.emerald600.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                            boxShadow: note.isRead ? Premium.shadowSm : [
                              ...Premium.shadowMd,
                              ...Premium.emeraldGlow(intensity: 0.2),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.emerald600.withValues(alpha: 0.15),
                                    backgroundImage: note.senderPhotoUrl != null
                                        ? NetworkImage(note.senderPhotoUrl!)
                                        : null,
                                    child: note.senderPhotoUrl == null
                                        ? Text(
                                            (note.senderName ?? '?')[0].toUpperCase(),
                                            style: const TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.w600),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note.senderName ?? 'Someone',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: note.isRead ? FontWeight.w400 : FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'on ${note.targetType == 'post' ? 'a Nob' : 'your profile'}',
                                          style: const TextStyle(color: AppColors.nobObserver, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!note.isRead)
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.emerald600,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                note.content,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
