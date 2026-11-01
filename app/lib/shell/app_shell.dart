
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import 'bottom_nav_bar.dart';
import '../design/tokens.dart';
import '../state/theme_scope.dart';
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

  /// 拖动切页：瞬时跳转，不跑动画。
  /// 用 animateToPage 的话，拖动每跨一格都会起一段 280ms 动画，
  /// 叠加起来就是一两帧的卡顿。
  void _preview(int index) {
    if (index == _index) return;
    _index = index;
    _controller.jumpToPage(index);
    setState(() {});
  }

  void _go(int index) {
    if (index == _index) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// 页面主体（玻璃主题下会被背景光斑包一层）
  Widget _sheetBody() {
    return ActivePage(
      index: _index,
      child: PageView(
        controller: _controller,
        onPageChanged: (value) => setState(() => _index = value),
        physics: const ClampingScrollPhysics(),
        children: [
          // 不包 RepaintBoundary：它会把页面隔离成独立图层，
          // 导致 BackdropFilter 采样不到背景，玻璃模糊直接消失。
          for (final page in _pages) page,
        ],
      ),
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
        body: _sheetBody(),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          // 用 Row 而不是 Align：Align 会撑满 bottomNavigationBar 的高度，
          // 导致底栏垂直居中跑到屏幕中间。Row 高度跟随内容。
          child: Row(
            children: [
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: BottomNavBar(
                  index: _index,
                  labels: labels,
                  iconsOutlined: iconsOutlined,
                  iconsFilled: iconsFilled,
                  onSelect: _go,
                  onPreview: _preview,
                  tokens: tokens,
                  glassRefraction:
                      ThemeScope.of(context).glassRefraction,
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
