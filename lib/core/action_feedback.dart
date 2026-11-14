// 二课「报名 / 取消报名」结果分类。
//
// 背景：学校接口在名额已满、报名截止等场景会返回 HTTP 4xx/5xx 或业务码，
// 旧版只留下 "HTTP 400" 这类空壳信息，最后兜底显示「上游服务暂不可用」，
// 用户会以为应用坏了，其实只是人满了。这里统一把原始文案/状态码翻译成
// 「类别 + 原因 + 下一步建议」，绝不再把业务失败说成服务不可用。
//
// 纯 Dart，不依赖 Flutter，网页版 js/app.js 里有同规则的实现。

enum ActionCategory {
  ok,
  pending,
  full,
  closed,
  already,
  notRegistered,
  ineligible,
  conflict,
  auth,
  rate,
  service,
  unknown,
  missing,
}

class ActionFeedback {
  final ActionCategory category;
  final bool ok;
  final String label;
  final String text;

  /// 某些失败其实透露了真实报名状态（例如「已报名」「本来没报名」），
  /// 顺手把按钮状态修正，省得用户再点一次。
  final bool? registrationHint;

  const ActionFeedback(
    this.category,
    this.ok,
    this.label,
    this.text, {
    this.registrationHint,
  });

  factory ActionFeedback.success(String verb) => ActionFeedback(
        ActionCategory.ok,
        true,
        '操作成功',
        '$verb成功，已同步刷新日历与按钮状态',
      );

  factory ActionFeedback.pending(String verb) => ActionFeedback(
        ActionCategory.pending,
        false,
        '结果待确认',
        '$verb已提交，但学校系统还没确认。稍后点一下刷新，或去杭电助手查报名状态',
      );

  factory ActionFeedback.uncertain(String verb) => ActionFeedback(
        ActionCategory.pending,
        false,
        '结果不确定',
        '$verb没拿到明确结果：学校系统没说明成功还是失败。先去杭电助手确认报名状态，别急着重复提交',
      );

  factory ActionFeedback.missing(String what) => ActionFeedback(
        ActionCategory.missing,
        false,
        '无法操作',
        what,
      );
}

/// 从接口返回的 data 里挖出错误文案（不同接口字段不统一）
String feedbackRaw(dynamic value) {
  if (value is! Map) return value == null ? '' : value.toString().trim();
  final m = Map<String, dynamic>.from(value);
  for (final key in [
    'message',
    'msg',
    'error',
    'reason',
    'detail',
    'tip',
    'description',
    'errorMessage',
  ]) {
    final v = m[key];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  }
  if (m['data'] is Map) return feedbackRaw(m['data']);
  return '';
}

bool _matches(String text, String pattern) =>
    RegExp(pattern, caseSensitive: false).hasMatch(text);

/// 把一次失败归类。applying=true 是报名，false 是取消报名。
/// status / kind 来自 HduError；quota 形如 "120/120"，deadline 是报名截止时间。
ActionFeedback classifyActionFailure({
  required bool applying,
  required String raw,
  String quota = '',
  String deadline = '',
  int? status,
  String kind = '',
}) {
  final verb = applying ? '报名' : '取消报名';
  final fail = applying ? '报名没成功' : '取消没成功';
  final t = raw.trim();
  final quotaText = quota.isEmpty ? '' : '（已报 $quota）';
  final deadlineText = deadline.isEmpty ? '' : '（截止 $deadline）';

  ActionFeedback fb(
          ActionCategory c, String label, String body, {bool? hint}) =>
      ActionFeedback(c, false, label, '【$label】$body',
          registrationHint: hint);

  // 1. 登录态问题优先级最高，换令牌才有意义
  if (kind == 'auth' ||
      status == 401 ||
      status == 403 ||
      _matches(t, r'令牌|登录|未授权|身份失效|token|401|403')) {
    return fb(
      ActionCategory.auth,
      '登录失效',
      '$fail：令牌无效或已过期，不是活动的问题。去「设置」重新粘贴令牌再试',
    );
  }

  // 2. 名额满了 —— 用户反馈里最常见的误判
  if (_matches(t,
      r'名额|人数.{0,6}满|已满|报满|满员|上限|超出.{0,6}(名额|人数)|quota|capacity|is full')) {
    return fb(
      ActionCategory.full,
      '名额已满',
      applying
          ? '$fail：这场二课已经报满$quotaText，不是应用坏了。可以等有人取消空出名额后再试'
          : '$fail：学校返回名额相关限制$quotaText，稍后重试或去杭电助手处理',
    );
  }

  // 3. 已经报名 / 本来没报名：其实是状态问题，不是失败
  if (applying &&
      _matches(t, r'重复报名|已经报名|已报名|无需.{0,4}报名|already')) {
    return fb(
      ActionCategory.already,
      '已经报名',
      '不用重复报名：学校系统说你已经在名单里了。按钮已帮你改成「已报名」，可点刷新再确认',
      hint: true,
    );
  }
  if (!applying &&
      _matches(t,
          r'未报名|没有报名|无报名记录|未找到.{0,6}(报名|记录)|不存在.{0,6}记录|not registered|no registration')) {
    return fb(
      ActionCategory.notRegistered,
      '本来没报名',
      '不用取消：学校系统里查不到你的报名记录。按钮已更新，可点刷新再确认',
      hint: false,
    );
  }

  // 4. 报名时间问题
  if (_matches(t,
      r'截止|过期|报名.{0,4}(结束|关闭|未开始|未开放)|不在报名|超出.{0,4}时间|expired|deadline|not open')) {
    final notStarted = _matches(t, r'未开始|未开放|not open|尚未');
    return fb(
      ActionCategory.closed,
      notStarted ? '尚未开放' : '报名已截止',
      '$fail：这场二课的报名时间${notStarted ? '还没开始' : '已经过了'}$deadlineText，不是网络问题',
    );
  }

  // 5. 资格 / 条件 / 冲突
  if (_matches(t, r'资格|不符合|不允许|限制|审核|年级|学院|专业|黑名单|报名条件|范围')) {
    return fb(
      ActionCategory.ineligible,
      '条件不符',
      '$fail：你的账号不满足这场活动的报名条件${t.isEmpty ? '' : '：$t'}',
    );
  }
  if (_matches(t, r'冲突|时间重叠')) {
    return fb(
      ActionCategory.conflict,
      '时间冲突',
      '$fail：和你已报名的其他活动时间冲突，先处理那边再试',
    );
  }
  if (_matches(t, r'频繁|太快|重复提交|限流|幂等|操作过于')) {
    return fb(
      ActionCategory.rate,
      '操作太频繁',
      '$fail：学校系统让你缓一下再提交，等几秒重试即可',
    );
  }

  // 6. 真的服务异常：只在没有更具体的原因时才这么说
  final pureHttp = RegExp(r'^HTTP\s*\d{3}$', caseSensitive: false).hasMatch(t);
  final serviceKind = kind == 'timeout' ||
      kind == 'network' ||
      kind == 'http' ||
      kind == 'protocol';
  if (t.isEmpty ||
      pureHttp ||
      (status != null && status >= 500) ||
      serviceKind ||
      _matches(t,
          r'超时|网络|不可用|网关|系统错误|服务异常|繁忙|稍后再试|try again|HTTP\s*5\d\d|502|503|504')) {
    // 4xx 属于「学校明确拒绝了这次操作」，通常是名额/时间/资格限制，
    // 就算没给原因也不能说成服务故障
    if (status != null &&
        status >= 400 &&
        status < 500 &&
        (t.isEmpty || pureHttp)) {
      return fb(
        ActionCategory.unknown,
        '学校系统拒绝',
        '$fail：学校返回 HTTP $status 但没说明原因，通常是名额、时间或资格限制，'
            '不是应用坏了。建议去杭电助手确认报名状态，或稍后再试',
      );
    }
    return fb(
      ActionCategory.service,
      '学校服务异常',
      '$verb结果不确定：学校接口这会儿没正常回应${t.isEmpty ? '' : '（$t）'}。'
          '不是应用坏了、也不是没名额；建议先去杭电助手确认报名状态，稍后再试',
    );
  }

  // 7. 上游给了明确但没匹配到规则的原因：原样呈现，别再自己瞎猜
  return fb(
    ActionCategory.unknown,
    '学校系统返回',
    '$fail：$t',
  );
}
