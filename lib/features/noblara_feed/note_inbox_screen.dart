import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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
        title: const Text('Notes', style: TextStyle(color: AppColors.noblaraGold, fontWeight: FontWeight.w700)),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.noblaraGold))
          : state.notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline_rounded, color: AppColors.nobObserver.withValues(alpha: 0.3), size: 56),
                      const SizedBox(height: AppSpacing.lg),
                      Text('No notes yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('When someone sends you a note,\nyou\'ll see it here.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.nobObserver, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.noblaraGold,
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
                                  : AppColors.noblaraGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.noblaraGold.withValues(alpha: 0.15),
                                    backgroundImage: note.senderPhotoUrl != null
                                        ? NetworkImage(note.senderPhotoUrl!)
                                        : null,
                                    child: note.senderPhotoUrl == null
                                        ? Text(
                                            (note.senderName ?? '?')[0].toUpperCase(),
                                            style: const TextStyle(color: AppColors.noblaraGold, fontWeight: FontWeight.w600),
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
                                        color: AppColors.noblaraGold,
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
