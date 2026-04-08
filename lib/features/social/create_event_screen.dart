import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../providers/event_provider.dart';
import '../../services/gemini_service.dart';

const _accent = AppColors.emerald700;

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  int _maxAttendees = 10;
  bool _companionEnabled = true;
  bool _plus3Enabled = false;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _eventTime = const TimeOfDay(hour: 18, minute: 0);
  bool _submitting = false;
  String? _warning;
  int _qualityScore = 50;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() { _submitting = true; _warning = null; });

    // AI quality check
    final fullText = '$title ${_descCtrl.text.trim()}';
    try {
      final validation = await GeminiService.analyzeText(
        'Check if this event description is promotional or spam. '
        'Promotional keywords: discount, sale, campaign, follow us, müşteri, indirim, kampanya. '
        'Reply ONLY with JSON: {"is_promotional": true/false, "quality_score": 0-100}. '
        'Text: "$fullText"',
      );
      if (validation.containsKey('is_promotional') && validation['is_promotional'] == true) {
        setState(() {
          _warning = 'This looks promotional. Events must be real activities.';
          _submitting = false;
        });
        return;
      }
      // Read quality score from AI response
      final aiScore = (validation['quality_score'] as num?)?.toInt();
      if (aiScore != null) _qualityScore = aiScore;
    } catch (e) { debugPrint('[event-create] AI validation failed: $e'); }

    final scheduledAt = DateTime(
      _eventDate.year, _eventDate.month, _eventDate.day,
      _eventTime.hour, _eventTime.minute,
    );

    try {
      await ref.read(eventListProvider.notifier).createEvent(
            title: title,
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            eventDate: scheduledAt,
            locationText: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
            maxAttendees: _maxAttendees,
            companionEnabled: _companionEnabled,
            plus3Enabled: _plus3Enabled,
            qualityScore: _qualityScore,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ToastService.show(context, message: 'Failed to create event', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              _label('Title'),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDeco('What\'s the event?'),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Description
              _label('Description (optional)'),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: _inputDeco('Tell people what to expect'),
              ),

              if (_warning != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(_warning!, style: TextStyle(color: AppColors.warning, fontSize: 13)),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Date & Time
              _label('When?'),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _eventDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                          builder: (c, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _accent, surface: AppColors.surface)), child: child!),
                        );
                        if (d != null) setState(() => _eventDate = d);
                      },
                      child: _picker(Icons.calendar_today_rounded, DateFormat('EEE, d MMM').format(_eventDate)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _eventTime,
                          builder: (c, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _accent, surface: AppColors.surface)), child: child!),
                        );
                        if (t != null) setState(() => _eventTime = t);
                      },
                      child: _picker(Icons.schedule_rounded, _eventTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Location
              _label('Location'),
              TextField(
                controller: _locationCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDeco('e.g. Kadikoy, Istanbul'),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Max attendees
              _label('Max attendees: $_maxAttendees'),
              Slider(
                value: _maxAttendees.toDouble(),
                min: 2,
                max: 50,
                divisions: 48,
                activeColor: _accent,
                onChanged: (v) => setState(() => _maxAttendees = v.round()),
              ),
              const SizedBox(height: AppSpacing.md),

              // Toggles
              SwitchListTile(
                title: const Text('Allow companions (+1/+2)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                value: _companionEnabled,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                onChanged: (v) => setState(() => _companionEnabled = v),
              ),
              SwitchListTile(
                title: const Text('Enable +3 mode (Triple Match)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                value: _plus3Enabled,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                onChanged: (v) => setState(() => _plus3Enabled = v),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Submit
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: _submitting ? null : Premium.emeraldGlow(intensity: 0.6),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Event', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: _accent)),
      );

  Widget _picker(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusSm), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: _accent, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ]),
      );
}
