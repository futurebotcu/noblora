import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';

// ---------------------------------------------------------------------------
// Inspiration prompts
// ---------------------------------------------------------------------------

const _prompts = [
  'What stayed with you today?',
  'Something you\'ve been thinking about?',
  'A quiet moment?',
  'What did you notice today?',
  'Something you learned recently?',
];

// ---------------------------------------------------------------------------
// NobComposeScreen
// ---------------------------------------------------------------------------

class NobComposeScreen extends ConsumerStatefulWidget {
  const NobComposeScreen({super.key});

  @override
  ConsumerState<NobComposeScreen> createState() => _NobComposeScreenState();
}

class _NobComposeScreenState extends ConsumerState<NobComposeScreen> {
  String _nobType = 'thought';
  final _contentCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  Uint8List? _photoBytes;
  String? _uploadedPhotoUrl;
  bool _isUploading = false;
  bool _aiLoading = false;
  String? _savedDraftId;
  String? _feedback;
  bool _feedbackIsPositive = false;

  static const _asciiOnly = r'^[\x20-\x7E\n\r\t]*$';

  String get _prompt =>
      _prompts[(DateTime.now().millisecondsSinceEpoch ~/ 1000) % _prompts.length];

  int get _maxChars => _nobType == 'thought' ? 150 : 300;
  TextEditingController get _activeCtrl =>
      _nobType == 'thought' ? _contentCtrl : _captionCtrl;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  // ── AI Edit ──────────────────────────────────────────────────────────────

  Future<void> _aiEdit(String editType) async {
    final text = _activeCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiLoading = true);
    try {
      if (isMockMode) {
        await Future.delayed(const Duration(seconds: 1));
        _showAiResult('$text — (AI polished)', editType);
        return;
      }
      final resp = await Supabase.instance.client.functions.invoke(
        'nob-ai-edit',
        body: {'content': text, 'edit_type': editType},
      );
      final edited = resp.data?['edited_content'] as String?;
      if (edited != null && mounted) _showAiResult(edited, editType);
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedback = 'AI edit failed. Try again.';
          _feedbackIsPositive = false;
        });
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _showAiResult(String result, String editType) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.nobSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.nobBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: AppColors.noblaraGold, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    editType == 'fix_typos'
                        ? 'Fixed typos'
                        : editType == 'clean_up'
                            ? 'Cleaned up'
                            : 'Clearer version',
                    style: const TextStyle(
                      color: AppColors.noblaraGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.nobSurfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.nobBorder),
                ),
                child: Text(
                  result,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.nobObserver,
                        side: const BorderSide(color: AppColors.nobBorder),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep original',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.noblaraGold,
                        foregroundColor: AppColors.nobBackground,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () {
                        _activeCtrl.text = result;
                        Navigator.pop(context);
                      },
                      child: const Text('Accept',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo pick ───────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1080, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _uploadedPhotoUrl = null;
    });
  }

  Future<void> _uploadPhoto() async {
    if (_photoBytes == null) return;
    setState(() => _isUploading = true);
    try {
      if (isMockMode) {
        setState(() => _uploadedPhotoUrl = 'mock://photo');
        return;
      }
      final userId = ref.read(authProvider).userId ?? 'anon';
      final path =
          'nob_photos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('public').uploadBinary(
          path, _photoBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = Supabase.instance.client.storage
          .from('public')
          .getPublicUrl(path);
      setState(() => _uploadedPhotoUrl = url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedback = 'Photo upload failed.';
          _feedbackIsPositive = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Save / Publish ────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    final text = _activeCtrl.text.trim();
    if (text.isEmpty && _nobType == 'thought') {
      setState(() {
        _feedback = 'Write something first.';
        _feedbackIsPositive = false;
      });
      return;
    }
    if (!RegExp(_asciiOnly).hasMatch(text)) {
      setState(() {
        _feedback = 'Please write in English only.';
        _feedbackIsPositive = false;
      });
      return;
    }
    if (_photoBytes != null && _uploadedPhotoUrl == null) {
      await _uploadPhoto();
      if (_uploadedPhotoUrl == null) return;
    }

    final post = await ref.read(postsProvider.notifier).createNob(
          content: _nobType == 'thought' ? text : '',
          nobType: _nobType,
          caption: _nobType == 'moment' ? _captionCtrl.text.trim() : null,
          photoUrl: _uploadedPhotoUrl,
          isDraft: true,
        );
    if (post != null && mounted) {
      setState(() {
        _savedDraftId = post.id;
        _feedback = 'Draft saved.';
        _feedbackIsPositive = true;
      });
    }
  }

  Future<void> _publish() async {
    final text = _activeCtrl.text.trim();
    if (text.isEmpty && _nobType == 'thought') {
      setState(() {
        _feedback = 'Write something first.';
        _feedbackIsPositive = false;
      });
      return;
    }
    if (!RegExp(_asciiOnly).hasMatch(text)) {
      setState(() {
        _feedback = 'Please write in English only.';
        _feedbackIsPositive = false;
      });
      return;
    }
    if (_nobType == 'moment' && _uploadedPhotoUrl == null) {
      if (_photoBytes != null) {
        await _uploadPhoto();
        if (_uploadedPhotoUrl == null) return;
      } else {
        setState(() {
          _feedback = 'Add a photo for a Moment Nob.';
          _feedbackIsPositive = false;
        });
        return;
      }
    }

    final canPublish =
        await ref.read(postsProvider.notifier).canPublishToday(_nobType);
    if (!mounted) return;
    if (!canPublish) {
      setState(() {
        _feedback = 'You\'ve shared your Nob for today. Come back tomorrow.';
        _feedbackIsPositive = false;
      });
      return;
    }

    bool success;
    if (_savedDraftId != null) {
      success =
          await ref.read(postsProvider.notifier).publishDraft(_savedDraftId!);
    } else {
      final post = await ref.read(postsProvider.notifier).createNob(
            content: _nobType == 'thought' ? text : '',
            nobType: _nobType,
            caption: _nobType == 'moment' ? _captionCtrl.text.trim() : null,
            photoUrl: _uploadedPhotoUrl,
            isDraft: false,
          );
      success = post != null;
    }

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _feedback = 'Could not publish. Try again.';
        _feedbackIsPositive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _activeCtrl.text.length;
    final isOver = charCount > _maxChars;
    final counterColor = isOver
        ? AppColors.error
        : charCount >= _maxChars - 20
            ? AppColors.warning
            : AppColors.nobObserver;

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'N E W  N O B',
          style: TextStyle(
            color: AppColors.noblaraGold,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 4,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.nobBorder),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Type selector (pill) ──────────────────────────────
                    _TypeSelector(
                      nobType: _nobType,
                      onChanged: (t) => setState(() => _nobType = t),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // ── AI row ────────────────────────────────────────────
                    if (_aiLoading)
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.noblaraGold),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Text('AI thinking…',
                                style: TextStyle(
                                    color: AppColors.noblaraGold,
                                    fontSize: 11)),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          _AiChip(
                              label: 'Fix typos',
                              onTap: () => _aiEdit('fix_typos')),
                          _AiChip(
                              label: 'Clean up',
                              onTap: () => _aiEdit('clean_up')),
                          _AiChip(
                              label: 'Make clearer',
                              onTap: () => _aiEdit('make_clearer')),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.xxl),

                    // ── Photo area (Moment) ───────────────────────────────
                    if (_nobType == 'moment') ...[
                      _buildPhotoArea(),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // ── Text area ─────────────────────────────────────────
                    _buildTextArea(
                      controller: _nobType == 'thought'
                          ? _contentCtrl
                          : _captionCtrl,
                      hint: _nobType == 'thought'
                          ? _prompt
                          : 'Caption your moment…',
                      maxLength: _maxChars,
                    ),

                    // ── Char counter (bottom-right) ───────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$charCount / $_maxChars',
                        style: TextStyle(
                            color: counterColor,
                            fontSize: 10,
                            letterSpacing: 0.5),
                      ),
                    ),

                    // ── Feedback ──────────────────────────────────────────
                    if (_feedback != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Icon(
                            _feedbackIsPositive
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: _feedbackIsPositive
                                ? AppColors.noblaraGold
                                : AppColors.error,
                            size: 13,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _feedback!,
                            style: TextStyle(
                              color: _feedbackIsPositive
                                  ? AppColors.noblaraGold
                                  : AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),

            // ── Bottom action bar ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xxl),
              decoration: const BoxDecoration(
                color: AppColors.nobBackground,
                border: Border(
                    top: BorderSide(color: AppColors.nobBorder)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.nobObserver,
                      side: const BorderSide(color: AppColors.nobBorder),
                      minimumSize: const Size(90, 48),
                    ),
                    onPressed: _saveDraft,
                    child: const Text('Draft',
                        style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.noblaraGold,
                        foregroundColor: AppColors.nobBackground,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      onPressed: isOver ? null : _publish,
                      child: const Text(
                        'Publish Nob',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
  }) {
    return TextField(
      controller: controller,
      maxLines: null,
      minLines: 6,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.7,
        letterSpacing: 0.2,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.nobObserver,
          fontSize: 15,
          height: 1.7,
          fontStyle: FontStyle.italic,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPhotoArea() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.nobSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _photoBytes != null
                ? AppColors.noblaraGold.withValues(alpha: 0.4)
                : AppColors.nobBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _photoBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_photoBytes!, fit: BoxFit.cover),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _photoBytes = null;
                        _uploadedPhotoUrl = null;
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(5),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  if (_isUploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.noblaraGold),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.nobSurfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.nobBorder),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.nobObserver, size: 22),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Tap to add a photo',
                    style: TextStyle(
                        color: AppColors.nobObserver, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type selector — pill tabs
// ---------------------------------------------------------------------------

class _TypeSelector extends StatelessWidget {
  final String nobType;
  final ValueChanged<String> onChanged;

  const _TypeSelector({required this.nobType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.nobSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.nobBorder),
      ),
      child: Row(
        children: [
          _PillTab(
            label: 'Thought',
            icon: Icons.format_quote_rounded,
            isActive: nobType == 'thought',
            onTap: () => onChanged('thought'),
          ),
          _PillTab(
            label: 'Moment',
            icon: Icons.image_outlined,
            isActive: nobType == 'moment',
            onTap: () => onChanged('moment'),
          ),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.noblaraGold.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 1),
            border: isActive
                ? Border.all(
                    color: AppColors.noblaraGold.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? AppColors.noblaraGold
                    : AppColors.nobObserver,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? AppColors.noblaraGold
                      : AppColors.nobObserver,
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI chip
// ---------------------------------------------------------------------------

class _AiChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AiChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          border: Border.all(
              color: AppColors.noblaraGold.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined,
                size: 11, color: AppColors.noblaraGold),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.noblaraGold,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
