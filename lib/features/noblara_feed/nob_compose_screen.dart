import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
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
        } catch (e) {
          debugPrint('[ai_writing_help prefs] fetch failed: $e');
        }
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
          _feedback = 'AI edit unavailable. Try again in a moment.';
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
                      color: AppColors.emerald600, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isTurkish ? 'Geliştirilmiş sürüm' : 'Improved version',
                    style: const TextStyle(
                      color: AppColors.emerald600,
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
                        backgroundColor: AppColors.emerald600,
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
          Container(width: 40, height: 4, decoration: Premium.sheetHandle()),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.emerald600),
            title: const Text('Take photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.emerald600),
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
      debugPrint('[publish] ERROR: $e');
      if (mounted) {
        setState(() {
          _feedback = 'Could not publish. Check your connection and try again.';
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
    final pct = charCount / _maxChars;
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
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.emerald600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('N', style: TextStyle(
                  color: AppColors.emerald600,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                )),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'New Nob',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ],
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Type toggle ──────────────────────────────────────
                    _TypeToggle(
                      nobType: _nobType,
                      onChanged: (t) => setState(() => _nobType = t),
                    ),
                    const SizedBox(height: 24),

                    // ── Photo area (Moment) ──────────────────────────────
                    if (_nobType == 'moment') ...[
                      _buildPhotoArea(),
                      const SizedBox(height: 16),
                    ],

                    // ── Text area card ───────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.nobSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _activeCtrl.text.isNotEmpty
                              ? AppColors.emerald600.withValues(alpha: 0.2)
                              : AppColors.nobBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextArea(
                            controller: _nobType == 'thought'
                                ? _contentCtrl
                                : _captionCtrl,
                            hint: _nobType == 'thought'
                                ? _prompt
                                : 'Caption your moment…',
                            maxLength: _maxChars,
                          ),
                          // ── Toolbar row inside card ────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: Row(
                              children: [
                                _ToolbarIcon(icon: Icons.camera_alt_outlined, onTap: _pickPhoto),
                                const SizedBox(width: 6),
                                _ToolbarIcon(icon: Icons.tag_rounded, onTap: () {
                                  setState(() { _feedback = 'Vibe tags coming soon.'; _feedbackIsPositive = true; });
                                }),
                                const SizedBox(width: 8),
                                _AiChip(
                                  label: _aiLoading ? 'Thinking…' : 'AI Polish',
                                  onTap: _aiLoading ? () {} : () => _aiEdit('improve'),
                                  loading: _aiLoading,
                                ),
                                const Spacer(),
                                // Circular character counter
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: pct.clamp(0.0, 1.0),
                                        strokeWidth: 2,
                                        backgroundColor: AppColors.nobBorder.withValues(alpha: 0.4),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isOver ? AppColors.error : AppColors.emerald600.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      Text(
                                        '${_maxChars - charCount}',
                                        style: TextStyle(
                                          color: counterColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Feedback ─────────────────────────────────────────
                    if (_feedback != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (_feedbackIsPositive
                              ? AppColors.emerald600
                              : AppColors.error).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _feedbackIsPositive
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.info_outline_rounded,
                              color: _feedbackIsPositive
                                  ? AppColors.emerald600
                                  : AppColors.error,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _feedback!,
                                style: TextStyle(
                                  color: _feedbackIsPositive
                                      ? AppColors.emerald600
                                      : AppColors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Bottom action bar (gradient fade) ────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.nobBackground.withValues(alpha: 0.0),
                    AppColors.nobBackground.withValues(alpha: 0.9),
                    AppColors.nobBackground,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.nobObserver,
                        side: BorderSide(color: AppColors.nobBorder.withValues(alpha: 0.6)),
                        minimumSize: const Size(80, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveDraft,
                      child: const Text('Draft',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: (isOver || _isPublishing) ? null : Premium.emeraldGlow(intensity: 0.5),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.emerald600.withValues(alpha: 0.3),
                            disabledForegroundColor: Colors.white54,
                            minimumSize: const Size.fromHeight(50),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        onPressed: (isOver || _isPublishing) ? null : _publish,
                        child: _isPublishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Publish',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
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
      minLines: _nobType == 'moment' ? 3 : 6,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.7,
        letterSpacing: 0.15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.nobObserver.withValues(alpha: 0.7),
          fontSize: 15,
          height: 1.7,
          fontStyle: FontStyle.italic,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        counterText: '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPhotoArea() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 240,
        decoration: BoxDecoration(
          color: _photoBytes != null
              ? Colors.transparent
              : AppColors.nobSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _photoBytes != null
                ? AppColors.emerald600.withValues(alpha: 0.3)
                : AppColors.nobBorder.withValues(alpha: 0.4),
            width: _photoBytes != null ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _photoBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_photoBytes!, fit: BoxFit.cover),
                  // Gradient overlay at top for the close button
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _photoBytes = null;
                        _uploadedPhotoUrl = null;
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  if (_isUploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.emerald600, strokeWidth: 2.5),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.emerald600.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.emerald600, size: 26),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add a photo',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to choose from gallery or camera',
                    style: TextStyle(
                      color: AppColors.nobObserver.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type toggle — compact segmented pill
// ---------------------------------------------------------------------------

class _TypeToggle extends StatelessWidget {
  final String nobType;
  final ValueChanged<String> onChanged;

  const _TypeToggle({required this.nobType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.nobSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _TogglePill(
            label: 'Thought',
            icon: Icons.format_quote_rounded,
            isActive: nobType == 'thought',
            onTap: () { HapticFeedback.selectionClick(); onChanged('thought'); },
          ),
          _TogglePill(
            label: 'Moment',
            icon: Icons.camera_alt_rounded,
            isActive: nobType == 'moment',
            onTap: () { HapticFeedback.selectionClick(); onChanged('moment'); },
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TogglePill({
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.emerald600.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isActive ? AppColors.emerald600.withValues(alpha: 0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                color: isActive ? AppColors.emerald600 : AppColors.nobObserver),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: isActive ? AppColors.emerald500 : AppColors.nobObserver,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI chip — inline action pill
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.emerald600.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.emerald600),
              )
            else
              const Icon(Icons.auto_awesome_outlined,
                  size: 12, color: AppColors.emerald600),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.emerald600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toolbar icon — subtle rounded action button
// ---------------------------------------------------------------------------

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ToolbarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: AppColors.nobSurfaceAlt.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}
