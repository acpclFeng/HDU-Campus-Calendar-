// 杭电助手 OpenAPI 客户端：手机 App 直接 HTTPS 请求，不需要电脑、不需要后端。
// 读取类 5 个接口；写入类只有「二课报名 / 取消报名」，必须经用户二次确认后才调用。
// 令牌放在 Authorization: Bearer 里，只发往 api.hduhelp.com。
//
// 已实测该服务返回 Access-Control-Allow-Origin（反射来源）且放行 Authorization，
// 所以浏览器 PWA 能直连；原生 App 更没有跨域限制。

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HduError implements Exception {
  final String kind; // auth / timeout / network / business / http / protocol
  final String message;
  final int? status;
  HduError(this.kind, this.message, {this.status});

  String userMessage() {
    switch (kind) {
      case 'auth':
        return '令牌无效或已过期，请在设置里更换令牌';
      case 'timeout':
        return '校园服务响应有点慢，稍后再试';
      case 'network':
        return '连不上校园服务，检查手机网络后重试';
      case 'business':
        return message.trim().isEmpty ? '校园服务暂时没有数据' : message.trim();
      default:
        // 不再笼统说「上游服务暂不可用」：名额已满等业务失败以前会被误报成服务故障
        return message.trim().isEmpty ? '学校服务暂时没有回应，稍后再试' : message.trim();
    }
  }

  @override
  String toString() => 'HduError($kind): $message';
}

class _Op {
  final String path;
  final List<String> params;
  final String method;
  final List<String> pathParams;
  const _Op(this.path, this.params,
      {this.method = 'GET', this.pathParams = const []});
}

const Map<String, _Op> _ops = {
  'schooltime': _Op('/hduhelp-neo/academic/schooltime/time', []),
  'term_schedule': _Op('/hduhelp-neo/academic/schedule',
      ['schoolYear', 'semester', 'week', 'limit', 'offset']),
  'my_activities': _Op('/hduhelp-neo/campuslife/activities/mine',
      ['status', 'page', 'pageSize']),
  'campus_events': _Op('/hduhelp-neo/campuslife/activities',
      ['page', 'pageSize', 'status', 'content', 'hostName']),
  'my_exams':
      _Op('/hduhelp-neo/academic/exam', ['schoolYear', 'semester']),

  // ---- 二课报名（写入类，调用前必须由用户在弹窗里明确确认） ----
  'activity_status': _Op(
      '/hduhelp-neo/campuslife/activities/{activityId}/registration', [],
      pathParams: ['activityId']),
  'activity_requirements': _Op(
      '/hduhelp-neo/campuslife/activities/{activityId}/application-requirements',
      [],
      pathParams: ['activityId']),
  'activity_apply': _Op(
      '/hduhelp-neo/campuslife/activities/{activityId}/registration', [],
      method: 'POST', pathParams: ['activityId']),
  'activity_cancel': _Op(
      '/hduhelp-neo/campuslife/activities/{activityId}/registration',
      ['reason'],
      method: 'DELETE', pathParams: ['activityId']),
};

class HduApi {
  static const String base = 'https://api.hduhelp.com';
  static const Duration timeout = Duration(seconds: 12);

  final String token;
  final http.Client _client;

  HduApi(this.token, {http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(_Op op, Map<String, dynamic> params) {
    // 活动编号在路径里，不在查询串里
    var path = op.path;
    for (final key in op.pathParams) {
      final v = params[key];
      if (v == null || v.toString().trim().isEmpty) {
        throw HduError('protocol', '缺少活动编号，无法操作');
      }
      path = path.replaceAll('{$key}', Uri.encodeComponent(v.toString()));
    }
    final query = <String, String>{};
    for (final key in op.params) {
      final v = params[key];
      if (v != null) query[key] = v.toString();
    }
    return Uri.parse('$base$path')
        .replace(queryParameters: query.isEmpty ? null : query);
  }

  /// 学校接口错误文案字段不统一，data 里还可能再套一层
  static String _messageOf(dynamic payload) {
    if (payload is! Map) {
      return payload is String ? payload.trim() : '';
    }
    final m = Map<String, dynamic>.from(payload);
    for (final key in [
      'msg',
      'message',
      'error',
      'reason',
      'errorMessage',
      'detail',
      'description',
    ]) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    if (m['data'] is Map) return _messageOf(m['data']);
    return '';
  }

  /// HTTP 非 2xx 时把响应体里的真实原因带出来。
  /// 旧版直接丢掉 body，只留 "HTTP 400"，最后被兜底成「上游服务暂不可用」，
  /// 于是「名额已满」这类正常业务失败看起来像应用/服务坏了。
  static String _bodyMessage(List<int> bytes) {
    String text;
    try {
      text = utf8.decode(bytes).trim();
    } catch (_) {
      return '';
    }
    if (text.isEmpty) return '';
    try {
      final msg = _messageOf(jsonDecode(text));
      if (msg.isNotEmpty) return msg;
      return '';
    } catch (_) {
      if (text.length < 200 && !text.startsWith('<')) return text;
      return '';
    }
  }

  /// 统一拆掉 {code,msg,data} 信封，业务码非 0 抛错
  dynamic _unwrap(dynamic payload) {
    if (payload is Map && payload.containsKey('code')) {
      final code = payload['code'];
      final bad = code != 0 && code != '0' && code != null;
      if (bad) {
        final kind = (code == 401 || code == 403) ? 'auth' : 'business';
        throw HduError(kind, _messageOf(payload),
            status: code is int ? code : null);
      }
      return payload['data'];
    }
    if (payload is Map && payload.containsKey('data')) return payload['data'];
    return payload;
  }

  /// method 不传就用接口定义的默认方法；写操作自动带幂等键，连点不会重复报名。
  Future<dynamic> call(String name,
      [Map<String, dynamic> params = const {}, String? method]) async {
    final op = _ops[name];
    if (op == null) throw HduError('protocol', '未知接口: $name');
    if (token.trim().isEmpty) throw HduError('auth', '令牌未配置');
    final m = method ?? op.method;
    final uri = _uri(op, params);
    final headers = <String, String>{
      'Authorization': 'Bearer ${token.trim()}',
      'Accept': 'application/json',
    };
    if (m == 'POST' || m == 'DELETE') {
      final key = params['idempotencyKey']?.toString();
      headers['Idempotency-Key'] = (key == null || key.isEmpty)
          ? 'cc-$name-${DateTime.now().millisecondsSinceEpoch ~/ 30000}'
          : key;
      headers['Content-Type'] = 'application/json';
    }

    try {
      late http.Response response;
      if (m == 'POST') {
        response = await _client.post(uri, headers: headers).timeout(timeout);
      } else if (m == 'DELETE') {
        response = await _client.delete(uri, headers: headers).timeout(timeout);
      } else {
        response = await _client.get(uri, headers: headers).timeout(timeout);
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HduError('auth', 'HTTP ${response.statusCode}',
            status: response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = _bodyMessage(response.bodyBytes);
        throw HduError(
          detail.isEmpty ? 'http' : 'business',
          detail.isEmpty ? 'HTTP ${response.statusCode}' : detail,
          status: response.statusCode,
        );
      }
      final dynamic payload = jsonDecode(utf8.decode(response.bodyBytes));
      return _unwrap(payload);
    } on HduError {
      rethrow;
    } on TimeoutException {
      throw HduError('timeout', '请求超时');
    } on FormatException {
      throw HduError('protocol', '返回内容不是 JSON');
    } catch (e) {
      throw HduError('network', e.toString());
    }
  }

  /// 接口 data 可能是数组，也可能是 {items/list/records/rows} 包了一层
  static List<Map<String, dynamic>> items(dynamic data) {
    List<dynamic>? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      for (final key in ['items', 'list', 'records', 'rows']) {
        if (data[key] is List) {
          raw = data[key] as List;
          break;
        }
      }
    }
    if (raw == null) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void close() => _client.close();
}
