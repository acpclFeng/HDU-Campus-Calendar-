// 事件卡：时间 + 标题 + 标签 + 一行灰色详情（地点 / 教师 / 节次 / 学分 / 周次）。

import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/models.dart';
import 'common.dart';

String _shortTime(String value) {
  final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})').firstMatch(value);
  if (m != null) return '${m.group(2)}-${m.group(3)} ${m.group(4)}:${m.group(5)}';
  final hm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  return hm != null ? '${hm.group(1)}:${hm.group(2)}' : value;
}

class EventCard extends StatelessWidget {
  final CalEvent event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1D2029) : Colors.white;
    final meta = _metaBits();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.of(event.type),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 11, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.baseline,
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      Text(
                        event.start.isEmpty ? '全天' : '${event.start}–${event.end}',
                        style: const TextStyle(fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      Text(event.title,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      if (event.type != 'class')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.of(event.type).withOpacity(0.13),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(AppColors.label(event.type),
                              style: TextStyle(fontSize: 10.5, color: AppColors.of(event.type))),
                        ),
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 92),
                      child: Text(meta.join(' ｜ '),
                          style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey.shade600)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _metaBits() {
    final bits = <String>[];
    if (event.place.isNotEmpty) bits.add(event.place);
    if (event.type == 'class') {
      if (event.teacher.isNotEmpty) bits.add(event.teacher);
      if (event.sections.isNotEmpty) bits.add(event.sections);
      if (event.credit.isNotEmpty) bits.add('${event.credit} 学分');
      if (event.weeks.isNotEmpty) {
        bits.add(event.weeks.contains('周次') ? event.weeks : '上课周次 ${event.weeks}');
      }
    } else if (event.type == 'activity') {
      final e = event.extra;
      if ((e['hostName'] ?? '').toString().isNotEmpty) bits.add('主办：${e['hostName']}');
      if ((e['deadline'] ?? '').toString().isNotEmpty) {
        bits.add('截止：${_shortTime(e['deadline'].toString())}');
      }
      if ((e['span'] ?? '').toString().isNotEmpty) bits.add(e['span'].toString());
    } else {
      final e = event.extra;
      if ((e['seat'] ?? '').toString().isNotEmpty) bits.add('座位：${e['seat']}');
      if ((e['mode'] ?? '').toString().isNotEmpty) bits.add(e['mode'].toString());
    }
    return bits;
  }
}
