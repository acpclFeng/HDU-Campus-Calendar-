// 二课「确认报名 / 取消报名」：先查状态与报名要求 → 弹二次确认 → 才真实写入学校系统。
// 官方 OpenAPI 对写接口有硬性要求：报名前查状态、查要求、展示活动信息、取得明确确认；
// 取消前先查「我的二课」拿真实编号。所有写操作绝不静默提交。
//
// 布局注意：这里全部用 Column(mainAxisSize.min) + Wrap，
// 绝不使用 Row(crossAxisAlignment: stretch)（在无限高约束下会把卡片撑成 infinity）。

import 'package:flutter/material.dart';
import '../../core/hdu_api.dart';
import '../../core/models.dart';

class ActionResult {
  final bool ok;
  final String text;
  const ActionResult(this.ok, this.text);
}

class ActivityActions {
  final HduApi api;
  const ActivityActions(this.api);

  String _s(dynamic v) => v == null ? '' : v.toString();

  String _shortTime(String value) {
    final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})')
        .firstMatch(value);
    if (m != null) {
      return '${m.group(2)}-${m.group(3)} ${m.group(4)}:${m.group(5)}';
    }
    final hm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
    return hm != null ? '${hm.group(1)}:${hm.group(2)}' : value;
  }

  List<MapEntry<String, String>> _lines(CalEvent event) {
    final e = event.extra;
    final out = <MapEntry<String, String>>[
      MapEntry('活动名称', event.title),
      MapEntry('活动时间',
          event.start.isEmpty ? '全天' : '${event.start} – ${event.end}'),
    ];
    if (event.place.isNotEmpty) out.add(MapEntry('活动地点', event.place));
    if (_s(e['hostName']).isNotEmpty) {
      out.add(MapEntry('主办方', _s(e['hostName'])));
    }
    if (_s(e['activityStatusName']).isNotEmpty) {
      out.add(MapEntry('活动状态', _s(e['activityStatusName'])));
    }
    if (_s(e['deadline']).isNotEmpty) {
      out.add(MapEntry('报名截止', _shortTime(_s(e['deadline']))));
    }
    if (e['applyCount'] != null && e['totalCount'] != null) {
      final applied = _s(e['applyCount']);
      final total = _s(e['totalCount']);
      out.add(MapEntry('已报/名额', '$applied / $total'));
    }
    final id = _s(e['activityID']);
    out.add(MapEntry('活动编号', id.isEmpty ? '—' : id));
    return out;
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String warn,
    required String confirmText,
    required List<MapEntry<String, String>> lines,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(warn,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF8A4B00))),
                ),
                const SizedBox(height: 10),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(line.key,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ),
                        Expanded(
                          child: Text(line.value,
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('先不操作'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 写入接口用 submitted/verified/success/registered 区分「已提交」和「真的成功」
  ActionResult _explain(dynamic d, String verb) {
    final m = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    final submitted = m['submitted'] == true;
    final verified = m['verified'] == true;
    final success = m['success'] == true;
    final hasReg = m.containsKey('registered');
    final registered = m['registered'] == true;
    final want = verb == '报名';
    var ok = success || (verified && (!hasReg || registered == want));
    if (success && hasReg && registered != want) ok = false;
    final msg = _s(m['message']).trim();
    final tail = msg.isEmpty
        ? (ok ? '，日历已刷新' : '，请到杭电助手里再确认一下')
        : '：$msg';
    final text = ok
        ? '$verb成功$tail'
        : (submitted && !verified)
            ? '$verb已提交，学校系统暂未确认，稍后点刷新看看'
            : '$verb未完成$tail';
    return ActionResult(ok, text);
  }

  Future<ActionResult> apply(BuildContext context, CalEvent event) async {
    final id = _s(event.extra['activityID']);
    if (id.isEmpty) return const ActionResult(false, '这条活动缺少编号，无法报名');

    final lines = _lines(event);
    var statusText = '状态查询失败（仍可尝试）';
    try {
      final reg = await api.call('activity_status', {'activityId': id});
      if (reg is Map && reg['registered'] == true) {
        return const ActionResult(false, '你已经报名过这个活动了，不用重复报名');
      }
      statusText = '尚未报名';
    } catch (_) {
      // 查不到也让用户在弹窗里自己决定
    }
    lines.add(MapEntry('报名状态', statusText));

    try {
      final req =
          await api.call('activity_requirements', {'activityId': id});
      if (req is Map && req['auditRequired'] is bool) {
        lines.add(MapEntry(
            '报名要求',
            req['auditRequired'] == true
                ? '需负责人审核，报名后不一定立即生效'
                : '无需审核，报名后直接生效'));
      }
    } catch (_) {
      // 非必需信息，取不到就不显示
    }

    final confirmed = await _confirm(
      context,
      title: '确认报名',
      warn: '这是真实操作：会把你的报名提交到学校二课系统。请先核对上面的活动信息。',
      confirmText: '确认报名',
      lines: lines,
    );
    if (!confirmed) return const ActionResult(false, '');

    try {
      final d = await api.call('activity_apply', {'activityId': id});
      return _explain(d, '报名');
    } on HduError catch (e) {
      return ActionResult(false, '报名未成功：${e.userMessage()}');
    } catch (e) {
      return ActionResult(false, '报名未成功：$e');
    }
  }

  Future<ActionResult> cancel(BuildContext context, CalEvent event) async {
    final id = _s(event.extra['activityID']);
    if (id.isEmpty) {
      return const ActionResult(false, '这条活动缺少编号，无法取消报名');
    }

    final lines = _lines(event);
    var realId = '';
    var foundText = '没查到记录（可能未报名，或活动已结束）';
    try {
      final mine = HduApi.items(await api.call('my_activities',
          {'status': 0, 'page': 1, 'pageSize': 100}));
      for (final item in mine) {
        final candidate = (item['activityID'] ?? item['id'] ?? '').toString();
        if (candidate == id) {
          realId = candidate;
          foundText = '已在「我的二课」中找到，可取消';
          break;
        }
      }
    } catch (_) {
      foundText = '查询失败（仍可尝试按活动编号取消）';
    }
    lines.add(MapEntry('报名记录', foundText));

    final confirmed = await _confirm(
      context,
      title: '取消报名',
      warn: '这是真实操作：会取消你在学校二课系统的报名，名额可能被别人抢走，请谨慎。',
      confirmText: '确认取消报名',
      lines: lines,
    );
    if (!confirmed) return const ActionResult(false, '');

    try {
      final d = await api.call('activity_cancel', {
        'activityId': realId.isEmpty ? id : realId,
        'reason': '在课程日历中取消报名',
      });
      return _explain(d, '取消报名');
    } on HduError catch (e) {
      return ActionResult(false, '取消未成功：${e.userMessage()}');
    } catch (e) {
      return ActionResult(false, '取消未成功：$e');
    }
  }
}
