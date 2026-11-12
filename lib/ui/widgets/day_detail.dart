// 日详情：选中那天的标题（含教学周）+ 事件列表，空态提示。

import 'package:flutter/material.dart';
import '../../core/date_utils.dart';
import '../../core/models.dart';
import 'event_card.dart';

class DayDetail extends StatelessWidget {
  final String selected;
  final Term? term;
  final Map<String, List<CalEvent>> days;
  final Set<String> filters;

  const DayDetail({
    super.key,
    required this.selected,
    required this.term,
    required this.days,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    final d = parseIso(selected);
    final names = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    var weekNo = 0;
    if (term != null &&
        selected.compareTo(term!.startDate) >= 0 &&
        selected.compareTo(term!.endDate) <= 0) {
      weekNo = term!.weekOf(selected);
    }
    final events = (days[selected] ?? [])
        .where((e) => filters.contains(e.type))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.month}月${d.day}日 ${names[d.weekday % 7]}' +
                (weekNo > 0 ? ' · 第 $weekNo 教学周' : ''),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('这天没有安排，休息一下～',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            )
          else
            for (final e in events) EventCard(event: e),
        ],
      ),
    );
  }
}
