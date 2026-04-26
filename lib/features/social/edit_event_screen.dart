import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/event.dart';
import '../../providers/event_provider.dart';
import '../../services/gemini_service.dart';

const _accent = AppColors.emerald700;

class EditEventScreen extends ConsumerStatefulWidget {
  final NobEvent event;
  const EditEventScreen({super.key, required this.event});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late int _maxAttendees;
  late DateTime _eventDate;
  late TimeOfDay _eventTime;
  bool _submitting = false;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event.title);
    _descCtrl = TextEditingController(text: widget.event.description ?? '');
    _locationCtrl = TextEditingController(text: widget.event.locationText ?? '');
    _maxAttendees = widget.event.maxAttendees;
    _eventDate = widget.event.eventDate;
    _eventTime = TimeOfDay.fromDateTime(widget.event.eventDate);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _eventDate,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _eventTime);
    if (picked != null) setState(() => _eventTime = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() { _submitting = true; _warning = null; });

    // AI re-validate
    final fullText = '$title ${_descCtrl.text.trim()}';
    try {
      final validation = await GeminiService.analyzeText(
        'Check if this event description is promotional or spam. '
        'Reply ONLY with JSON: {"is_promotional": true/false, "quality_score": 0-100}. '
        'Text: "$fullText"',
      );
      if (validation['is_promotional'] == true) {
        setState(() { _warning = 'This looks promotional.'; _submitting = false; });
        return;
      }
    } catch (e) { debugPrint('[event-edit] AI validation failed: $e'); }

    final scheduledAt = DateTime(
      _eventDate.year, _eventDate.month, _eventDate.day,
      _eventTime.hour, _eventTime.minute,
    );

    if (!isMockMode) {
      await ref.read(eventRepositoryProvider).updateEvent(widget.event.id, {
        'title': title,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'location_text': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'event_date': scheduledAt.toIso8601String(),
        'max_attendees': _maxAttendees,
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Event title'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _locationCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Date & time
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(DateFormat('d MMM yyyy').format(_eventDate)),
                  style: OutlinedButton.styleFrom(foregroundColor: _accent),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(_eventTime.format(context)),
                  style: OutlinedButton.styleFrom(foregroundColor: _accent),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xxl),

            // Max attendees
            Row(children: [
              const Text('Max attendees', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const Spacer(),
              Text('$_maxAttendees', style: const TextStyle(color: _accent, fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            SliderTheme(
              data: SliderThemeData(activeTrackColor: _accent, inactiveTrackColor: AppColors.border, thumbColor: _accent),
              child: Slider(value: _maxAttendees.toDouble(), min: 2, max: 50, divisions: 48, onChanged: (v) => setState(() => _maxAttendees = v.round())),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (_warning != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: Text(_warning!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: _submitting ? null : Premium.emeraldGlow(intensity: 0.5),
              ),
              child: ElevatedButton(
                onPressed: _submitting ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd))),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
