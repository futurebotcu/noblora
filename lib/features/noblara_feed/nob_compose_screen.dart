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
  bool _isPublishing = false;
  String? _savedDraftId;
  String? _feedback;
  bool _feedbackIsPositive = false;

  String get _prompt =>
      _prompts[(DateTime.now().millisecondsSinceEpoch ~/ 1000) % _prompts.length];

  int get _maxChars => _nobType == 'thought' ? 300 : 150;
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
    // Check AI writing help setting
    if (!isMockMode) {
      final uid = ref.read(authProvider).userId;
      if (uid != null) {
        try {
          final row = await Supabase.instance.client.from('profiles')
              .select('ai_writing_help').eq('id', uid).maybeSingle();
          final prefs = row?['ai_writing_help'] as Map<String, dynamic>?;
          if (prefs != null && prefs['nob_cleanup'] == false) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI writing help is disabled in Settings')));
            }
            return;
          }
        } catch (_) {}
      }
    }

    final text = _activeCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiLoading = true);
    try {
      if (isMockMode) {
        await Future.delayed(const Duration(seconds: 1));
        _showAiResult('[AI unavailable] $text', isTurkish: _isTurkish(text));
        return;
      }
      final resp = await Supabase.instance.client.functions.invoke(
        'nob-ai-edit',
        body: {'content': text, 'edit_type': editType},
      );
      final edited = resp.data?['edited_content'] as String?;
      if (edited != null && mounted) {
        _showAiResult(edited, isTurkish: _isTurkish(text) || _isTurkish(edited));
      }
    } catch (e) {
      debugPrint('[nob-ai-edit] ERROR: $e');
      if (mounted) {
        setState(() {
          _feedback = 'AI edit failed: $e';
          _feedbackIsPositive = false;
        });
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  bool _isTurkish(String text) =>
      RegExp(r'[ğüşıöçĞÜŞİÖÇ]').hasMatch(text);

  void _showAiResult(String result, {bool isTurkish = false}) {
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
                    isTurkish ? 'Geliştirilmiş sürüm' : 'Improved version',
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
                        setState(() {});
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

  Future<void> _pickPhoto({ImageSource? source}) async {
    if (source == null) {
      // Show bottom sheet with options
      final picked = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.nobSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 3, decoration: BoxDecoration(color: AppColors.nobBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.noblaraGold),
            title: const Text('Take photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.noblaraGold),
            title: const Text('Choose from gallery', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 12),
        ])),
      );
      if (picked == null) return;
      source = picked;
    }
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _uploadedPhotoUrl = null;
      if (_nobType == 'thought') _nobType = 'moment';
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
      await Supabase.instance.client.storage.from('galleries').uploadBinary(
          path, _photoBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = Supabase.instance.client.storage
          .from('galleries')
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
    if (_isPublishing) return;
    final text = _activeCtrl.text.trim();
    // Thought: requires min 10 chars
    if (_nobType == 'thought' && text.length < 10) {
      setState(() {
        _feedback = text.isEmpty ? 'Write something first.' : 'At least 10 characters needed.';
        _feedbackIsPositive = false;
      });
      return;
    }
    // Moment: requires photo OR min 10 chars
    if (_nobType == 'moment' && _photoBytes == null && text.length < 10) {
      setState(() {
        _feedback = 'Add a photo or write at least 10 characters.';
        _feedbackIsPositive = false;
      });
      return;
    }
    if (_nobType == 'moment' && _photoBytes != null && _uploadedPhotoUrl == null) {
      await _uploadPhoto();
      if (_uploadedPhotoUrl == null) return;
    }

    setState(() => _isPublishing = true);
    try {
      final canPublish =
          await ref.read(postsProvider.notifier).canPublishToday(_nobType);
      if (!mounted) return;
      if (!canPublish) {
        setState(() {
          _feedback = 'You\'ve shared your Nob for today. Come back tomorrow.';
          _feedbackIsPositive = false;
          _isPublishing = false;
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
    } catch (e) {
      // publish failed
      if (mounted) {
        setState(() {
          _feedback = 'Publish failed: $e';
          _feedbackIsPositive = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
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
                    _AiChip(
                      label: _aiLoading ? 'AI thinking…' : 'AI Improve',
                      onTap: _aiLoading ? () {} : () => _aiEdit('improve'),
                      loading: _aiLoading,
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

                    // ── Media toolbar + counter ──────────────────────────
                    Row(
                      children: [
                        _ToolbarIcon(icon: Icons.camera_alt_outlined, onTap: _pickPhoto),
                        const SizedBox(width: 4),
                        _ToolbarIcon(icon: Icons.tag_rounded, onTap: () {
                          setState(() { _feedback = 'Vibe tags coming soon.'; _feedbackIsPositive = true; });
                        }),
                        const Spacer(),
                        Text(
                          '$charCount/$_maxChars',
                          style: TextStyle(color: counterColor, fontSize: 11, letterSpacing: 0.3),
                        ),
                      ],
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
                      onPressed: (isOver || _isPublishing) ? null : _publish,
                      child: _isPublishing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.nobBackground),
                            )
                          : const Text(
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
    return Row(
      children: [
        _TypeCard(
          label: 'Thought',
          subtitle: 'Text-based',
          icon: Icons.format_quote_rounded,
          isActive: nobType == 'thought',
          onTap: () => onChanged('thought'),
        ),
        const SizedBox(width: AppSpacing.md),
        _TypeCard(
          label: 'Moment',
          subtitle: 'Photo-based',
          icon: Icons.camera_alt_rounded,
          isActive: nobType == 'moment',
          onTap: () => onChanged('moment'),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.subtitle,
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isActive ? AppColors.noblaraGold.withValues(alpha: 0.08) : AppColors.nobSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? AppColors.noblaraGold.withValues(alpha: 0.4) : AppColors.nobBorder,
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: isActive ? AppColors.noblaraGold : AppColors.nobObserver),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                color: isActive ? AppColors.noblaraGold : AppColors.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600,
              )),
              Text(subtitle, style: TextStyle(
                color: isActive ? AppColors.noblaraGold.withValues(alpha: 0.6) : AppColors.nobObserver,
                fontSize: 11,
              )),
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
  final bool loading;
  const _AiChip({required this.label, required this.onTap, this.loading = false});

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
            if (loading)
              const SizedBox(
                width: 11, height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.noblaraGold),
              )
            else
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

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ToolbarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.nobSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.nobBorder, width: 0.5),
        ),
        child: Icon(icon, size: 18, color: AppColors.noblaraGold.withValues(alpha: 0.7)),
      ),
    );
  }
}
