// 课程日历 · 安卓独立版入口
// 启动逻辑：本机有令牌 → 直接进日历；没有 → 进令牌页。全程没有 PIN。

import 'package:flutter/material.dart';
import 'core/token_store.dart';
import 'ui/token_screen.dart';
import 'ui/calendar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // release 包默认把渲染异常画成一块空白，用户只会看到「点了没反应」。
  // 这里改成把错误直接显示在屏幕上，方便一眼定位 / 截图反馈。
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFFFF4E5),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          '界面渲染出错，请把这段截图发我：\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A4B00)),
        ),
      ),
    );
  };

  runApp(const CampusCalendarApp());
}

class CampusCalendarApp extends StatelessWidget {
  const CampusCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '课程日历',
      debugShowCheckedModeBanner: false,
      // 固定浅色：参考截图就是浅色版；系统深色模式在部分机型上会把
      // 标题/图例等文字压成深底深字、整页看起来像「只剩一个日历网格」。
      themeMode: ThemeMode.light,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: const _Root(),
    );
  }

  ThemeData _lightTheme() {
    const seed = Color(0xFF2F6FED);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF4F5F8),
      fontFamily: null,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
    );
  }

  ThemeData _darkTheme() {
    const seed = Color(0xFF2F6FED);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF14161C),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final TokenStore _store = TokenStore();
  String? _token;
  bool _ready = false;
  bool _editing = false; // 设置里点「更换令牌」时回到令牌页，可取消

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await _store.readToken();
    if (!mounted) return;
    setState(() {
      _token = (token != null && token.trim().isNotEmpty) ? token.trim() : null;
      _ready = true;
    });
  }

  Future<void> _onSaved(String token) async {
    await _store.saveToken(token);
    if (!mounted) return;
    setState(() {
      _token = token.trim();
      _editing = false;
    });
  }

  Future<void> _onCleared() async {
    await _store.clearToken();
    if (!mounted) return;
    setState(() {
      _token = null;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token == null || _editing) {
      return TokenScreen(
        onSaved: _onSaved,
        onCancel: _editing ? () => setState(() => _editing = false) : null,
        initialToken: _editing ? _token : null,
      );
    }
    // key 绑定令牌：更换令牌后强制重建页面状态，否则会继续用旧令牌的 service
    return CalendarScreen(
      key: ValueKey(_token!),
      token: _token!,
      onCleared: _onCleared,
      onChangeToken: () => setState(() => _editing = true),
    );
  }
}
