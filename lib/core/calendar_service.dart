// 日历聚合层：把校园接口返回的原始数据换算成「哪天有哪些事」。
// 从旧网页版 app/calendar.py 逐函数移植，规则完全一致：
//   日期 = 学期开始 + (教学周-1)*7 + (星期几-1)，周一起算；
//   同一门课相邻小节合并成一段；二课跨天展开；考试单独成条。

import 'date_utils.dart';
import 'hdu_api.dart';
import 'models.dart';

class CalendarService {
  final HduApi api;
  final Map<String, _Memo> _cache = {};

  CalendarService(String token) : api = HduApi(token);

  Future<T> _memo<T>(String key, Duration ttl, Future<T> Function() factory) async {
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return hit.value as T;
    }
    final value = await factory();
    _cache[key] = _Memo(DateTime.now(), value);
    return value;
  }

  void clearCache() => _cache.clear();

  Future<Term> term() => _memo('term', const Duration(minutes: 10), () async {
        return Term.fromApi(await api.call('schooltime'));
      });

  /// 课表分页拉全（每页 200 条）
  Future<List<Map<String, dynamic>>> scheduleRows(Term term) {
    final key = 'schedule:${term.schoolYear}:${term.semester}';
    return _memo(key, const Duration(minutes: 10), () async {
      final rows = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        final data = await api.call('term_schedule', {
          'schoolYear': term.schoolYear,
          'semester': term.semester,
          'limit': 200,
          'offset': offset,
        });
        final batch = HduApi.items(data);
        rows.addAll(batch);
        if (batch.length < 200) break;
        offset += 200;
        if (offset > 2000) break;
      }
      return rows;
    });
  }

  Future<List<Map<String, dynamic>>> activities({bool mine = true}) {
    final key = 'activities:${mine ? 'mine' : 'public'}';
    return _memo(key, const Duration(minutes: 5), () async {
      if (mine) {
        return HduApi.items(await api.call('my_activities', {'status': 1, 'page': 1}));
      }
      return HduApi.items(await api.call('campus_events', {
        'page': 1,
        'pageSize': 100,
        'status': 8,
      }));
    });
  }

  /// 「全部二课」开 = 「我的二课」∪ 全校公开活动，关 = 只看我的。
  /// 用「活动编号」+「活动名|开始时间」双键去重；命中同一条时把后到的字段
  /// 补进来（不覆盖已有非空值），既不重复显示，也不丢公开列表里的名额/状态。
  /// 任一接口失败时退化为另一接口的结果，不让整个月历一起挂掉。
  Future<List<Map<String, dynamic>>> _safeActivities(
      {required bool mine}) async {
    try {
      return await activities(mine: mine);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> activityRows(
      {bool includePublic = true}) async {
    final mine = await _safeActivities(mine: true);
    if (!includePublic) return mine;
    final publicList = await _safeActivities(mine: false);
    final list = <Map<String, dynamic>>[];
    final index = <String, int>{};

    void add(Map<String, dynamic> item) {
      final keys = _activityKeys(item);
      var at = -1;
      for (final k in keys) {
        final hit = index[k];
        if (hit != null) {
          at = hit;
          break;
        }
      }
      if (at >= 0) {
        list[at] = _mergeActivity(list[at], item);
      } else {
        at = list.length;
        list.add(item);
      }
      for (final k in keys) {
        index[k] = at;
      }
    }

    for (final item in mine) {
      add(item);
    }
    for (final item in publicList) {
      add(item);
    }
    return list;
  }

  /// 考试接口常因教务处未开放返回业务码，转成一条提示而不是让整个日历报错
  Future<_ExamResult> exams() =>
      _memo('exams', const Duration(minutes: 30), () async {
        try {
          return _ExamResult(HduApi.items(await api.call('my_exams')), const []);
        } on HduError catch (e) {
          return _ExamResult(const [], [Notice(type: 'exam_unavailable', text: e.userMessage())]);
        }
      });

  Future<_DaysResult> daysFor(String first, String last, {bool includePublic = false}) async {
    // 局部变量不能与同名实例方法 term()/exams() 重名，否则 Dart 会判定
    // 「声明前引用」并把方法引用解析成局部变量（见 CI 编译报错）。
    final termInfo = await term();
    final days = <String, List<CalEvent>>{};

    _merge(days, classEvents(await scheduleRows(termInfo), termInfo));
    _merge(days,
        activityEvents(await activityRows(includePublic: includePublic)));
    final examResult = await exams();
    _merge(days, examEvents(examResult.items));

    final sorted = <String, List<CalEvent>>{};
    final keys = days.keys.toList()..sort();
    for (final key in keys) {
      if (key.compareTo(first) < 0 || key.compareTo(last) > 0) continue;
      final list = List<CalEvent>.from(days[key]!);
      list.sort((a, b) {
        final sa = a.start.isEmpty ? '99:99' : a.start;
        final sb = b.start.isEmpty ? '99:99' : b.start;
        final c = sa.compareTo(sb);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
      sorted[key] = list;
    }
    return _DaysResult(termInfo, sorted, examResult.notices);
  }

  Future<CalendarResult> range(String first, String last, {bool includePublic = false}) async {
    final r = await daysFor(first, last, includePublic: includePublic);
    final today = todayIso();
    final thisWeek = (today.compareTo(r.term.startDate) >= 0 &&
            today.compareTo(r.term.endDate) <= 0)
        ? r.term.weekOf(today)
        : 0;
    return CalendarResult(
      term: r.term,
      today: today,
      thisWeek: thisWeek,
      days: r.days,
      notices: r.notices,
      generatedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<CalendarResult> month(int year, int month, {bool includePublic = false}) {
    final b = monthBounds(year, month);
    return range(b[0], b[1], includePublic: includePublic);
  }

  Future<CalendarResult> week(String anchor, {bool includePublic = false}) async {
    final b = weekBounds(anchor);
    final base = await range(b[0], b[1], includePublic: includePublic);
    return CalendarResult(
      term: base.term,
      today: base.today,
      thisWeek: base.thisWeek,
      days: base.days,
      notices: base.notices,
      generatedAt: base.generatedAt,
      weekStart: b[0],
      weekEnd: b[1],
      week: (b[0].compareTo(base.term.startDate) >= 0 &&
              b[0].compareTo(base.term.endDate) <= 0)
          ? base.term.weekOf(b[0])
          : 0,
    );
  }
}

class _Memo {
  final DateTime at;
  final dynamic value;
  const _Memo(this.at, this.value);
}

class _DaysResult {
  final Term term;
  final Map<String, List<CalEvent>> days;
  final List<Notice> notices;
  const _DaysResult(this.term, this.days, this.notices);
}

class _ExamResult {
  final List<Map<String, dynamic>> items;
  final List<Notice> notices;
  const _ExamResult(this.items, this.notices);
}

List<String> _activityKeys(Map<String, dynamic> item) {
  final id = (item['activityID'] ?? item['id'] ?? item['activityId'] ?? '')
      .toString()
      .trim();
  final name = (item['activityName'] ?? item['name'] ?? '').toString().trim();
  final start =
      (item['activityStartTime'] ?? item['startTime'] ?? '').toString().trim();
  final keys = <String>[];
  if (id.isNotEmpty) keys.add('id:$id');
  if (name.isNotEmpty && start.isNotEmpty) keys.add('ns:$name|$start');
  return keys;
}

Map<String, dynamic> _mergeActivity(
    Map<String, dynamic> base, Map<String, dynamic> extra) {
  final out = Map<String, dynamic>.from(base);
  extra.forEach((k, v) {
    final cur = out[k];
    if (cur == null || (cur is String && cur.isEmpty)) out[k] = v;
  });
  return out;
}

void _merge(Map<String, List<CalEvent>> target, Map<String, List<CalEvent>> extra) {
  extra.forEach((day, list) {
    target.putIfAbsent(day, () => <CalEvent>[]).addAll(list);
  });
}

String _eventId(String prefix, List<dynamic> parts) {
  final raw = '$prefix:${parts.join('|')}';
  var hash = 0;
  for (final unit in raw.codeUnits) {
    hash = ((hash << 5) - hash + unit) & 0x7fffffff;
  }
  return '$prefix:${hash.toRadixString(16).padLeft(12, '0').substring(0, 12)}';
}

/// 解析上课周次：优先 weeks 数组，其次从 classTime 里的 "{2-17周}" 提取
List<int> parseWeeks(Map<String, dynamic> row) {
  final set = <int>{};
  final weeks = row['weeks'];
  if (weeks is List && weeks.isNotEmpty) {
    for (final w in weeks) {
      final n = asInt(w);
      if (n > 0) set.add(n);
    }
  } else {
    final m = RegExp(r'\{([\d,\-\s]+)周\}').firstMatch(row['classTime']?.toString() ?? '');
    if (m != null) {
      for (final chunk in m.group(1)!.split(',')) {
        final c = chunk.trim();
        if (c.isEmpty) continue;
        if (c.contains('-')) {
          final p = c.split('-');
          final low = asInt(p[0]);
          final high = asInt(p[1]);
          if (low > 0 && high >= low) {
            for (var i = low; i <= high; i++) {
              set.add(i);
            }
          }
        } else {
          final n = asInt(c);
          if (n > 0) set.add(n);
        }
      }
    }
  }
  final out = set.toList()..sort();
  return out;
}

String weeksLabel(Iterable<int> weeks) {
  final seen = <int>{};
  for (final w in weeks) {
    if (w > 0) seen.add(w);
  }
  final ordered = seen.toList()..sort();
  if (ordered.isEmpty) return '';
  final ranges = <String>[];
  var low = ordered.first;
  var high = ordered.first;
  for (final n in ordered.skip(1)) {
    if (n == high + 1) {
      high = n;
      continue;
    }
    ranges.add(low == high ? '$low' : '$low-$high');
    low = n;
    high = n;
  }
  ranges.add(low == high ? '$low' : '$low-$high');
  return '第${ranges.join(',')}周';
}

List<int> sectionsOf(Map<String, dynamic> row) {
  final set = <int>{};
  final raw = row['sections'];
  if (raw is List && raw.isNotEmpty) {
    for (final s in raw) {
      final n = asInt(s);
      if (n > 0) set.add(n);
    }
  } else {
    final n = asInt(row['period']);
    if (n > 0) set.add(n);
  }
  return set.toList()..sort();
}

/// 课表：按 (日期, 课程名, 地点, 教师) 分桶，把同一天的相邻小节并成一段
Map<String, List<CalEvent>> classEvents(List<Map<String, dynamic>> rows, Term term) {
  final buckets = <String, _ClassBucket>{};
  for (final row in rows) {
    final day = asInt(row['day']);
    final weeks = parseWeeks(row);
    final name = (row['courseName'] ?? '').toString().trim();
    if (day < 1 || day > 7 || weeks.isEmpty || name.isEmpty) continue;
    final place = (row['locationName'] ?? row['location'] ?? '').toString().trim();
    final teacher = (row['teacherName'] ?? row['teacher'] ?? '').toString().trim();
    for (final week in weeks) {
      final when = term.dateOf(week, day);
      if (when.isEmpty) continue;
      final key = [when, name, place, teacher].join('|');
      buckets.putIfAbsent(key, () => _ClassBucket(when, name, place, teacher)).rows.add(row);
    }
  }

  final days = <String, List<CalEvent>>{};
  for (final b in buckets.values) {
    final starts = b.rows.map((r) => clockOf(r['startTime'])).where((s) => s.isNotEmpty).toList()
      ..sort();
    final ends = b.rows.map((r) => clockOf(r['endTime'])).where((s) => s.isNotEmpty).toList()
      ..sort();
    final sections = <int>{};
    for (final r in b.rows) {
      sections.addAll(sectionsOf(r));
    }
    final secList = sections.toList()..sort();
    final sectionText = secList.length > 1
        ? '${secList.first}-${secList.last}节'
        : (secList.isNotEmpty ? '${secList.first}节' : '');
    String credit = '';
    for (final r in b.rows) {
      if (r['credit'] != null && r['credit'].toString().isNotEmpty) {
        credit = r['credit'].toString();
        break;
      }
    }
    final allWeeks = <int>[];
    for (final r in b.rows) {
      allWeeks.addAll(parseWeeks(r));
    }
    if (allWeeks.isEmpty) {
      for (final r in b.rows) {
        final w = asInt(r['week']);
        if (w > 0) allWeeks.add(w);
      }
    }
    days.putIfAbsent(b.when, () => <CalEvent>[]).add(CalEvent(
          id: _eventId('class', [b.name, b.place, b.when]),
          type: 'class',
          title: b.name,
          start: starts.isEmpty ? '' : starts.first,
          end: ends.isEmpty ? '' : ends.last,
          place: b.place,
          teacher: b.teacher,
          sections: sectionText,
          credit: credit,
          weeks: weeksLabel(allWeeks),
          extra: const {},
        ));
  }
  return days;
}

class _ClassBucket {
  final String when;
  final String name;
  final String place;
  final String teacher;
  final List<Map<String, dynamic>> rows = [];
  _ClassBucket(this.when, this.name, this.place, this.teacher);
}

/// 二课活动：跨天活动按天展开
Map<String, List<CalEvent>> activityEvents(List<Map<String, dynamic>> list) {
  final days = <String, List<CalEvent>>{};
  for (final item in list) {
    final name = (item['activityName'] ?? item['name'] ?? '').toString().trim();
    final startAt = parseApiDateTime(item['activityStartTime']);
    var endAt = parseApiDateTime(item['activityEndTime']) ?? startAt;
    if (name.isEmpty || startAt == null || endAt == null) continue;
    if (endAt.isBefore(startAt)) endAt = startAt;

    final firstDay = isoOf(DateTime(startAt.year, startAt.month, startAt.day));
    final lastDay = isoOf(DateTime(endAt.year, endAt.month, endAt.day));
    var totalDays = parseIso(lastDay).difference(parseIso(firstDay)).inDays + 1;
    if (totalDays < 1) totalDays = 1;

    final hostName = (item['hostName'] ?? '').toString();
    final deadline = (item['applyEndTime'] ?? '').toString();
    final activityId = (item['activityID'] ?? item['id'] ?? '').toString();

    for (var offset = 0; offset < totalDays; offset++) {
      final day = addDays(firstDay, offset);
      final startText = offset == 0 ? hm(startAt) : '全天';
      final endText = totalDays > 1
          ? (day == lastDay && offset != 0 ? hm(endAt) : '全天')
          : hm(endAt);
      final extra = <String, dynamic>{
        'hostName': hostName,
        'deadline': deadline,
        'activityID': activityId,
        // 下面这些只用于报名确认弹窗展示，不参与日历计算
        'activityStatusName': (item['activityStatusName'] ?? '').toString(),
        'applyCount': item['applyCount'],
        'totalCount': item['totalCount'],
      };
      if (totalDays > 1) extra['span'] = '第${offset + 1}/$totalDays天';
      days.putIfAbsent(day, () => <CalEvent>[]).add(CalEvent(
            id: _eventId('activity', [activityId, day]),
            type: 'activity',
            title: name,
            start: startText,
            end: endText,
            place: (item['position'] ?? '').toString(),
            teacher: '',
            sections: '',
            credit: '',
            weeks: '',
            extra: extra,
          ));
    }
  }
  return days;
}

/// 考试
Map<String, List<CalEvent>> examEvents(List<Map<String, dynamic>> list) {
  final days = <String, List<CalEvent>>{};
  for (final item in list) {
    final name = (item['examName'] ?? item['courseName'] ?? item['name'] ?? '')
        .toString()
        .trim();
    final startAt = parseApiDateTime(
        item['examTime'] ?? item['startTime'] ?? item['examDate'] ?? item['startAt']);
    if (name.isEmpty || startAt == null) continue;
    var endAt = parseApiDateTime(item['endTime'] ?? item['examEndTime']);
    endAt ??= startAt.add(const Duration(hours: 2));
    final day = isoOf(DateTime(startAt.year, startAt.month, startAt.day));
    days.putIfAbsent(day, () => <CalEvent>[]).add(CalEvent(
          id: _eventId('exam', [name, startAt.millisecondsSinceEpoch]),
          type: 'exam',
          title: name,
          start: hm(startAt),
          end: hm(endAt),
          place: (item['location'] ?? item['classroom'] ?? item['place'] ?? '').toString(),
          teacher: '',
          sections: '',
          credit: '',
          weeks: '',
          extra: {
            'seat': (item['seatNo'] ?? item['seat'] ?? '').toString(),
            'mode': (item['examType'] ?? item['mode'] ?? '').toString(),
          },
        ));
  }
  return days;
}
