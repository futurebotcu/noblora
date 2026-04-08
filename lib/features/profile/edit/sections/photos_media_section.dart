import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/premium.dart';
import '../../../../core/utils/mock_mode.dart';
import '../../../../providers/auth_provider.dart';
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
                onTap: () => _confirmRemove(context, ref, i),
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
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('profile-photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
      final url = Supabase.instance.client.storage.from('profile-photos').getPublicUrl(path);
      ref.read(editProfileProvider.notifier).updateDraft((d) {
        final urls = List<String>.from(d.photoUrls);
        index < urls.length ? urls[index] = url : urls.add(url);
        d.photoUrls = urls;
        return d;
      });
    } catch (e) {
      if (context.mounted) ToastService.show(context, message: 'Photo upload failed', type: ToastType.error);
    }
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
          ref.read(editProfileProvider.notifier).updateDraft((d) {
            final urls = List<String>.from(d.photoUrls);
            urls.removeAt(index);
            d.photoUrls = urls;
            return d;
          });
        }, child: const Text('Remove', style: TextStyle(color: AppColors.error))),
      ],
    ));
  }
}
