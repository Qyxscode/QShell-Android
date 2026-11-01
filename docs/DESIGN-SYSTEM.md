# QShell 设计系统说明

本文档描述项目里「可切换设计语言 + 液态玻璃」的完整实现，可作为其他 Flutter 项目复用的参考。

---

## 一、总体架构

### 1.1 三层结构

```
DesignSystem（接口）           ← 一套皮肤的实现
    ├── Md3DesignSystem        ← Material Design 3
    └── GlassDesignSystem      ← 液态玻璃

AppTokens（ThemeExtension）    ← 语义 token，页面只读这一层
    ├── background / surfaceCard / outline / textPrimary / accent …
    └── glass（bool）           ← 当前是否玻璃主题

DesignLanguage（enum）          ← 用户在设置里切换
    └── DesignLanguage.resolve(language) → DesignSystem
```

页面代码**只允许引用 `AppTokens` 的语义名**（如 `tokens.surfaceCard`），不写死颜色。
切换设计语言时，只要换 `DesignSystem` 实现，页面一行都不用改。

### 1.2 关键文件

| 文件 | 作用 |
|---|---|
| `lib/design/design_system.dart` | `DesignSystem` 接口 + `tokensFromColorScheme()` |
| `lib/design/design_switcher.dart` | `DesignLanguage` 枚举与解析 |
| `lib/design/tokens.dart` | `AppTokens`（ThemeExtension，含 `glass` 标志） |
| `lib/design/md3_design_system.dart` | MD3 皮肤 |
| `lib/design/glass_design_system.dart` | 玻璃皮肤 + `GlassBackdrop`（背景层） |
| `lib/design/glass_card.dart` | `GlassCard`（卡片玻璃质感） |
| `lib/design/glass_edge_painter.dart` | `GlassEdgePainter`（厚度描边，卡片/底栏共用） |
| `lib/design/liquid_glass.dart` | `LiquidGlass`（真实背景模糊，用于固定元素） |
| `lib/design/wallpaper_page.dart` | `WallpaperPage`（push 页面的不透明背景） |
| `lib/design/instant_route.dart` | `InstantPageRoute`（滑动转场 + 自动包 WallpaperPage） |
| `lib/design/fade_transitions.dart` | 页面转场 builder |
| `lib/shell/bottom_nav_bar.dart` | 底栏（玻璃胶囊 + 拖动切页） |
| `lib/state/theme_controller.dart` | 所有外观设置的持久化 |

---

## 二、AppTokens 语义表

```dart
class AppTokens extends ThemeExtension<AppTokens> {
  final Color background;      // 页面底色
  final Color surfaceCard;     // 卡片
  final Color surfaceCardAlt;  // 弹层 / 次级卡片 / 输入框
  final Color outline;         // 强描边
  final Color outlineSoft;     // 弱描边
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color accent;          // 强调色
  final Color onAccent;
  final Color accentSoft;      // 强调色容器
  final Color onAccentSoft;
  final Color highlight;       // 次要强调（如蜂窝卡图标）
  final Color onHighlight;
  final Color success;
  final Color warning;
  final Color danger;
  final Color track;           // 进度条轨道
  final bool glass;            // ← 玻璃主题标志（新增）
}
```

**`glass` 的作用**：页面/组件用它判断「要不要走玻璃分支」，避免到处 import DesignSystem。

---

## 三、液态玻璃的五层结构

### 3.1 背景层（全局唯一）

`GlassBackdrop` 由 `app.dart` 的 `MaterialApp.builder` 之外的 `Stack` 提供，
**位于所有路由之下**：

```dart
Stack(
  children: [
    Positioned.fill(
      child: RepaintBoundary(
        child: tokens.glass
            ? GlassBackdrop(
                accent: tokens.accent,
                brightness: isDark ? Brightness.dark : Brightness.light,
                background: tokens.background,
                wallpaper: controller.wallpaper,
                wallpaperDim: controller.wallpaperDim,
                child: const SizedBox.expand(),
              )
            : ColoredBox(color: tokens.background),
      ),
    ),
    Positioned.fill(child: MaterialApp(...)),
  ],
)
```

**两种模式**：

| 情况 | 内容 |
|---|---|
| 没有壁纸 | 底色 + 3 个径向渐变色斑（日间强度 0.52 / 夜间 0.46） |
| 有壁纸 | 底色 + `Image.file(cover, cacheWidth: 1080, gaplessPlayback: true)` + 压暗遮罩 |

### 3.2 Tab 页（透明）

主页 / 会话 / 工具 / 文件 四个 Tab 的 `Scaffold` **背景透明**
（玻璃主题下 `scaffoldBackgroundColor: Colors.transparent`），
让全局背景层透上来。

Tab 之间用 `PageView` 切换，**没有路由转场**，所以不存在重影问题。

### 3.3 push 页面（自带壁纸，不透明）

`InstantPageRoute` 会自动把页面包进 `WallpaperPage`：

```dart
pageBuilder: (context, animation, secondaryAnimation) =>
    WallpaperPage(child: builder(context)),
```

`WallpaperPage` 画一张**同样的壁纸**并压暗（比主页深 6%）：

```dart
Stack(
  fit: StackFit.expand,
  children: [
    ColoredBox(color: tokens.background),
    Image.file(File(path), fit: BoxFit.cover, cacheWidth: 1080,
        gaplessPlayback: true),
    ColoredBox(color: (isDark ? Colors.black : Colors.white)
        .withValues(alpha: (dim + 0.06).clamp(0.0, 0.92))),
    child,
  ],
)
```

**为什么必须不透明**：页面透明 + 路由转场 = 新旧两个路由同时绘制 → 内容重影。
让每个 push 页面自己画壁纸，转场时就能完整盖住旧页面。

### 3.4 卡片（静态玻璃，不做模糊）

`GlassCard` 用**半透明底 + 渐变 + 描边**模拟玻璃，**不用 `BackdropFilter`**：

```dart
DecoratedBox(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: isDark ? 0.075 : 0.40),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: isDark ? 0.05 : 0.20),
        Colors.white.withValues(alpha: 0),
        Colors.black.withValues(alpha: isDark ? 0.07 : 0.025),
      ],
      stops: const [0.0, 0.48, 1.0],
    ),
  ),
)
```

`GlassCard` 兼容 `Card` 的常用参数（`margin` / `elevation` / `color` / `shape` / `clipBehavior`），
全项目通过批量替换从 `Card(` 迁过来，由 `ThemeScope.maybeOf(context)?.glassAllCards` 控制是否启用。

### 3.5 底栏（真实模糊）

底栏是固定元素（不滚动），可以用 `BackdropFilter`：

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(22),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white)
            .withValues(alpha: isDark ? 0.16 : 0.14),
      ),
    ),
  ),
)
```

---

## 四、厚度感的实现（GlassEdgePainter）

玻璃"看起来有厚度"靠四层描边，卡片和底栏共用：

```dart
class GlassEdgePainter extends CustomPainter {
  void paint(canvas, size) {
    // 1) 外圈亮线：顶部白 55% → 底部白 18% 的渐变描边
    // 2) 内圈暗线：内缩 2px，黑色 5%（制造"玻璃有厚度"的分界）
    // 3) 顶部高光：沿圆角的描边，用 LinearGradient 从上往下淡出到透明
    //    （不要用 clipRect 裁剪，否则会留下生硬的断口）
  }
}
```

**关键点**：
- 顶部高光**必须用渐变淡出**，不能用 `clipRect` 切一刀
- 内圈暗线是厚度感的主要来源（"两层边"的效果）

---

## 五、底栏交互（BottomNavBar）

| 参数 | 值 |
|---|---|
| 高度 | 66 |
| 左右内边距 | 5 |
| 宽度 | 320（外层 `SizedBox`） |
| 圆角 | 22 |
| 高亮放大 | 拖动时 1.26 倍（`AnimatedScale` 180ms） |

**对齐要点**：高亮块宽度 = `(总宽 - 2*pad) / count`，
所以按钮行必须放在同样的 `Padding(horizontal: pad)` 里，否则会错位。

**拖动逻辑**：

```dart
onHorizontalDragStart  → setState(_dragging = true)    // 高亮放大
onHorizontalDragUpdate → 按手指横向位置算目标页，jumpToPage
onHorizontalDragEnd    → setState(_dragging = false)
```

- 用**水平拖动**而不是长按（长按要等 500ms，太迟钝）
- 拖动中必须 `jumpToPage`，用 `animateToPage` 会每跨一格起一段动画 → 卡成幻灯片
- 点击仍走 `animateToPage`（平滑过渡）

---

## 六、踩过的坑（重要）

| 现象 | 原因 | 解决 |
|---|---|---|
| **页面转场内容重影** | 页面透明，转场时新旧路由同屏 | 用 `WallpaperPage` 让 push 页面自带不透明壁纸 |
| **滚动列表时模糊消失** | `BackdropFilter` 在滚动容器里采样失效（Flutter 固有） | 卡片不用 backdrop，改静态玻璃 |
| **`ImageFilter.matrix` 滚动失效** | 放大后的采样区域越界 | 去掉 matrix，只用 blur |
| **`ImageFilter.shader` 背景采样返回白色** | 部分机型上 sampler 绑定失败 | 弃用 shader 方案 |
| **换壁纸要重启** | `Image.file` 按路径缓存 | 文件名带时间戳 `wallpaper_<ms>.img` |
| **页面背景被纯色盖住** | 每个页面的 `Scaffold` 有自己的不透明底色 | 玻璃主题下 `scaffoldBackgroundColor: Colors.transparent` |
| **切主题白屏** | `body` 的 widget 结构随主题变化 | 用固定的 `Stack` 结构，只在里面换内容 |
| **切主题闪烁** | 主题渐变过渡露出中间态 | `themeAnimationDuration: Duration.zero` |
| **状态栏图标不反色** | 没配 `SystemUiOverlayStyle` | `MaterialApp.builder` 里包 `AnnotatedRegion` |
| **push 页面白闪** | 背景层在 `MaterialApp` 内，随路由重建 | 背景层提到 `MaterialApp` 外的 `Stack` |
| **RepaintBoundary 导致模糊失效** | 它把页面隔离成独立图层 | PageView 的 children 不要包 RepaintBoundary |

---

## 七、调参指南

### 7.1 想更透

| 参数 | 位置 | 方向 |
|---|---|---|
| 卡片底色 `0.40 / 0.075` | `glass_card.dart` | 调小 |
| 底栏底色 `0.14 / 0.16` | `bottom_nav_bar.dart` | 调小 |
| `LiquidGlass.tint` | `liquid_glass.dart` | 调小到 0 |
| 壁纸压暗 `wallpaperDim` | 设置页滑块（默认 0.35） | 调小 |

### 7.2 想更明显（玻璃更"厚"）

| 参数 | 位置 | 方向 |
|---|---|---|
| `GlassEdgePainter` 的 alpha | `glass_edge_painter.dart` | 调大 |
| 渐变 stops | `glass_card.dart` | 加大顶部高光 |
| `depth` | `LiquidGlass` / 底栏 | 调大 |

### 7.3 性能

- 玻璃卡片数量多会掉帧（每张一次绘制），设置里给了开关
- 不做 `BackdropFilter` 的卡片几乎没有额外开销
- 真实模糊只用在底栏

---

## 八、复用到新项目的清单

最小可复用集合：

```
design/
├── design_system.dart       # 接口
├── design_switcher.dart     # 枚举
├── tokens.dart              # AppTokens（含 glass）
├── md3_design_system.dart
├── glass_design_system.dart # 含 GlassBackdrop
├── glass_card.dart
├── glass_edge_painter.dart
├── liquid_glass.dart
├── wallpaper_page.dart
└── instant_route.dart
state/
├── theme_controller.dart    # 外观设置持久化
└── theme_scope.dart         # InheritedNotifier
```

`app.dart` 的关键结构：

```dart
AnimatedBuilder(
  animation: controller,
  builder: (context, _) => ThemeScope(
    controller: controller,
    child: Builder(builder: (innerContext) {
      // MediaQuery 之外，用 platformBrightness 推断明暗
      final isDark = ...;
      final tokens = design.buildTheme(brightness: isDark, seed: seed)
          .extension<AppTokens>();
      return Directionality(
        textDirection: TextDirection.ltr,   // ← 必须有，MaterialApp 之外没有
        child: Stack(children: [
          背景层,
          Positioned.fill(child: MaterialApp(...)),
        ]),
      );
    }),
  ),
)
```

**注意**：`MaterialApp` 之外没有 `Directionality` / `MediaQuery`，
自己包 `Stack`/`Directionality` 时要补上，否则首帧黑屏。
