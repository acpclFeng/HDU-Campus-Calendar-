// 课程日历 · 安卓独立版入口
// 启动逻辑：本机有令牌 → 直接进日历；没有 → 进令牌页。全程没有 PIN。

import 'package:flutter/material.dart';
import 'core/token_store.dart';
import 'ui/token_screen.dart';
import 'ui/calendar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusCalendarApp());
}

class CampusCalendarApp extends StatelessWidget {
  const CampusCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '课程日历',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // 跟随系统深色模式
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
