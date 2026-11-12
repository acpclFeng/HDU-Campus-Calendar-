// 月历网格：周一起算 42 格，跨月的灰字日期、今天橙框、选中深蓝框、三类圆点。

import 'package:flutter/material.dart';
import '../../core/date_utils.dart';
import '../../core/models.dart';
import 'common.dart';

class MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final String selected;
  final Map<String, List<CalEvent>> days;
  final Set<String> filters;
  final ValueChanged<DateTime> onTap;

  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.selected,
    required this.days,
    required this.filters,
    required this.onTap,
  });

  List<CalEvent> _eventsFor(String key) =>
      (days[key] ?? []).where((e) => filters.contains(e.type)).toList();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D2029) : Colors.white;
    final start = gridStart(year, month);
    final today = todayIso();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WeekdayHeader(),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final key = addDays(start, index);
              // parseIso 是 UTC 零点，直接取它的年月日，绝不 toLocal（否则负时区会串到前一天）
              final d = parseIso(key);
              final out = d.year != year || d.month != month;
              final isToday = key == today;
              final isSelected = key == selected;
              final events = _eventsFor(key);

              return GestureDetector(
                onTap: () => onTap(DateTime(d.year, d.month, d.day)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (dark ? const Color(0xFF22304D) : const Color(0xFFEEF3FF))
                        : (isToday
                            ? (dark ? const Color(0xFF33291B) : const Color(0xFFFFF9F0))
                            : Colors.transparent),
                    border: Border.all(
                      width: 1.5,
                      color: isToday
                          ? AppColors.orange
                          : (isSelected
                              ? (dark ? const Color(0xFF5B8DEF) : AppColors.navy)
                              : Colors.transparent),
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${d.day}',
                              style: TextStyle(
                                fontSize: 14,
                                color: out
                                    ? (dark ? const Color(0xFF565C6B) : const Color(0xFFC3C7D1))
                                    : (dark ? const Color(0xFFDFE2EA) : const Color(0xFF2A2F3A)),
                              )),
                          if (isToday)
                            Text(' 今天',
                                style: TextStyle(fontSize: 9, color: AppColors.orange)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DayDots(events: events),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(names[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: i >= 5 ? const Color(0xFFB06A00) : Colors.grey.shade600,
                  )),
            ),
          ),
      ],
    );
  }
}
