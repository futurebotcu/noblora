import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/premium.dart';
import '../../../../core/utils/mock_mode.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/storage_provider.dart';
import '../edit_profile_provider.dart';
import '../widgets/edit_section_shell.dart';

class PhotosMediaSection extends ConsumerWidget {
  const PhotosMediaSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(editProfileProvider).draft;
    final saving = ref.watch(editProfileProvider).isSaving;

    return EditSectionShell(
      title: 'Photos & Media',
      description: 'Add up to 6 photos. First photo is your main profile picture.',
      saving: saving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.75,
          ),
          itemCount: 6,
          itemBuilder: (ctx, i) {
            final hasPhoto = i < draft.photoUrls.length && draft.photoUrls[i].isNotEmpty;
            if (hasPhoto) {
              return GestureDetector(
                onTap: () => _showPhotoOptions(context, ref, i, draft.photoUrls.length),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: CachedNetworkImage(
                        imageUrl: draft.photoUrls[i],
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (_, __) => Container(
                          color: context.surfaceColor,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: context.surfaceColor,
                          child: Icon(Icons.broken_image, color: context.textDisabled),
                        ),
                      ),
                    ),
                    if (i == 0)
                      Positioned(bottom: 4, left: 4, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(4)),
                        child: Text('Main', style: TextStyle(color: context.onAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                      )),
                    Positioned(top: 4, right: 4, child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                    )),
                  ],
                ),
              );
            }
            return GestureDetector(
              onTap: () => _pickPhoto(context, ref, i),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: context.borderColor.withValues(alpha: 0.4), width: 0.5),
                  boxShadow: Premium.shadowSm,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: context.textMuted, size: 28),
                  const SizedBox(height: 4),
                  Text('Add', style: TextStyle(color: context.textMuted, fontSize: 11)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref, int index) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (img == null) return;
    if (isMockMode) {
      ref.read(editProfileProvider.notifier).updateDraft((d) {
        final urls = List<String>.from(d.photoUrls);
        index < urls.length ? urls[index] = img.path : urls.add(img.path);
        d.photoUrls = urls;
        return d;
      });
      return;
    }
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final bytes = await img.readAsBytes();
      // Validate file size (max 10MB)
      if (bytes.length > 10 * 1024 * 1024) {
        if (context.mounted) {
          ToastService.show(context, message: 'Photo is too large (10 MB max)', type: ToastType.error);
        }
        return;
      }
      // Detect content type from magic bytes
      final contentType = _detectImageType(bytes);
      if (contentType == null) {
        if (context.mounted) {
          ToastService.show(context, message: 'Use JPG, PNG, or WebP format', type: ToastType.error);
        }
        return;
      }
      // Delete old photo from storage if replacing
      final draft = ref.read(editProfileProvider).draft;
      final oldUrl = index < draft.photoUrls.length ? draft.photoUrls[index] : null;
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await ref.read(storageRepositoryProvider).uploadProfilePhoto(
        path: path,
        bytes: bytes,
        contentType: contentType,
      );
      ref.read(editProfileProvider.notifier).updateDraft((d) {
        final urls = List<String>.from(d.photoUrls);
        index < urls.length ? urls[index] = url : urls.add(url);
        d.photoUrls = urls;
        return d;
      });
      // Cleanup replaced photo
      if (oldUrl != null && oldUrl.contains('profile-photos')) {
        final segments = Uri.parse(oldUrl).pathSegments;
        final storagePath = segments.length >= 2 ? segments.sublist(segments.length - 2).join('/') : null;
        if (storagePath != null) {
          try {
            await ref.read(storageRepositoryProvider).removeProfilePhoto(storagePath);
          } catch (e) {
            debugPrint('[photos] orphan cleanup: $e');
          }
        }
      }
    } catch (e) {
      if (context.mounted) ToastService.show(context, message: 'Photo upload failed', type: ToastType.error);
    }
  }

  void _showPhotoOptions(BuildContext context, WidgetRef ref, int index, int totalPhotos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(
              color: context.borderColor, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 16),
            if (index > 0)
              ListTile(
                leading: Icon(Icons.star_rounded, color: context.accent),
                title: Text('Set as main photo', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(editProfileProvider.notifier).updateDraft((d) {
                    final urls = List<String>.from(d.photoUrls);
                    final moved = urls.removeAt(index);
                    urls.insert(0, moved);
                    d.photoUrls = urls;
                    return d;
                  });
                  ToastService.show(context, message: 'Photo set as main', type: ToastType.success);
                },
              ),
            if (index > 0 && index < totalPhotos - 1)
              ListTile(
                leading: Icon(Icons.arrow_downward_rounded, color: context.textMuted),
                title: Text('Move back', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(editProfileProvider.notifier).updateDraft((d) {
                    final urls = List<String>.from(d.photoUrls);
                    final item = urls.removeAt(index);
                    urls.insert(index + 1, item);
                    d.photoUrls = urls;
                    return d;
                  });
                },
              ),
            if (index > 1)
              ListTile(
                leading: Icon(Icons.arrow_upward_rounded, color: context.textMuted),
                title: Text('Move forward', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(editProfileProvider.notifier).updateDraft((d) {
                    final urls = List<String>.from(d.photoUrls);
                    final item = urls.removeAt(index);
                    urls.insert(index - 1, item);
                    d.photoUrls = urls;
                    return d;
                  });
                },
              ),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: context.textMuted),
              title: Text('Replace photo', style: TextStyle(color: context.textPrimary, fontSize: 14)),
              onTap: () { Navigator.pop(context); _pickPhoto(context, ref, index); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Remove photo', style: TextStyle(color: AppColors.error, fontSize: 14)),
              onTap: () { Navigator.pop(context); _confirmRemove(context, ref, index); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String? _detectImageType(List<int> bytes) {
    if (bytes.length < 4) return null;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return 'image/webp';
    return null;
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, int index) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: context.surfaceColor,
      title: Text('Remove photo?', style: TextStyle(color: context.textPrimary, fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: context.textMuted))),
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          final draft = ref.read(editProfileProvider).draft;
          final removedUrl = index < draft.photoUrls.length ? draft.photoUrls[index] : null;
          ref.read(editProfileProvider.notifier).updateDraft((d) {
            final urls = List<String>.from(d.photoUrls);
            urls.removeAt(index);
            d.photoUrls = urls;
            return d;
          });
          // Cleanup storage orphan
          if (removedUrl != null && removedUrl.contains('profile-photos') && !isMockMode) {
            final path = Uri.parse(removedUrl).pathSegments;
            final storagePath = path.length >= 2 ? path.sublist(path.length - 2).join('/') : null;
            if (storagePath != null) {
              ref.read(storageRepositoryProvider).removeProfilePhoto(storagePath);
            }
          }
        }, child: const Text('Remove', style: TextStyle(color: AppColors.error))),
      ],
    ));
  }
}
