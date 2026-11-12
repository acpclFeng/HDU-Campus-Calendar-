// 纯日期工具：统一用 YYYY-MM-DD 字符串做键，避免时区把日期算错一天。
// 与旧网页版 app/calendar.py 的换算规则一致：周一起算，日期 = 学期开始 + (周-1)*7 + (日-1)。

String pad2(int n) => n.toString().padLeft(2, '0');

String isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}-${pad2(d.day)}';

/// 把 YYYY-MM-DD 变成 UTC 零点的 DateTime，专门用来做「只加天数」的运算
DateTime parseIso(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String addDays(String iso, int n) =>
    isoOf(parseIso(iso).add(Duration(days: n)));

/// 1=周一 … 7=周日
int weekdayOf(String iso) => parseIso(iso).weekday;

/// 手机本地今天
String todayIso() {
  final now = DateTime.now();
  return isoOf(DateTime(now.year, now.month, now.day));
}

/// 把接口里的日期时间（时间戳 / 字符串）解析为本地 DateTime
DateTime? parseApiDateTime(dynamic value) {
  if (value == null || value == '') return null;
  if (value is int) {
    var ms = value;
    if (ms > 10000000000) ms = ms ~/ 1000; // 毫秒 → 秒
    if (ms > 10000000000) ms = ms ~/ 1000; // 兜底
    try {
      return DateTime.fromMillisecondsSinceEpoch(ms * 1000);
    } catch (_) {
      return null;
    }
  }
  if (value is String && RegExp(r'^\d+$').hasMatch(value.trim())) {
    return parseApiDateTime(int.parse(value.trim()));
  }
  final text = value.toString().trim().replaceFirst('T', ' ');
  final m = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(text);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4) ?? '0'),
    int.parse(m.group(5) ?? '0'),
    int.parse(m.group(6) ?? '0'),
  );
}

String hm(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}';

String? parseApiDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(text);
  if (m == null) return null;
  return '${m.group(1)}-${pad2(int.parse(m.group(2)!))}-${pad2(int.parse(m.group(3)!))}';
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  return int.tryParse(value.toString().trim()) ?? fallback;
}

String clockOf(dynamic value) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value?.toString() ?? '');
  if (m == null) return '';
  return '${pad2(int.parse(m.group(1)!))}:${m.group(2)}';
}

/// 月历网格边界：从本月 1 号所在周的周一开始，一共 42 格
String gridStart(int year, int month) {
  final first = '$year-${pad2(month)}-01';
  final wd = weekdayOf(first); // 1..7
  return addDays(first, -(wd - 1));
}

List<String> monthBounds(int year, int month) {
  final first = DateTime.utc(year, month, 1);
  final last = DateTime.utc(year, month + 1, 0);
  return [isoOf(first), isoOf(last)];
}

List<String> weekBounds(String anchor) {
  final monday = addDays(anchor, -(weekdayOf(anchor) - 1));
  return [monday, addDays(monday, 6)];
}
