// 令牌页：首次启动（或更换令牌）时唯一需要操作的地方。
// 输入 → 用校历接口校验 → 系统级加密保存 → 进入日历。没有 PIN、没有账号。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/hdu_api.dart';
import '../core/token_store.dart';

class TokenScreen extends StatefulWidget {
  final Future<void> Function(String token) onSaved;
  final VoidCallback? onCancel;
  final String? initialToken;
  const TokenScreen({
    super.key,
    required this.onSaved,
    this.onCancel,
    this.initialToken,
  });

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final _controller = TextEditingController();
  final _store = TokenStore();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) _controller.text = widget.initialToken!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _controller.text.trim();
    if (token.isEmpty) {
      setState(() => _error = '请先粘贴令牌');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    // 校验：401/403 判定令牌无效；网络不通时允许先保存，联网后自动加载
    String? warning;
    try {
      final api = HduApi(token);
      await api.call('schooltime');
      api.close();
    } on HduError catch (e) {
      if (e.kind == 'auth') {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = '令牌无效或已过期，请重新复制';
        });
        return;
      }
      warning = '暂时连不上校园服务，令牌已保存，联网后会自动加载';
    } catch (_) {
      warning = '暂时连不上校园服务，令牌已保存，联网后会自动加载';
    }

    await _store.saveToken(token);
    await widget.onSaved(token);
    if (!mounted) return;
    setState(() => _busy = false);
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning), duration: const Duration(seconds: 4)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFF2F6FED),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('课程日历',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('课表 · 二课 · 考试，一张日历看全',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('杭电助手个人访问令牌',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1D2029) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.only(left: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '粘贴你的令牌',
                            ),
                            onSubmitted: (_) => _busy ? null : _submit(),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          child: Text(_obscure ? '显示' : '隐藏',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('令牌加密保存在这台手机的系统密钥库，不会上传到任何服务器',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.5)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F6FED),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('保存并进入', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: 'https://neo.hduhelp.com'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('网址已复制，打开浏览器 → 个人访问令牌'),
                        duration: Duration(seconds: 3),
                      ));
                    },
                    child: Text('去哪里拿令牌？ neo.hduhelp.com ↗',
                        style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.primary)),
                  ),
                  if (widget.onCancel != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('取消，继续用当前令牌', style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFD64545))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
