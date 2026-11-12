// 共用小组件：三色圆点、图例、提示条。配色与截图一致（蓝 / 橙 / 红）。

import 'package:flutter/material.dart';
import '../../core/models.dart';

class AppColors {
  static const blue = Color(0xFF2F6FED);   // 上课
  static const orange = Color(0xFFF39C12); // 第二课堂活动
  static const red = Color(0xFFE5484D);    // 考试
  static const navy = Color(0xFF1E3A63);  // 选中框 / 分割线

  static Color of(String type) {
    switch (type) {
      case 'activity':
        return orange;
      case 'exam':
        return red;
      default:
        return blue;
    }
  }

  static String label(String type) {
    switch (type) {
      case 'activity':
        return '二课';
      case 'exam':
        return '考试';
      default:
        return '课堂';
    }
  }
}

class TypeDot extends StatelessWidget {
  final String type;
  final double size;
  const TypeDot(this.type, {super.key, this.size = 5});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.of(type), shape: BoxShape.circle),
      );
}

class DayDots extends StatelessWidget {
  final List<CalEvent> events;
  const DayDots({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final types = events.map((e) => e.type).toSet();
    final shown = ['class', 'activity', 'exam'].where(types.contains).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in shown) ...[
          if (t != shown.first) const SizedBox(width: 3),
          TypeDot(t),
        ],
      ],
    );
  }
}

class Legend extends StatelessWidget {
  const Legend({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(fontSize: 12, color: Colors.grey.shade600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          _item('上课', AppColors.blue, textStyle),
          const SizedBox(width: 14),
          _item('第二课堂活动', AppColors.orange, textStyle),
          const SizedBox(width: 14),
          _item('考试', AppColors.red, textStyle),
        ],
      ),
    );
  }

  Widget _item(String label, Color color, TextStyle style) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: style),
        ],
      );
}

class NoticesBar extends StatelessWidget {
  final List<Notice> notices;
  const NoticesBar({super.key, required this.notices});

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2F1C) : const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        notices.map((n) => n.text).where((t) => t.isNotEmpty).join(' · '),
        style: TextStyle(
          fontSize: 12.5,
          height: 1.5,
          color: dark ? const Color(0xFFF2C98A) : const Color(0xFF8A5200),
        ),
      ),
    );
  }
}
