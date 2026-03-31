import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/bff_plan.dart';
import '../../providers/bff_provider.dart';

const _teal = Color(0xFF26C6DA);

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
  }

  Future<void> _loadPlans() async {
    final plans = await ref.read(bffProvider.notifier).fetchPlans(widget.conversationId);
    if (mounted) setState(() => _existingPlans = plans);
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
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _teal,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _teal,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan sent!'),
        backgroundColor: _teal,
      ),
    );
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
                    border: Border.all(color: _teal.withValues(alpha: 0.2)),
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
                                style: TextStyle(color: _teal, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.isAccepted ? _teal.withValues(alpha: 0.15) : AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p.status[0].toUpperCase() + p.status.substring(1),
                            style: TextStyle(color: p.isAccepted ? _teal : AppColors.textMuted, fontSize: 11)),
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
                    selectedColor: _teal.withValues(alpha: 0.2),
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: selected ? _teal : AppColors.textMuted,
                    ),
                    side: BorderSide(
                      color: selected
                          ? _teal.withValues(alpha: 0.5)
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
                    borderSide: const BorderSide(color: _teal),
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
                                color: _teal, size: 18),
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
                                color: _teal, size: 18),
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
                    backgroundColor: _teal,
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
