// 主页面：月历 / 周历切换、翻页、回到今天、三类筛选、日详情、设置、离线提示。
// 布局按你给的截图 1:1 还原：标题 + 学期副标题 → 月历/周历 → ‹ 回到今天 ›
// → 月份标题（深蓝下划线）→ 三色图例 → 42 格日历 → 当天详情 → 筛选 chips。

import 'package:flutter/material.dart';
import '../core/calendar_service.dart';
import '../core/date_utils.dart';
import '../core/hdu_api.dart';
import '../core/models.dart';
import '../core/token_store.dart';
import 'settings_sheet.dart';
import 'widgets/common.dart';
import 'widgets/day_detail.dart';
import 'widgets/month_grid.dart';
import 'widgets/week_view.dart';

class CalendarScreen extends StatefulWidget {
  final String token;
  final Future<void> Function() onCleared;
  final VoidCallback onChangeToken;

  const CalendarScreen({
    super.key,
    required this.token,
    required this.onCleared,
    required this.onChangeToken,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarService _service;
  final _store = TokenStore();

  bool _monthView = true;
  late int _year;
  late int _month;
  late String _selected;
  CalendarResult? _data;
  CalendarResult? _weekData;
  final Set<String> _filters = {'class', 'activity', 'exam'};
  bool _includePublic = false;
  bool _loading = false;
  bool _offline = false;
  String? _error;
  int _requestId = 0; // 防止「翻页 / 切视图」时旧请求回来覆盖新结果

  @override
  void initState() {
    super.initState();
    _service = CalendarService(widget.token);
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _selected = todayIso();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  // ---------------------------------------------------------------- 加载

  Future<void> _load({bool week = false}) async {
    final myId = ++_requestId; // 每次加载都发号，只有最新一次能写回界面
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (week) {
        final r = await _service.week(_selected, includePublic: _includePublic);
        if (!mounted || myId != _requestId) return;
        setState(() => _weekData = r);
      } else {
        final start = gridStart(_year, _month);
        final end = addDays(start, 41);
        final r = await _service.range(start, end, includePublic: _includePublic);
        await _store.saveCache(r);
        if (!mounted || myId != _requestId) return;
        setState(() {
          _data = r;
          _offline = false;
        });
      }
    } on HduError catch (e) {
      if (!mounted || myId != _requestId) return;
      if (e.kind == 'auth') {
        _showTokenError('令牌已失效，请在设置里更换');
        return;
      }
      final cached = await _store.loadCache();
      if (cached != null && !week) {
        if (!mounted) return;
        setState(() {
          _data = cached;
          _offline = true;
        });
        _snack('离线中，显示上次保存的日历');
      } else {
        if (!mounted) return;
        setState(() => _error = e.userMessage());
        _snack(e.userMessage());
      }
    } catch (e) {
      if (!mounted || myId != _requestId) return;
      final cached = await _store.loadCache();
      if (cached != null && !week) {
        setState(() {
          _data = cached;
          _offline = true;
        });
        _snack('离线中，显示上次保存的日历');
      } else {
        setState(() => _error = '加载失败：$e');
        _snack('加载失败：$e');
      }
    } finally {
      if (mounted && myId == _requestId) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  void _showTokenError(String text) {
    _snack(text);
    _openSettings();
  }

  // ---------------------------------------------------------------- 交互

  void _switchView(bool month) {
    setState(() => _monthView = month);
    if (!month) _load(week: true);
  }

  void _shift(int delta) {
    setState(() {
      if (_monthView) {
        final next = DateTime(_year, _month + delta, 1);
        _year = next.year;
        _month = next.month;
      } else {
        _selected = addDays(_selected, delta * 7);
        final d = parseIso(_selected);
        _year = d.year;
        _month = d.month;
        _weekData = null;
      }
    });
    _load(week: !_monthView);
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _year = now.year;
      _month = now.month;
      _selected = todayIso();
      _weekData = null;
    });
    _load(week: !_monthView);
  }

  Future<void> _refresh() async {
    _service.clearCache();
    await _load(week: !_monthView);
    _snack('已刷新');
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SettingsSheet(
        token: widget.token,
        onChangeToken: widget.onChangeToken,
        onClear: () async {
          await widget.onCleared();
        },
      ),
    );
  }

  // ---------------------------------------------------------------- 渲染

  String get _subtitle {
    final term = (_monthView ? _data : _weekData)?.term;
    if (term == null) return '加载中…';
    final week = _monthView
        ? (term.weekNow > 0 ? term.weekNow : (_data?.thisWeek ?? 0))
        : (_weekData?.week ?? 0);
    return term.label + (week > 0 ? ' · 本周第 $week 教学周' : '');
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_offline)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        color: const Color(0xFFFFF4E5),
                        child: const Text('离线中 · 显示的是上次的数据',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF8A4B00))),
                      ),
                    _buildTopbar(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSegmented(),
                          _buildToolbar(),
                          _buildMonthTitle(),
                          const Legend(),
                          NoticesBar(notices: data?.notices ?? const []),
                          _buildBody(),
                          _buildFilters(),
                          const SizedBox(height: 14),
                          Text('数据来自杭电助手 · 令牌仅存本机',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          const SizedBox(height: 18),
                          Text('课程日历 · 本机版',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey.shade500)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopbar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('课程日历',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 5),
                  Text(_subtitle,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
            _iconButton(Icons.refresh, _refresh, '刷新'),
            const SizedBox(width: 8),
            _iconButton(Icons.settings_outlined, _openSettings, '设置'),
          ],
        ),
      );

  Widget _iconButton(IconData icon, VoidCallback onTap, String tooltip) => SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 17,
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: _loading ? null : onTap,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
      );

  Widget _buildSegmented() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF232733) : const Color(0xFFE9EBF1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segmentButton('月历', _monthView, () => _switchView(true)),
          _segmentButton('周历', !_monthView, () => _switchView(false)),
        ],
      ),
    );
  }

  Widget _segmentButton(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: active ? null : onTap,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Theme.of(context).colorScheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        ),
      );

  Widget _buildToolbar() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _iconButton(Icons.chevron_left, () => _shift(-1), '上一页'),
            SizedBox(
              height: 34,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _today,
                child: const Text('回到今天', style: TextStyle(fontSize: 13)),
              ),
            ),
            _iconButton(Icons.chevron_right, () => _shift(1), '下一页'),
          ],
        ),
      );

  Widget _buildMonthTitle() => Container(
        margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(width: 2, color: AppColors.navy)),
        ),
        child: Text('$_year 年 $_month 月',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      );

  Widget _buildBody() {
    if (_error != null && _data == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _load(), child: const Text('重试')),
          ],
        ),
      );
    }
    if (_data == null && _loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_monthView) {
      final weekData = _weekData;
      if (weekData == null) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v.abs() > 300) _shift(v > 0 ? -1 : 1);
        },
        child: WeekView(
          data: weekData,
          filters: _filters,
          onPickDay: (key) {
            final d = parseIso(key);
            setState(() {
              _monthView = true;
              _selected = key;
              _year = d.year;
              _month = d.month;
            });
            _load();
          },
        ),
      );
    }

    final data = _data;
    if (data == null) return const SizedBox.shrink();
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() > 300) _shift(v > 0 ? -1 : 1);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonthGrid(
            year: _year,
            month: _month,
            selected: _selected,
            days: data.days,
            filters: _filters,
            onTap: (d) {
              if (d.year != _year || d.month != _month) {
                setState(() {
                  _year = d.year;
                  _month = d.month;
                  _selected = isoOf(d);
                });
                _load();
                return;
              }
              setState(() => _selected = isoOf(d));
            },
          ),
          DayDetail(
            selected: _selected,
            term: data.term,
            days: data.days,
            filters: _filters,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('class', '上课'),
              ('activity', '二课'),
              ('exam', '考试'),
            ])
              _chip(
                label: item.$2,
                active: _filters.contains(item.$1),
                onTap: () => setState(() {
                  if (_filters.contains(item.$1)) {
                    _filters.remove(item.$1);
                  } else {
                    _filters.add(item.$1);
                  }
                }),
              ),
            _chip(
              label: '全部二课',
              active: _includePublic,
              ghost: true,
              onTap: () {
                setState(() => _includePublic = !_includePublic);
                _service.clearCache();
                _load(week: !_monthView);
              },
            ),
          ],
        ),
      );

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool ghost = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE8EFFF) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: ghost && !active
              ? Border.all(color: Colors.grey.shade400, style: BorderStyle.solid)
              : null,
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              color: active ? const Color(0xFF2F6FED) : null,
            )),
      ),
    );
  }
}
