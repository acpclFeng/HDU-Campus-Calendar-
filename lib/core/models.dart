// 数据模型：学期、日历事件、提示条、一个月/一周的聚合结果。
// 全部提供 toJson / fromJson，用于把上次结果缓存到手机本机（离线可看）。

import 'date_utils.dart';

class Term {
  final String schoolYear;
  final String semester;
  final int weekNow;
  final int weekDayNow;
  final String startDate;
  final String endDate;
  final int weeks;

  const Term({
    required this.schoolYear,
    required this.semester,
    required this.weekNow,
    required this.weekDayNow,
    required this.startDate,
    required this.endDate,
    required this.weeks,
  });

  String get label => '$schoolYear 学年 第${semester.isEmpty ? '?' : semester}学期';

  /// 教学周 + 星期几 → 日期（周一起算）
  String dateOf(int week, int day) {
    if (week < 1 || day < 1 || day > 7) return '';
    return addDays(startDate, (week - 1) * 7 + (day - 1));
  }

  int weekOf(String iso) =>
      (parseIso(iso).difference(parseIso(startDate)).inDays ~/ 7) + 1;

  Map<String, dynamic> toJson() => {
        'schoolYear': schoolYear,
        'semester': semester,
        'weekNow': weekNow,
        'weekDayNow': weekDayNow,
        'startDate': startDate,
        'endDate': endDate,
        'weeks': weeks,
      };

  factory Term.fromJson(Map<String, dynamic> j) => Term(
        schoolYear: (j['schoolYear'] ?? '').toString(),
        semester: (j['semester'] ?? '').toString(),
        weekNow: asInt(j['weekNow']),
        weekDayNow: asInt(j['weekDayNow']),
        startDate: (j['startDate'] ?? '').toString(),
        endDate: (j['endDate'] ?? '').toString(),
        weeks: asInt(j['weeks'], 20),
      );

  /// 从校历接口返回的 data 解析
  factory Term.fromApi(dynamic data) {
    final j = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final start = parseApiDate(j['termStartDate'] ?? j['startDate']) ?? todayIso();
    final end = parseApiDate(j['termEndDate'] ?? j['endDate']) ?? addDays(start, 140);
    var weeks = asInt(j['termWeeks']);
    if (weeks <= 0) {
      weeks = (parseIso(end).difference(parseIso(start)).inDays ~/ 7) + 1;
      if (weeks < 1) weeks = 1;
    }
    return Term(
      schoolYear: (j['schoolYear'] ?? '').toString(),
      semester: (j['semester'] ?? '').toString(),
      weekNow: asInt(j['weekNow']),
      weekDayNow: asInt(j['weekDayNow']),
      startDate: start,
      endDate: end,
      weeks: weeks,
    );
  }
}

class CalEvent {
  final String id;
  final String type; // class / activity / exam
  final String title;
  final String start;
  final String end;
  final String place;
  final String teacher;
  final String sections;
  final String credit;
  final String weeks;
  final Map<String, dynamic> extra;

  const CalEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.start,
    required this.end,
    required this.place,
    required this.teacher,
    required this.sections,
    required this.credit,
    required this.weeks,
    required this.extra,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'start': start,
        'end': end,
        'place': place,
        'teacher': teacher,
        'sections': sections,
        'credit': credit,
        'weeks': weeks,
        'extra': extra,
      };

  factory CalEvent.fromJson(Map<String, dynamic> j) => CalEvent(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        start: (j['start'] ?? '').toString(),
        end: (j['end'] ?? '').toString(),
        place: (j['place'] ?? '').toString(),
        teacher: (j['teacher'] ?? '').toString(),
        sections: (j['sections'] ?? '').toString(),
        credit: (j['credit'] ?? '').toString(),
        weeks: (j['weeks'] ?? '').toString(),
        extra: j['extra'] is Map
            ? Map<String, dynamic>.from(j['extra'] as Map)
            : <String, dynamic>{},
      );
}

class Notice {
  final String type;
  final String text;
  const Notice({required this.type, required this.text});
  Map<String, dynamic> toJson() => {'type': type, 'text': text};
  factory Notice.fromJson(Map<String, dynamic> j) =>
      Notice(type: (j['type'] ?? '').toString(), text: (j['text'] ?? '').toString());
}

class CalendarResult {
  final Term term;
  final String today;
  final int thisWeek;
  final Map<String, List<CalEvent>> days;
  final List<Notice> notices;
  final String generatedAt;
  final String? weekStart;
  final String? weekEnd;
  final int? week;

  const CalendarResult({
    required this.term,
    required this.today,
    required this.thisWeek,
    required this.days,
    required this.notices,
    required this.generatedAt,
    this.weekStart,
    this.weekEnd,
    this.week,
  });

  Map<String, dynamic> toJson() => {
        'term': term.toJson(),
        'today': today,
        'thisWeek': thisWeek,
        'days': days.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'notices': notices.map((n) => n.toJson()).toList(),
        'generatedAt': generatedAt,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'week': week,
      };

  factory CalendarResult.fromJson(Map<String, dynamic> j) => CalendarResult(
        term: Term.fromJson(Map<String, dynamic>.from(j['term'] as Map)),
        today: (j['today'] ?? '').toString(),
        thisWeek: asInt(j['thisWeek']),
        days: (j['days'] is Map)
            ? (j['days'] as Map).map((k, v) => MapEntry(
                  k.toString(),
                  (v as List)
                      .map((e) => CalEvent.fromJson(Map<String, dynamic>.from(e as Map)))
                      .toList(),
                ))
            : <String, List<CalEvent>>{},
        notices: (j['notices'] is List)
            ? (j['notices'] as List)
                .map((e) => Notice.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : <Notice>[],
        generatedAt: (j['generatedAt'] ?? '').toString(),
        weekStart: j['weekStart']?.toString(),
        weekEnd: j['weekEnd']?.toString(),
        week: j['week'] == null ? null : asInt(j['week']),
      );
}
