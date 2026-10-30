import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../i18n/app_strings.dart';
import '../pages/files/files_page.dart';
import '../pages/home/home_page.dart';
import '../pages/sessions/sessions_page.dart';
import '../pages/tools/tools_page.dart';

/// 应用外壳：悬浮底栏 + 4 个常驻页面。
///
/// 页面用 PageView 承载：切换是横向滑动（不是淡入淡出），
/// 每个页面都保活，来回切不会重新加载数据。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final PageController _controller = PageController();

  static const _pages = <Widget>[
    _KeepAlive(child: HomePage()),
    _KeepAlive(child: SessionsPage()),
    _KeepAlive(child: ToolsPage()),
    _KeepAlive(child: FilesPage()),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index == _index) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final strings = AppStrings.of(context);
    final labels = <String>[
      strings.tabHome,
      strings.tabSessions,
      strings.tabTools,
      strings.tabFiles,
    ];
    const iconsOutlined = <IconData>[
      Icons.dashboard_outlined,
      Icons.terminal_outlined,
      Icons.handyman_outlined,
      Icons.folder_outlined,
    ];
    const iconsFilled = <IconData>[
      Icons.dashboard_rounded,
      Icons.terminal_rounded,
      Icons.handyman_rounded,
      Icons.folder_rounded,
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        extendBody: true,
        body: ActivePage(
          index: _index,
          child: PageView(
            controller: _controller,
            onPageChanged: (value) => setState(() => _index = value),
            physics: const ClampingScrollPhysics(),
            children: [
              for (final page in _pages) RepaintBoundary(child: page),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          // 用 Row 而不是 Align：Align 会撑满 bottomNavigationBar 的高度，
          // 导致底栏垂直居中跑到屏幕中间。Row 高度跟随内容。
          child: Row(
            children: [
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: _BottomBar(
                  index: _index,
                  labels: labels,
                  iconsOutlined: iconsOutlined,
                  iconsFilled: iconsFilled,
                  onSelect: _go,
                  tokens: tokens,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 返回手势：不在首页先回首页；在首页第一次提示「再按一次退出」，第二次才退。
  DateTime? _lastBackAt;

  Future<void> _handleBack() async {
    if (_index != 0) {
      _go(0);
      return;
    }
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('再按一次返回退出'),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

/// 自定义悬浮底栏：滑块式高亮背景 + 小号标签，比 M3 NavigationBar 更收敛。
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.labels,
    required this.iconsOutlined,
    required this.iconsFilled,
    required this.onSelect,
    required this.tokens,
  });

  final int index;
  final List<String> labels;
  final List<IconData> iconsOutlined;
  final List<IconData> iconsFilled;
  final ValueChanged<int> onSelect;
  final AppTokens tokens;

  static const double _height = 66;
  static const double _pad = 5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = labels.length;

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: tokens.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.outlineSoft),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - _pad * 2) / count;
          return Stack(
            children: [
              // 高亮滑块：跟随选中项平移
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: _pad + itemWidth * index,
                top: _pad,
                bottom: _pad,
                width: itemWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: i == index ? 1.0 : 0.94,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              child: Icon(
                                i == index
                                    ? iconsFilled[i]
                                    : iconsOutlined[i],
                                size: 24,
                                color: i == index
                                    ? tokens.onAccentSoft
                                    : tokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: text.labelSmall!.copyWith(
                                fontSize: 10,
                                height: 1.1,
                                color: i == index
                                    ? tokens.onAccentSoft
                                    : tokens.textSecondary,
                                fontWeight: i == index
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              child: Text(labels[i], maxLines: 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// PageView 默认不保活：包一层让每页状态常驻。
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 当前可见的页索引：各页面据此暂停/恢复自己的后台刷新。
class ActivePage extends InheritedWidget {
  const ActivePage({super.key, required this.index, required super.child});

  final int index;

  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActivePage>()?.index;

  @override
  bool updateShouldNotify(ActivePage oldWidget) => oldWidget.index != index;
}