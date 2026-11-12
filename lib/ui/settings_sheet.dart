// 设置面板：查看令牌掩码、更换令牌、清除令牌并退出、最近同步时间。

import 'package:flutter/material.dart';
import '../core/token_store.dart';

class SettingsSheet extends StatefulWidget {
  final String token;
  final VoidCallback onChangeToken;
  final VoidCallback onClear;

  const SettingsSheet({
    super.key,
    required this.token,
    required this.onChangeToken,
    required this.onClear,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _store = TokenStore();
  String _lastSync = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _store.lastSync();
    if (!mounted) return;
    setState(() {
      if (v == null) {
        _lastSync = '尚未同步';
      } else {
        final d = DateTime.tryParse(v)?.toLocal();
        _lastSync = d == null
            ? '—'
            : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _row('当前令牌', TokenStore.mask(widget.token)),
            _row('存储方式', '系统密钥库加密'),
            _row('最近同步', _lastSync),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEEF3FF),
                        foregroundColor: const Color(0xFF2F6FED),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onChangeToken();
                      },
                      child: const Text('更换令牌', style: TextStyle(fontSize: 13.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFECEC),
                        foregroundColor: const Color(0xFFC0393E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onClear();
                      },
                      child: const Text('清除令牌并退出', style: TextStyle(fontSize: 13.5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('更换或清除后需要重新输入令牌。旧网页版与这里互不影响。',
                style: TextStyle(fontSize: 11.5, height: 1.6, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text(value, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      );
}
