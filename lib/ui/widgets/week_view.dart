// 周历：7 张日卡片，每天的课程/二课/考试直接列在卡片里。
// 卡片本身不响应点击：只有顶部「月历」标签能切视图（之前点卡片会误跳月历）。

import 'package:flutter/material.dart';
import '../../core/date_utils.dart';
import '../../core/models.dart';
import 'event_card.dart';

class WeekView extends StatelessWidget {
  final CalendarResult data;
  final Set<String> filters;

  const WeekView({
    super.key,
    required this.data,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D2029) : Colors.white;
    final names = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final start = data.weekStart ?? todayIso();
    final today = todayIso();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Builder(builder: (context) {
            final key = addDays(start, i);
            final d = parseIso(key);
            final events = (data.days[key] ?? [])
                .where((e) => filters.contains(e.type))
                .toList();
            final isToday = key == today;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${d.month}月${d.day}日 ${names[d.weekday % 7]}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isToday ? const Color(0xFF2F6FED) : null,
                          )),
                      Text(events.isEmpty ? '空' : '${events.length} 项',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('没有安排',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    )
                  else ...[
                    const SizedBox(height: 6),
                    for (final e in events) EventCard(event: e),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
