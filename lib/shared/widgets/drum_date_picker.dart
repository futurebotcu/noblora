import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 3D rotating drum/wheel date picker with day, month, year columns.
class DrumDatePicker extends StatelessWidget {
  final int? day, month, year;
  final void Function(int day, int month, int year) onChanged;

  const DrumDatePicker({super.key, this.day, this.month, this.year, required this.onChanged});

  static const _monthLabels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(31, (i) => i + 1);
    final months = List.generate(12, (i) => i + 1);
    final minYear = now.year - 80;
    final maxYear = now.year - 18;
    final years = List.generate(maxYear - minYear + 1, (i) => maxYear - i);

    final initDay = day ?? 15;
    final initMonth = month ?? 6;
    final initYear = year ?? (now.year - 25);

    return Container(
      height: 220,
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
                items: days,
                initialItem: initDay,
                labelBuilder: (v) => v.toString().padLeft(2, '0'),
                onChanged: (v) => onChanged(v, month ?? initMonth, year ?? initYear),
              )),
              Container(width: 1, color: AppColors.gold.withValues(alpha: 0.15)),
              // Month
              Expanded(child: _DrumColumn<int>(
                items: months,
                initialItem: initMonth,
                labelBuilder: (v) => _monthLabels[v - 1],
                onChanged: (v) => onChanged(day ?? initDay, v, year ?? initYear),
              )),
              Container(width: 1, color: AppColors.gold.withValues(alpha: 0.15)),
              // Year
              Expanded(child: _DrumColumn<int>(
                items: years,
                initialItem: initYear,
                labelBuilder: (v) => v.toString(),
                onChanged: (v) => onChanged(day ?? initDay, month ?? initMonth, v),
              )),
            ],
          ),
          // Gold selection band
          Positioned(
            top: 220 / 2 - 22,
            left: 0, right: 0,
            child: IgnorePointer(child: Column(children: [
              Container(height: 1, color: AppColors.gold.withValues(alpha: 0.35)),
              const SizedBox(height: 43),
              Container(height: 1, color: AppColors.gold.withValues(alpha: 0.35)),
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
      diameterRatio: 1.6,
      perspective: 0.003,
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
            opacity = 1.0; fontSize = 22; weight = FontWeight.w700; color = AppColors.gold;
          } else if (distance == 1) {
            opacity = 0.6; fontSize = 17; weight = FontWeight.w500; color = Colors.white;
          } else {
            opacity = 0.25; fontSize = 13; weight = FontWeight.w400; color = Colors.white;
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
