// 杭电助手 OpenAPI 客户端：手机 App 直接 HTTPS 请求，不需要电脑、不需要后端。
// 只调用 5 个只读接口。令牌放在 Authorization: Bearer 里，只发往 api.hduhelp.com。
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
        return message.trim().isEmpty ? '校园服务暂时不可用，稍后再试' : message.trim();
    }
  }

  @override
  String toString() => 'HduError($kind): $message';
}

class _Op {
  final String path;
  final List<String> params;
  const _Op(this.path, this.params);
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
};

class HduApi {
  static const String base = 'https://api.hduhelp.com';
  static const Duration timeout = Duration(seconds: 12);

  final String token;
  final http.Client _client;

  HduApi(this.token, {http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(_Op op, Map<String, dynamic> params) {
    final query = <String, String>{};
    for (final key in op.params) {
      final v = params[key];
      if (v != null) query[key] = v.toString();
    }
    return Uri.parse('$base${op.path}').replace(queryParameters: query.isEmpty ? null : query);
  }

  /// 统一拆掉 {code,msg,data} 信封，业务码非 0 抛错
  dynamic _unwrap(dynamic payload) {
    if (payload is Map && payload.containsKey('code')) {
      final code = payload['code'];
      final bad = code != 0 && code != '0' && code != null;
      if (bad) {
        final msg = (payload['msg'] ?? payload['message'] ?? '').toString();
        final kind = (code == 401 || code == 403) ? 'auth' : 'business';
        throw HduError(kind, msg, status: code is int ? code : null);
      }
      return payload['data'];
    }
    if (payload is Map && payload.containsKey('data')) return payload['data'];
    return payload;
  }

  Future<dynamic> call(String name, [Map<String, dynamic> params = const {}]) async {
    final op = _ops[name];
    if (op == null) throw HduError('protocol', '未知接口: $name');
    if (token.trim().isEmpty) throw HduError('auth', '令牌未配置');

    try {
      final response = await _client
          .get(
            _uri(op, params),
            headers: {
              'Authorization': 'Bearer ${token.trim()}',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HduError('auth', 'HTTP ${response.statusCode}',
            status: response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HduError('http', 'HTTP ${response.statusCode}',
            status: response.statusCode);
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
