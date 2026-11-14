// 事件卡：时间 + 标题 + 标签 + 一行灰色详情（地点 / 教师 / 节次 / 学分 / 周次）。
//
// 布局注意：外层是 SingleChildScrollView → Column，纵向约束是「无限高」。
// 这里绝不能用 Row(crossAxisAlignment: CrossAxisAlignment.stretch)：
// 在无限高约束下 Flutter release 包会把卡片高度算成 infinity，
// 于是排在它后面的筛选 chips / 页脚 / 后续事件全部被推到屏幕之外，
// 表现就是「下半屏一片空白、按钮点了没反应」。
// 现在用 Stack + Positioned：高度由内容撑开，左侧色条再按卡片高度拉伸。

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

typedef EventAction = void Function(BuildContext context, CalEvent event);

class EventCard extends StatelessWidget {
  final CalEvent event;
  final bool showActions;
  final EventAction? onApply;
  final EventAction? onCancel;

  const EventCard({
    super.key,
    required this.event,
    this.showActions = false,
    this.onApply,
    this.onCancel,
  });

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
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.of(event.type),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    Text(
                      event.start.isEmpty ? '全天' : '${event.start}–${event.end}',
                      style: const TextStyle(
                          fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]),
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
                if (event.type == 'activity' && showActions) ...[
                  const SizedBox(height: 9),
                  _actionsRow(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 用 Wrap 而不是 Row：窄屏放不下时自动换行，不会把「取消报名」挤出屏幕。
  Widget _actionsRow(BuildContext context) {
    final id = (event.extra['activityID'] ?? '').toString();
    final enabled = id.isNotEmpty && onApply != null && onCancel != null;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          enabled ? '点按钮可报名 / 取消报名' : '缺少活动编号',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        _actionButton(
          label: '确认报名',
          background: const Color(0xFF2F6FED),
          foreground: Colors.white,
          onTap: enabled ? () => onApply!(context, event) : null,
        ),
        _actionButton(
          label: '取消报名',
          background: const Color(0xFFFFF1F1),
          foreground: const Color(0xFFC0393E),
          border: true,
          onTap: enabled ? () => onCancel!(context, event) : null,
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback? onTap,
    bool border = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : background,
          borderRadius: BorderRadius.circular(9),
          border: border ? Border.all(color: const Color(0xFFF0C7C7)) : null,
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: onTap == null ? Colors.grey.shade600 : foreground,
            )),
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
