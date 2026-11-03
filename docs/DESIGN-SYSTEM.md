# QShell 视觉系统规范

> 本文档描述应用**全部**外观实现：颜色 token、主题配置、自定义组件、背景系统、
> 路由转场、交互规范、已知限制与迁移模板。
>
> 目标：拿到这份文档 + 对应源码，可以在另一个 Flutter 项目里复刻同一套视觉，
> 或者交给 AI 照着实现。
>
> 版本对应：`v1.0.0+5` 之后的实现状态。

---

## 目录

- [0. 快速理解](#0-快速理解)
- [1. 设计原则](#1-设计原则)
- [2. 文件结构](#2-文件结构)
- [3. 主题架构](#3-主题架构)
- [4. Token 完整规格](#4-token-完整规格)
- [5. ThemeData 组件配置全表](#5-themedata-组件配置全表)
- [6. 背景系统](#6-背景系统)
- [7. 组件规格](#7-组件规格)
- [8. 路由与转场](#8-路由与转场)
- [9. 交互规范](#9-交互规范)
- [10. 已知限制](#10-已知限制)
- [11. 迁移模板](#11-迁移模板)
- [12. 调参速查](#12-调参速查)
- [13. 变更记录](#13-变更记录)

---

## 0. 快速理解

三个概念：

| 概念 | 含义 |
|---|---|
| **DesignLanguage** | 用户在设置里选的皮肤：`md3` / `glass` |
| **DesignSystem** | 皮肤的代码实现，负责产出 `ThemeData` |
| **AppTokens** | 从 `ThemeData` 里挂出来的语义 token，**页面只读这一层** |

数据流：

```
用户选皮肤 → DesignLanguage.resolve() → DesignSystem.buildTheme()
    → ThemeData（含 AppTokens 扩展）
        → 页面读 AppTokens.of(context).xxx
```

**页面代码禁止出现写死的颜色**，一律用 `tokens.xxx`。

---

## 1. 设计原则

1. **扁平 MD3 为基底**：没有拟物阴影、没有渐变描边、圆角统一。
2. **玻璃是叠加层，不是替代品**：`glass` 主题复用同一套 token 结构，只是取值不同。
3. **性能优先于极致效果**：卡片不做背景模糊（滚动会失效且掉帧），只有固定元素做。
4. **一屏内材质一致**：卡片、顶栏按钮、输入框、底栏用同一套透明度和描边。
5. **不做无谓的动效**：主题切换瞬时、页面转场 260ms、高亮滑动 260ms。

---

## 2. 文件结构

```
lib/
├── design/
│   ├── design_system.dart          # DesignSystem 接口 + tokensFromColorScheme()
│   ├── design_switcher.dart        # DesignLanguage 枚举与 resolve()
│   ├── tokens.dart                 # AppTokens（ThemeExtension）
│   ├── md3_design_system.dart      # MD3 皮肤
│   ├── glass_design_system.dart    # 玻璃皮肤 + GlassBackdrop（光斑/壁纸背景）
│   ├── glass_card.dart             # GlassCard（静态玻璃卡片）
│   ├── glass_edge_painter.dart     # GlassEdgePainter（厚度描边，卡片/底栏共用）
│   ├── liquid_glass.dart           # LiquidGlass（真实模糊容器）
│   ├── wallpaper_page.dart         # WallpaperPage（push 页面的不透明背景）
│   ├── instant_route.dart          # InstantPageRoute（滑动转场 + 自动包背景）
│   └── fade_transitions.dart       # 页面转场 builder
├── shell/
│   ├── app_shell.dart              # 底栏容器 + PageView + 返回处理
│   └── bottom_nav_bar.dart         # 玻璃胶囊底栏
└── state/
    ├── theme_controller.dart       # 全部外观设置的读写与持久化
    └── theme_scope.dart            # InheritedNotifier，页面取 controller
```

---

## 3. 主题架构

### 3.1 DesignSystem 接口

```dart
abstract interface class DesignSystem {
  String get id;      // 'md3' / 'glass'
  String get label;   // 设置页显示名

  ThemeData buildTheme({
    required Brightness brightness,
    required Color seed,
    ColorScheme? dynamicScheme,   // Material You 取色结果
  });
}
```

### 3.2 DesignLanguage 枚举

```dart
enum DesignLanguage {
  md3,
  glass;

  static DesignSystem resolve(DesignLanguage language) {
    switch (language) {
      case DesignLanguage.md3:   return const Md3DesignSystem();
      case DesignLanguage.glass: return const GlassDesignSystem();
    }
  }
}
```

### 3.3 AppTokens 与 glass 标志

`AppTokens` 是 `ThemeExtension`，额外带一个 `bool glass`。
页面用 `tokens.glass` 走分支，避免到处 import DesignSystem。

```dart
class AppTokens extends ThemeExtension<AppTokens> {
  // ... 全部字段见第 4 节
  final bool glass;   // 默认 false，只有 GlassDesignSystem 置 true
}
```

### 3.4 设置状态（ThemeController）

持久化 key 一览：

| key | 类型 | 含义 |
|---|---|---|
| `appearance.mode` | int | `ThemeModeChoice`：system / light / dark |
| `appearance.use_dynamic_color` | bool | Material You 取色开关 |
| `appearance.seed` | int | 强调色（ARGB32） |
| `appearance.design_language` | int | `DesignLanguage.index` |
| `appearance.glass_refraction` | bool | 底栏是否真实模糊 |
| `appearance.glass_all_cards` | bool | 卡片是否走玻璃质感 |
| `appearance.wallpaper` | String? | 壁纸文件路径 |
| `appearance.wallpaper_dim` | double | 壁纸压暗（0~0.8，默认 0.35） |
| `terminal.font_size` | double | 终端字号（10~22，默认 13） |
| `terminal.bg_color` | int? | 终端背景色 |
| `terminal.bg_image` | String? | 终端背景图 |
| `terminal.fg_color` | int? | 终端前景色 |

页面拿到 controller：

```dart
final controller = ThemeScope.of(context);          // 有断言
final maybe = ThemeScope.maybeOf(context);          // 可能为 null（测试场景）
```

---

## 4. Token 完整规格

### 4.1 字段清单

| 字段 | 用途 |
|---|---|
| `background` | 页面底色 |
| `surfaceCard` | 卡片 |
| `surfaceCardAlt` | 弹层 / 次级卡片 / 输入框 |
| `outline` | 强描边 |
| `outlineSoft` | 弱描边（卡片、分隔线） |
| `textPrimary` | 主文字 |
| `textSecondary` | 次要文字 |
| `textDisabled` | 禁用文字 / 占位 |
| `accent` | 强调色 |
| `onAccent` | 强调色上的文字 |
| `accentSoft` | 强调色容器（选中态底色） |
| `onAccentSoft` | 强调色容器上的文字 |
| `highlight` | 次强调（蜂窝卡等） |
| `onHighlight` | 次强调上的文字 |
| `success` | 成功 |
| `warning` | 警告 |
| `danger` | 危险 |
| `track` | 进度条轨道 |
| `glass` | 是否玻璃主题 |

### 4.2 MD3 取值

由 `tokensFromColorScheme(scheme)` 从 `ColorScheme` 映射：

| token | 来源 |
|---|---|
| `background` | `scheme.surface` |
| `surfaceCard` | `scheme.surfaceContainer` |
| `surfaceCardAlt` | `scheme.surfaceContainerHigh` |
| `outline` | `scheme.outline` |
| `outlineSoft` | `scheme.outlineVariant` |
| `textPrimary` | `scheme.onSurface` |
| `textSecondary` | `scheme.onSurfaceVariant` |
| `textDisabled` | `scheme.onSurface` @ 38% |
| `accent` | `scheme.primary` |
| `onAccent` | `scheme.onPrimary` |
| `accentSoft` | `scheme.primaryContainer` |
| `onAccentSoft` | `scheme.onPrimaryContainer` |
| `highlight` | `scheme.tertiary` |
| `onHighlight` | `scheme.onTertiary` |
| `success` | 日 `#1B7F45` / 夜 `#6DD58C` |
| `warning` | 日 `#9A6B00` / 夜 `#F3C969` |
| `danger` | `scheme.error` |
| `track` | `scheme.surfaceContainerHighest` |
| `glass` | `false` |

### 4.3 玻璃主题取值（日间 / 夜间）

| token | 日间 | 夜间 |
|---|---|---|
| `background` | `#E6EAF2` | `#0A0D12` |
| `surfaceCard` | 白 48% | 白 9% |
| `surfaceCardAlt` | 白 96% | `#1B2028` 94% |
| `outline` | 黑 10% | 白 12% |
| `outlineSoft` | 黑 6% | 白 8% |
| `textPrimary` | `onSurface` | `onSurface` |
| `textSecondary` | `onSurfaceVariant` | 同左 |
| `textDisabled` | `onSurface` 38% | 同左 |
| `accent` / `onAccent` | 来自 ColorScheme | 同左 |
| `accentSoft` / `onAccentSoft` | 来自 ColorScheme | 同左 |
| `highlight` / `onHighlight` | 来自 ColorScheme | 同左 |
| `success` | `#1B7F45` | `#6DD58C` |
| `warning` | `#9A6B00` | `#F3C969` |
| `danger` | `scheme.error` | 同左 |
| `track` | 白 50% | 白 16% |
| `glass` | `true` | `true` |

**注意**：描边颜色跟随亮度**反转**（浅底配深边、深底配浅边），否则浅色卡片上看不见边界。

### 4.4 生成代码

```dart
final scheme = dynamicScheme ??
    ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
final isDark = brightness == Brightness.dark;

final tokens = tokensFromColorScheme(scheme).copyWith(
  background: isDark ? const Color(0xFF0A0D12) : const Color(0xFFE6EAF2),
  surfaceCard: Colors.white.withValues(alpha: isDark ? 0.09 : 0.48),
  surfaceCardAlt: (isDark ? const Color(0xFF1B2028) : Colors.white)
      .withValues(alpha: isDark ? 0.94 : 0.96),
  outline: isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.10),
  outlineSoft: isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06),
  track: Colors.white.withValues(alpha: isDark ? 0.16 : 0.5),
  glass: true,
);
```

---

## 5. ThemeData 组件配置全表

玻璃主题 `buildTheme()` 里覆盖的组件（按出现顺序）。

### 5.1 基础

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  brightness: brightness,
  // 页面 Scaffold 必须透明，否则会盖住背景层（光斑/壁纸）
  scaffoldBackgroundColor: Colors.transparent,
  // Navigator 的默认底色也透明，避免 push 瞬间露底色
  canvasColor: Colors.transparent,
  visualDensity: VisualDensity.adaptivePlatformDensity,
  splashFactory: InkSparkle.splashFactory,
)
```

### 5.2 AppBar

```dart
appBarTheme: AppBarTheme(
  backgroundColor: Colors.transparent,
  foregroundColor: tokens.textPrimary,
  elevation: 0,
  scrolledUnderElevation: 0,
  centerTitle: false,
  titleTextStyle: base.textTheme.titleLarge?.copyWith(
    color: tokens.textPrimary,
    fontWeight: FontWeight.w600,
  ),
  // 状态栏/导航栏图标跟随主题反色
  systemOverlayStyle: (isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark)
      .copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ),
  // 让右上角圆形按钮的边缘与下方卡片对齐（卡片左右各 16）
  actionsPadding: const EdgeInsets.only(right: 10),
)
```

### 5.3 Card

```dart
cardTheme: CardThemeData(
  color: tokens.surfaceCard,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  margin: EdgeInsets.zero,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: BorderSide(color: tokens.outlineSoft, width: 1),
  ),
)
```

### 5.4 图标按钮

```dart
iconButtonTheme: IconButtonThemeData(
  style: IconButton.styleFrom(
    // 与卡片同档透明度
    backgroundColor: Colors.white.withValues(alpha: isDark ? 0.08 : 0.40),
    foregroundColor: tokens.textPrimary,
    shape: const CircleBorder(),
    minimumSize: const Size(40, 40),
    maximumSize: const Size(40, 40),
    padding: EdgeInsets.zero,
    iconSize: 20,
  ),
)
```

### 5.5 输入框

```dart
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: Colors.white.withValues(alpha: isDark ? 0.07 : 0.45),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: tokens.outlineSoft),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: tokens.outlineSoft),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: tokens.accent, width: 1.4),
  ),
  labelStyle: TextStyle(color: tokens.textSecondary),
  hintStyle: TextStyle(color: tokens.textDisabled, fontSize: 13),
)
```

### 5.6 按钮族

**FilledButton（主按钮）**

```dart
filledButtonTheme: FilledButtonThemeData(
  style: FilledButton.styleFrom(
    backgroundColor: tokens.accent.withValues(alpha: isDark ? 0.62 : 0.72),
    foregroundColor: tokens.onAccent,
    disabledBackgroundColor: tokens.accent.withValues(alpha: 0.20),
    disabledForegroundColor: tokens.onAccent.withValues(alpha: 0.6),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
      side: BorderSide(
        color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.35),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
)
```

**OutlinedButton**

```dart
outlinedButtonTheme: OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
    foregroundColor: tokens.textPrimary,
    side: BorderSide(color: tokens.outlineSoft),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
  ),
)
```

**TextButton / ElevatedButton**

```dart
textButtonTheme: TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: tokens.accent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
  ),
),
elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
    foregroundColor: tokens.textPrimary,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(100),
      side: BorderSide(color: tokens.outlineSoft),
    ),
  ),
),
```

### 5.7 分段按钮

```dart
segmentedButtonTheme: SegmentedButtonThemeData(
  style: ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return tokens.accent.withValues(alpha: isDark ? 0.30 : 0.22);
      }
      return Colors.white.withValues(alpha: isDark ? 0.05 : 0.32);
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return isDark ? Colors.white : tokens.accent;
      }
      return tokens.textSecondary;
    }),
    side: WidgetStatePropertyAll(BorderSide(color: tokens.outlineSoft)),
  ),
)
```

> 用 `ButtonStyle` + `WidgetStateProperty` 而不是 `styleFrom`，避免选中色被 MD3 默认态覆盖。

### 5.8 其余组件

```dart
// 开关
switchTheme: SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? tokens.onAccent : tokens.outline),
  trackColor: WidgetStateProperty.resolveWith((states) =>
      states.contains(WidgetState.selected) ? tokens.accent : tokens.track),
),

// 列表
listTileTheme: ListTileThemeData(
  selectedTileColor: tokens.accent.withValues(alpha: 0.12),
  iconColor: tokens.textSecondary,
),

// 展开项：背景透明，交给外层卡片
expansionTileTheme: ExpansionTileThemeData(
  backgroundColor: Colors.transparent,
  collapsedBackgroundColor: Colors.transparent,
  shape: const Border(),
  collapsedShape: const Border(),
  iconColor: tokens.accent,
  collapsedIconColor: tokens.textSecondary,
),

// 滑块
sliderTheme: SliderThemeData(
  activeTrackColor: tokens.accent.withValues(alpha: 0.85),
  inactiveTrackColor: Colors.white.withValues(alpha: isDark ? 0.10 : 0.42),
  thumbColor: tokens.accent,
  overlayColor: tokens.accent.withValues(alpha: 0.12),
),

// Chip
chipTheme: ChipThemeData(
  backgroundColor: Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
  side: BorderSide(color: tokens.outlineSoft),
  labelStyle: base.textTheme.labelMedium?.copyWith(color: tokens.textSecondary),
),

// 弹层（BottomSheet）
bottomSheetTheme: BottomSheetThemeData(
  backgroundColor: tokens.surfaceCardAlt,
  surfaceTintColor: Colors.transparent,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
),

// 对话框
dialogTheme: DialogThemeData(
  backgroundColor: tokens.surfaceCardAlt,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(26),
    side: BorderSide(color: tokens.outlineSoft),
  ),
),

// 提示条
snackBarTheme: SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor:
      (isDark ? const Color(0xFF1B2028) : Colors.white).withValues(alpha: 0.96),
  contentTextStyle:
      base.textTheme.bodyMedium?.copyWith(color: tokens.textPrimary),
),

// 分隔线
dividerTheme: DividerThemeData(
  color: tokens.outlineSoft,
  thickness: 1,
  space: 1,
),
```

---

## 6. 背景系统

### 6.1 层级总览

```
MaterialApp.builder 之外
└── Directionality
    └── Stack
        ├── RepaintBoundary(背景层)      ← 所有路由共享
        │     ├── 无壁纸：GlassBackdrop（光斑）
        │     └── 有壁纸：Image.file + 压暗
        └── MaterialApp
            └── Navigator
                ├── AppShell（4 个 Tab 页，Scaffold 透明）
                └── push 页面（WallpaperPage 自带背景）
```

### 6.2 全局背景层

```dart
Positioned.fill(
  child: RepaintBoundary(     // 转场时不重绘，避免闪
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
```

### 6.3 光斑（无壁纸时）

三个径向渐变圆，跟随强调色：

| 位置 | 尺寸 | 透明度 |
|---|---|---|
| `top: -110, left: -80` | 300 | `strength` |
| `top: 140, right: -90` | 260 | `strength × 0.7` |
| `bottom: -120, left: 40` | 320 | `strength × 0.55` |

`strength`：日间 **0.52**、夜间 **0.46**（日间底色浅，需要更强才能看出来）。

每个圆是 `RadialGradient(colors: [color, color.withValues(alpha: 0)], stops: [0, 1])`。

### 6.4 壁纸

选了壁纸后：

```dart
Stack(
  fit: StackFit.expand,
  children: [
    ColoredBox(color: tokens.background),
    Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 1080,          // 半分辨率，省内存
      gaplessPlayback: true,     // 重建时保留上一帧
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    ),
    ColoredBox(                  // 压暗，保证文字可读
      color: (isDark ? Colors.black : Colors.white)
          .withValues(alpha: wallpaperDim),
    ),
    child,
  ],
)
```

- `wallpaperDim` 由设置页滑块控制，范围 0~0.8，默认 **0.35**
- 壁纸文件**必须**用时间戳命名（`wallpaper_<ms>.img`），否则 `Image.file` 按路径缓存导致换图不生效

### 6.5 Tab 页 vs push 页

| | Tab 页（4 个） | push 页 |
|---|---|---|
| 背景来源 | 全局背景层透上来 | `WallpaperPage` 自己画 |
| Scaffold | 透明 | 透明（背景由 WallpaperPage 提供） |
| 光斑/壁纸 | 与全局一致 | **无壁纸时用 `GlassBackdrop`**，有壁纸时画同一张图 |
| 压暗 | 全局 `wallpaperDim` | `wallpaperDim + 0.06`（更深一档，形成"第二层"） |

```dart
// WallpaperPage 无壁纸分支（必须复用光斑，否则和主页割裂）
return GlassBackdrop(
  accent: tokens.accent,
  brightness: Theme.of(context).brightness,
  background: tokens.background,
  wallpaper: null,
  wallpaperDim: dim,
  child: child,
);
```

---

## 7. 组件规格

### 7.1 GlassCard（卡片）

**不做 BackdropFilter**——Flutter 的 backdrop 在滚动容器里会随内容平移短暂失效（模糊忽隐忽现），卡片是列表里最常见的元素，必须稳定。

```dart
ClipRRect(
  borderRadius: borderRadius,   // 默认 20
  child: Stack(
    children: [
      // 玻璃本体
      Positioned.fill(
        child: DecoratedBox(
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
        ),
      ),
      // 厚度描边
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: GlassEdgePainter(isDark: isDark, radius: 20),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        clipBehavior: clipBehavior,
        child: child,
      ),
    ],
  ),
)
```

**参数兼容**：`margin` / `elevation` / `color` / `shape` / `clipBehavior` / `borderRadius`，
与 Flutter 的 `Card` 对齐，方便批量替换。

**启用条件**：`refraction ?? ThemeScope.maybeOf(context)?.glassAllCards ?? false`
且 `tokens.glass == true`，否则退化成普通 `Card`。

### 7.2 GlassEdgePainter（厚度）

四层绘制，卡片与底栏共用：

| 层 | 参数 | 作用 |
|---|---|---|
| 1. 外圈亮线 | 宽 `1.2 × strength`，内缩 0.6，白 55%→18%（日）/ 22%→6%（夜）纵向渐变 | 玻璃外缘反光 |
| 2. 内圈暗线 | 宽 `1 × strength`，内缩 2.0，黑 5%（日）/ 22%（夜） | 制造"两层边"的厚度分界 |
| 3. 顶部高光 | 宽 `1.6 × strength`，内缩 1.0，白 55%→16%→0 纵向渐变（stops 0/0.32/0.62） | 光从上方打进来 |

`strength`：卡片 1.0，底栏 1.15。

**关键**：顶部高光**必须用渐变淡出**，不能用 `clipRect` 切一刀（会留下生硬断口）。

### 7.3 LiquidGlass（真实模糊容器）

用于固定元素（底栏），能安全用 `BackdropFilter`。

```dart
ClipRRect(
  borderRadius: borderRadius,
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),   // blur 默认 3
    child: Stack(
      children: [
        if (tint > 0)
          ColoredBox(color: (isDark ? Colors.black : Colors.white)
              .withValues(alpha: tint)),        // 默认 0.06
        // 厚度渐变（depth 默认 0.18）
        DecoratedBox(LinearGradient[白 0.55×depth, 透明, 黑 0.28×depth]),
        // 描边
        CustomPaint(GlassEdgePainter(isDark: isDark, radius: r, strength: 1.15)),
        child,
      ],
    ),
  ),
)
```

**不要**在 `filter` 里用 `ImageFilter.matrix`：放大采样在滚动/转场时会越界，
导致玻璃整块失效。

### 7.4 BottomNavBar（底栏）

| 参数 | 值 |
|---|---|
| 高度 | 66 |
| 左右内边距 `_pad` | 5 |
| 外层宽度 | 320（`SizedBox`） |
| 圆角 | 22 |
| 底盘颜色 | 日间 白 14% / 夜间 黑 16% |
| 高亮胶囊 | 日间 `accent` 13% / 夜间 白 10%，边框白 12% |
| 高亮圆角 | 16 |
| 拖动时放大 | 1.26 倍（`AnimatedScale` 180ms） |
| 高亮位移时长 | 260ms `easeOutCubic` |

**结构**（关键：内容层不裁剪，高亮才能溢出）：

```dart
SizedBox(
  height: 66,
  child: Stack(
    clipBehavior: Clip.none,        // ← 允许溢出
    children: [
      Positioned.fill(               // 底层：裁剪做模糊
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: LiquidGlass(...) 或 BackdropFilter(...),
        ),
      ),
      Positioned.fill(               // 描边
        child: IgnorePointer(
          child: CustomPaint(
            painter: GlassEdgePainter(radius: 22, strength: 1.15),
          ),
        ),
      ),
      Positioned.fill(child: gesture),  // 内容层：高亮 + 按钮
    ],
  ),
)
```

**对齐规则**：高亮宽度 `= (总宽 - 2×pad) / count`，
所以按钮行必须包在 `Padding(horizontal: _pad)` 里，否则越靠右偏得越多。

**内容结构**：

```dart
LayoutBuilder(builder: (context, c) {
  final itemWidth = (c.maxWidth - _pad * 2) / count;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      AnimatedPositioned(            // 高亮胶囊
        duration: 260ms,
        left: _pad + itemWidth * index,
        top: _pad, bottom: _pad, width: itemWidth,
        child: AnimatedScale(
          scale: _dragging ? 1.26 : 1.0,
          duration: 180ms,
          child: DecoratedBox(...),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: _pad),
        child: Row(children: [ for (...) Expanded(按钮) ]),
      ),
    ],
  );
})
```

### 7.5 工具页模板组件

`lib/widgets/tool_layout.dart` 里的四个：

| 组件 | 规格 |
|---|---|
| `ToolCard` | 卡片容器，内部 `Column` + 16px padding |
| `ToolField` | 带标签的输入框，用主题的 `inputDecorationTheme` |
| `ToolPrimaryButton` | **全宽**、**纯文字**（不用 `.icon`，否则文字偏右） |
| `ToolNotice` | 提示 / 错误行（图标 + 文字） |
| `ToolSectionTitle` | 结果区小标题 |

`ToolPrimaryButton` 的 loading 处理：

```dart
FilledButton(
  // 不能设 null：禁用态文字只有 60% 不透明度，会看不清
  onPressed: loading ? () {} : onPressed,
  child: loading
      ? Row(居中: [16×16 转圈, 8 间距, Text(loadingLabel)])
      : Text(label),
)
```

### 7.6 下拉刷新

```dart
RefreshIndicator(
  color: tokens.accent,
  backgroundColor:
      isDark ? const Color(0xFF2A2F38) : Colors.white.withValues(alpha: 0.92),
  strokeWidth: 2.2,
  displacement: 32,
  onRefresh: ...,
  child: ...,
)
```

### 7.7 结果列表

工具页的逐条结果（Ping 的每一包、Traceroute 的每一跳）**必须包进 `ToolCard`**，
不能裸排在页面上，否则和其他的卡片视觉割裂。

---

## 8. 路由与转场

### 8.1 InstantPageRoute

```dart
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  }) : super(
          opaque: true,                              // 声明不透明
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, a, b) =>
              WallpaperPage(child: builder(context)),   // 自动包背景
          transitionsBuilder: (context, animation, secondary, child) {
            final incoming = Tween<Offset>(begin: Offset(1, 0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation);
            final outgoing = Tween<Offset>(begin: Offset.zero, end: Offset(-0.22, 0))
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(secondary);
            return SlideTransition(
              position: outgoing,
              child: SlideTransition(position: incoming, child: child),
            );
          },
        );
}
```

迁移成本：全项目 `MaterialPageRoute(` → `InstantPageRoute(`，`builder` 签名一致。

### 8.2 应用级结构

```dart
class _QShellAppState extends State<QShellApp> with WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});   // 背景层在 MaterialApp 外，必须主动重建
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 部分 ROM 不回调上面的方法，回前台补一次
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Widget build(context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller, widget.localeController]),
    builder: (context, _) {
      // MaterialApp 之外没有 MediaQuery，用 platformBrightness 推断
      final platformDark = View.of(context).platformDispatcher
          .platformBrightness == Brightness.dark;
      final isDark = switch (widget.controller.themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => platformDark,
      };
      final theme = design.buildTheme(brightness: isDark, seed: seed);
      final tokens = theme.extension<AppTokens>();

      return ThemeScope(
        controller: widget.controller,
        child: LocaleScope(
          child: AppStringsScope(
            child: Directionality(          // ← MaterialApp 外必须有
              textDirection: TextDirection.ltr,
              child: Stack(children: [背景层, MaterialApp(...)]),
            ),
          ),
        ),
      );
    },
  );
}
```

---

## 9. 交互规范

| 交互 | 行为 | 参数 |
|---|---|---|
| 切换设计语言 | 瞬时，无渐变 | `themeAnimationDuration: Duration.zero` |
| 页面 push/back | 新页右侧滑入，旧页左移视差 | 260ms / 220ms，视差 22% |
| 底栏点击 | `animateToPage` 平滑切页 | 280ms `easeOutCubic` |
| 底栏拖动 | **水平拖动**（非长按），跟手切页 | `jumpToPage`（瞬时） |
| 底栏拖动高亮 | 放大到 1.26 倍并溢出 | `AnimatedScale` 180ms |
| 长按列表项 | 弹出操作菜单 | 系统默认 |
| 返回键 | 不在首页 → 回首页；在首页 → 提示「再按一次退出」 | SnackBar |

**拖动必须用 `jumpToPage`**：`animateToPage` 会在拖动每跨一格时起一段 280ms 动画，
叠加起来就是幻灯片级别的卡顿。

---

## 10. 已知限制

### 10.1 弹层无法真实模糊

`showModalBottomSheet` 是独立路由，Flutter 在它和下层之间插入 `RepaintBoundary`，
`BackdropFilter` 跨不过 route 边界，模糊完全不生效。

实测三版：

| 方案 | 结果 |
|---|---|
| 半透明 + BackdropFilter | 模糊不生效 |
| 半透明无模糊（alpha 0.97） | 下层文字透上来，发脏 |
| 不透明 + 描边（当前方案） | 干净，无透视 |

真模糊只能改用 `OverlayEntry` 自绘（滑入动画、遮罩点击、下滑拖拽、返回键拦截，
约 200~300 行），收益与成本不成正比，**当前不采用**。

### 10.2 卡片不能做背景模糊

滚动容器内 `BackdropFilter` 会随内容平移失效。卡片改用静态玻璃质感（见 7.1）。

### 10.3 转场与透明页面的冲突

页面若透明，转场时新旧两页同屏 → 内容重影。
解法：push 页面用 `WallpaperPage` 自带不透明背景（见 6.5）。

### 10.4 RepaintBoundary 破坏 backdrop

`PageView` 的 children 不要包 `RepaintBoundary`，否则页面被隔离成独立图层，
`BackdropFilter` 采样不到背景。

### 10.5 ImageFilter.shader 不可用

`shaders/liquid_glass.frag` 保留在仓库里但**未启用**：部分机型上
`ImageFilter.shader` 的背景采样返回白色，玻璃变成奶白块。
Impeller 修复后可重新启用。

### 10.6 系统日夜切换需要主动重建

背景层在 `MaterialApp` 之外，`MaterialApp` 的 `themeMode: system` 会自动跟随，
但背景层不会——必须用 `WidgetsBindingObserver` 在亮度变化时 `setState`。
否则会出现「主页还是日间、二级页面已是夜间」。

---

## 11. 迁移模板

### 11.1 最小文件集

```
design/
├── design_system.dart
├── design_switcher.dart
├── tokens.dart
├── md3_design_system.dart
├── glass_design_system.dart
├── glass_card.dart
├── glass_edge_painter.dart
├── liquid_glass.dart
├── wallpaper_page.dart
└── instant_route.dart
state/
├── theme_controller.dart
└── theme_scope.dart
```

### 11.2 接入步骤

1. 复制上面两组文件
2. `main.dart` 改成 `Directionality > Stack[背景层, MaterialApp]`
3. 主题统一走 `DesignLanguage.resolve(...).buildTheme(...)`，
   把原来手写的 `ColorScheme.fromSeed`、`appBarTheme` 搬进对应 DesignSystem
4. 若项目已有自己的外观设置（高亮色/壁纸/明暗），让 `ThemeController`
   **委托读取**而不是各存一份，避免两个来源打架
5. `MaterialPageRoute` → `InstantPageRoute`（全项目替换）
6. `Card` → `GlassCard`（非玻璃主题下自动退化为 `Card`）
7. 自定义 AppBar 里按 `tokens.glass` 分支
8. Android `windowBackground` 对齐主题底色，关闭预测返回

### 11.3 Android 侧配置

```xml
<!-- values/styles.xml -->
<item name="android:windowBackground">#FFE6EAF2</item>

<!-- values-night/styles.xml -->
<item name="android:windowBackground">#FF0A0D12</item>
```

```xml
<!-- AndroidManifest.xml -->
<application android:enableOnBackInvokedCallback="false" ...>
```

---

## 12. 调参速查

### 想更透

| 位置 | 参数 | 当前值 | 方向 |
|---|---|---|---|
| `glass_card.dart` | 卡片底色 | 0.40 / 0.075 | 调小 |
| `bottom_nav_bar.dart` | 底盘底色 | 0.14 / 0.16 | 调小 |
| `liquid_glass.dart` | `tint` | 0.06 | 调小到 0 |
| 设置页 | 壁纸压暗 | 0.35 | 调小 |

### 想更有厚度

| 位置 | 参数 | 当前值 |
|---|---|---|
| `glass_edge_painter.dart` | 各层 alpha | 见 7.2 |
| `glass_card.dart` | 渐变 stops | 0 / 0.48 / 1 |
| `liquid_glass.dart` | `depth` | 0.18 |

### 性能

- 玻璃卡片数量多会掉帧：设置里给了「卡片折射」开关，默认关
- 静态玻璃卡片几乎无额外开销
- 真实模糊只用在一处（底栏）

---

## 13. 变更记录

| 版本 | 外观相关变更 |
|---|---|
| `+1` | MD3 基底、可切换设计语言骨架 |
| `+3` | 液态玻璃第一版：光斑、半透明卡片、模糊底栏 |
| `+4` | 玻璃细节打磨：透明度、描边、图标按钮、搜索框、下拉刷新、卡片折射开关 |
| `+5` | 修主按钮 loading 态、MD3 下误显示玻璃开关、结果列表裸排 |
| 未发版 | 二级页面背景改回光斑、系统日夜切换跟随、弹层方案回滚 |
