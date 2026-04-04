import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 3D rotating drum/wheel date picker with day, month, year columns.
/// Handles variable days per month including leap year February (29 days).
class DrumDatePicker extends StatefulWidget {
  final int? day, month, year;
  final void Function(int day, int month, int year) onChanged;

  const DrumDatePicker({super.key, this.day, this.month, this.year, required this.onChanged});

  @override
  State<DrumDatePicker> createState() => _DrumDatePickerState();
}

class _DrumDatePickerState extends State<DrumDatePicker> {
  static const _monthLabels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  late int _currentDay;
  late int _currentMonth;
  late int _currentYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentDay = widget.day ?? 15;
    _currentMonth = widget.month ?? 6;
    _currentYear = widget.year ?? (now.year - 25);
  }

  static bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

  static int _daysInMonth(int month, int year) {
    const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) return 29;
    return daysPerMonth[month - 1];
  }

  void _onMonthChanged(int month) {
    final maxDay = _daysInMonth(month, _currentYear);
    final clampedDay = _currentDay > maxDay ? maxDay : _currentDay;
    setState(() {
      _currentMonth = month;
      _currentDay = clampedDay;
    });
    widget.onChanged(clampedDay, month, _currentYear);
  }

  void _onYearChanged(int year) {
    final maxDay = _daysInMonth(_currentMonth, year);
    final clampedDay = _currentDay > maxDay ? maxDay : _currentDay;
    setState(() {
      _currentYear = year;
      _currentDay = clampedDay;
    });
    widget.onChanged(clampedDay, _currentMonth, year);
  }

  void _onDayChanged(int day) {
    setState(() => _currentDay = day);
    widget.onChanged(day, _currentMonth, _currentYear);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxDays = _daysInMonth(_currentMonth, _currentYear);
    final days = List.generate(maxDays, (i) => i + 1);
    final months = List.generate(12, (i) => i + 1);
    final minYear = now.year - 80;
    final maxYear = now.year - 18;
    final years = List.generate(maxYear - minYear + 1, (i) => maxYear - i);

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Day
              Expanded(child: _DrumColumn<int>(
                key: ValueKey('day_$maxDays'),
                items: days,
                initialItem: _currentDay.clamp(1, maxDays),
                labelBuilder: (v) => v.toString().padLeft(2, '0'),
                onChanged: _onDayChanged,
              )),
              Container(width: 1, color: AppColors.emerald600.withValues(alpha: 0.15)),
              // Month
              Expanded(child: _DrumColumn<int>(
                items: months,
                initialItem: _currentMonth,
                labelBuilder: (v) => _monthLabels[v - 1],
                onChanged: _onMonthChanged,
              )),
              Container(width: 1, color: AppColors.emerald600.withValues(alpha: 0.15)),
              // Year
              Expanded(child: _DrumColumn<int>(
                items: years,
                initialItem: _currentYear,
                labelBuilder: (v) => v.toString(),
                onChanged: _onYearChanged,
              )),
            ],
          ),
          // Gold selection band
          Positioned(
            top: 160 / 2 - 22,
            left: 0, right: 0,
            child: IgnorePointer(child: Column(children: [
              Container(height: 1, color: AppColors.emerald600.withValues(alpha: 0.35)),
              const SizedBox(height: 43),
              Container(height: 1, color: AppColors.emerald600.withValues(alpha: 0.35)),
            ])),
          ),
        ],
      ),
    );
  }
}

/// Single drum column with 3D perspective scroll.
class _DrumColumn<T> extends StatefulWidget {
  final List<T> items;
  final T initialItem;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _DrumColumn({
    super.key,
    required this.items,
    required this.initialItem,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  State<_DrumColumn<T>> createState() => _DrumColumnState<T>();
}

class _DrumColumnState<T> extends State<_DrumColumn<T>> {
  late FixedExtentScrollController _controller;
  int _selectedIndex = 0;

  static const _itemExtent = 44.0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.items.indexOf(widget.initialItem);
    if (_selectedIndex < 0) _selectedIndex = 0;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: _itemExtent,
      diameterRatio: 1.1,
      perspective: 0.004,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        setState(() => _selectedIndex = i);
        HapticFeedback.selectionClick();
        widget.onChanged(widget.items[i]);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.items.length,
        builder: (context, index) {
          final isSelected = index == _selectedIndex;
          final distance = (index - _selectedIndex).abs();

          double opacity;
          double fontSize;
          FontWeight weight;
          Color color;

          if (distance == 0) {
            opacity = 1.0; fontSize = 22; weight = FontWeight.w700; color = AppColors.emerald600;
          } else if (distance == 1) {
            opacity = 0.45; fontSize = 16; weight = FontWeight.w500; color = Colors.white;
          } else {
            opacity = 0.15; fontSize = 12; weight = FontWeight.w400; color = Colors.white;
          }

          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 100),
              style: TextStyle(
                color: color.withValues(alpha: opacity),
                fontSize: fontSize,
                fontWeight: weight,
                letterSpacing: isSelected ? 0.5 : 0,
              ),
              child: Text(widget.labelBuilder(widget.items[index])),
            ),
          );
        },
      ),
    );
  }
}
