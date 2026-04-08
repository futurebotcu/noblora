import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/scheduling.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../data/models/bff_plan.dart';
import '../../core/services/toast_service.dart';
import '../../providers/bff_provider.dart';

const _accent = AppColors.emerald500;

class BffPlanScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const BffPlanScreen({super.key, required this.conversationId});

  @override
  ConsumerState<BffPlanScreen> createState() => _BffPlanScreenState();
}

class _BffPlanScreenState extends ConsumerState<BffPlanScreen> {
  String _selectedType = 'coffee';
  final _locationCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  bool _submitting = false;
  List<BffPlan> _existingPlans = [];
  List<BffPlan> _pendingCheckins = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlans();
      _loadPendingCheckins();
    });
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await ref.read(bffProvider.notifier).fetchPlans(widget.conversationId);
      if (mounted) setState(() => _existingPlans = plans);
    } catch (e) {
      if (mounted) ToastService.show(context, message: 'Could not load plans', type: ToastType.error);
    }
  }

  Future<void> _loadPendingCheckins() async {
    try {
      final pending = await ref.read(bffProvider.notifier).fetchPendingCheckins();
      if (mounted) setState(() => _pendingCheckins = pending);
    } catch (e) {
      debugPrint('[bff] Failed to load checkins: $e');
    }
  }

  void _showCheckinSheet(BffPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: AppSpacing.xxl),
            Text('How did it go?', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Text('${plan.typeEmoji} ${plan.typeLabel}${plan.location != null ? ' · ${plan.location}' : ''}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: AppSpacing.xxl),
            ...[
              ('Great', Icons.sentiment_very_satisfied_rounded, _accent),
              ('It was okay', Icons.sentiment_neutral_rounded, AppColors.textMuted),
              ("I'd rather not say", Icons.sentiment_dissatisfied_rounded, AppColors.textMuted),
              ('Report an issue', Icons.flag_rounded, AppColors.error),
            ].map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(opt.$2, size: 18),
                  label: Text(opt.$1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: opt.$3,
                    side: BorderSide(color: opt.$3.withValues(alpha: 0.3)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(bffProvider.notifier).submitPlanCheckin(plan.id, opt.$1);
                      setState(() => _pendingCheckins.removeWhere((p) => p.id == plan.id));
                      if (mounted) {
                        ToastService.show(context, message: 'Thanks for your feedback!', type: ToastType.success);
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastService.show(context, message: 'Check-in failed', type: ToastType.error);
                      }
                    }
                  },
                ),
              ),
            )),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      builder: (c, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _accent,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TimePickerSheet(initial: _selectedTime),
    );
    if (result != null) setState(() => _selectedTime = result);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await ref.read(bffProvider.notifier).createPlan(
            conversationId: widget.conversationId,
            planType: _selectedType,
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            scheduledAt: scheduledAt,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ToastService.show(context, message: 'Plan sent!', type: ToastType.success);
    } catch (e) {
      if (mounted) {
        ToastService.show(context, message: 'Failed to create plan', type: ToastType.error);
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
        title: const Text('Make a plan'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pending check-ins ──
              ..._pendingCheckins.map((plan) => GestureDetector(
                onTap: () => _showCheckinSheet(plan),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: _accent.withValues(alpha: 0.20), width: 0.5),
                    boxShadow: Premium.shadowMd,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.rate_review_rounded, color: _accent, size: 22),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('How did it go?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('${plan.typeEmoji} ${plan.typeLabel}${plan.location != null ? ' · ${plan.location}' : ''}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _accent, size: 18),
                    ],
                  ),
                ),
              )),

              // ── Existing plans ──
              if (_existingPlans.isNotEmpty) ...[
                Text('Your plans', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                ..._existingPlans.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: _accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(p.typeEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.typeLabel, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            if (p.location != null)
                              Text(p.location!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            Text(DateFormat('EEE, d MMM · HH:mm').format(p.scheduledAt),
                                style: TextStyle(color: _accent, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.isAccepted ? _accent.withValues(alpha: 0.15) : AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.status[0].toUpperCase() + p.status.substring(1),
                            style: TextStyle(color: p.isAccepted ? _accent : AppColors.textMuted, fontSize: 11)),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: AppSpacing.xxl),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.xxl),
              ],

              Text(
                'What kind of plan?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Plan type chips
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: bffPlanTypes.map((type) {
                  final plan = BffPlan(
                    id: '',
                    conversationId: '',
                    createdBy: '',
                    planType: type,
                    scheduledAt: DateTime.now(),
                    status: 'proposed',
                    createdAt: DateTime.now(),
                  );
                  final selected = _selectedType == type;
                  return ChoiceChip(
                    label: Text('${plan.typeEmoji} ${plan.typeLabel}'),
                    selected: selected,
                    selectedColor: _accent.withValues(alpha: 0.2),
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: selected ? _accent : AppColors.textMuted,
                    ),
                    side: BorderSide(
                      color: selected
                          ? _accent.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                    onSelected: (_) => setState(() => _selectedType = type),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Location
              Text(
                'Where?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _locationCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Kadikoy, Istanbul',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: _accent),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Date & Time
              Text(
                'When?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: _accent, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              DateFormat('EEE, d MMM').format(_selectedDate),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                color: _accent, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: AppColors.bg,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.bg,
                          ),
                        )
                      : const Text(
                          'Send plan',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
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
// Time picker sheet — 5-minute step, consistent with video scheduling
// ---------------------------------------------------------------------------

class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _TimePickerSheet({required this.initial});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour.clamp(
        SchedulingConfig.startHour, SchedulingConfig.endHour);
    _minute = SchedulingConfig.snapMinute(widget.initial.minute);
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(
      SchedulingConfig.endHour - SchedulingConfig.startHour + 1,
      (i) => SchedulingConfig.startHour + i,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Select time',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hours.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) {
                final h = hours[i];
                final isSel = h == _hour;
                return GestureDetector(
                  onTap: () => setState(() => _hour = h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSel ? _accent : AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                          color: isSel ? _accent : AppColors.border),
                    ),
                    child: Text(
                      '${_pad(h)}:__',
                      style: TextStyle(
                        color: isSel ? AppColors.bg : AppColors.textPrimary,
                        fontWeight:
                            isSel ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: AppSpacing.xs),
            Row(
              children: SchedulingConfig.minutes
                  .sublist(row * 6, row * 6 + 6)
                  .map((m) {
                final isSel = m == _minute;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: GestureDetector(
                      onTap: () => setState(() => _minute = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSel
                              ? _accent.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                              color: isSel ? _accent : AppColors.border),
                        ),
                        child: Text(
                          ':${_pad(m)}',
                          style: TextStyle(
                            color: isSel ? _accent : AppColors.textMuted,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: AppColors.bg,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () =>
                  Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute)),
              child: Text(
                'Confirm ${_pad(_hour)}:${_pad(_minute)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
