# 液态玻璃设计系统（Liquid Glass Design System）

> 本文档是 **QClash（com.qclash.app）当前实现的完整视觉规范**，由 QShell 期文档与
> QClash 现状合并整理而成，是唯一版本（历史旧的 QShell 内容已并入，不再单独保留）。
>
> 目标：拿到这份文档 + `lib/design/` 源码，可以在任意 Flutter 项目里复刻同一套视觉，
> 或者交给 AI 照着重写。
>
> 参考源码：`anyproxy_client/lib/design/`（约 18 个文件）。

---

## 目录

- [0. 快速开始（新项目 6 步）](#0-快速开始新项目-6-步)
- [1. 设计原则](#1-设计原则)
- [2. 架构与数据流](#2-架构与数据流)
- [3. Token 规格](#3-token-规格)
- [4. 层级与透明度](#4-层级与透明度)
- [5. 圆角 / 间距 / 字号](#5-圆角--间距--字号)
- [6. 主题配置全表](#6-主题配置全表)
- [7. 背景系统](#7-背景系统)
- [8. 组件规范](#8-组件规范)
- [9. 浮层体系](#9-浮层体系)
- [10. 动效规范](#10-动效规范)
- [11. 交互规范](#11-交互规范)
- [12. 已知限制与陷阱](#12-已知限制与陷阱)
- [13. 迁移与落地](#13-迁移与落地)
- [14. 调参速查](#14-调参速查)
- [15. 变更记录](#15-变更记录)

---

## 0. 快速开始（新项目 6 步）

1. 建 `lib/design/`，按依赖顺序复制：
   `tokens.dart` → `design_system.dart` → `glass_design_system.dart` + `md3_design_system.dart`
   → `glass_card.dart` / `glass_edge_painter.dart` → `glass_surface.dart`
   → `glass_switch.dart` / `glass_slider.dart` → `segment_style.dart`
   → `bottom_nav_bar.dart` → `page_shell.dart` / `wallpaper_page.dart` / `instant_route.dart`
   → `expandable_section.dart` / `copyable_text.dart`
   → `glass_sheet.dart` / `glass_menu.dart` / `glass_dialog.dart` / `glass_toast.dart` / `glass_select.dart`。
2. `MaterialApp` 的 `theme` + `darkTheme` 都来自 `GlassDesignSystem.buildTheme`。
3. 根组件外包 `ThemeScope`（`InheritedNotifier` 包 `ThemeController`），
   管理 seed 色、壁纸、`glassRefraction`、`glassAllCards`。
4. 页面 `Scaffold` 必须 `backgroundColor: Colors.transparent`，背景由 `WallpaperPage` / `GlassBackdrop` 统一铺。
5. 所有 push 页面用 `InstantPageRoute`（自动套 `WallpaperPage`）。
6. 页面里**只读 `AppTokens`**，不写死颜色；卡片只用 `GlassCard`，浮层只用第 9 节的 5 个入口。

依赖：`provider`（或自写 InheritedWidget）、`shared_preferences`（外观持久化）。
不需要第三方 UI 库。

---

## 1. 设计原则

| # | 原则 | 说明 |
|---|---|---|
| 1 | **玻璃是层次，不是装饰** | 卡片 / 内嵌块 / 标签是三级不同亮度的"玻璃片"，靠 alpha 分层，不用阴影 |
| 2 | **选中 = 更亮的一层** | 半透明高光 + 强调色描边，禁止实心色块 + 白字 |
| 3 | **描边与背景反色** | 深色卡片配浅描边，浅色卡片配深描边，否则边界消失 |
| 4 | **浮层才有模糊** | 滚动列表里的卡片不用 `BackdropFilter`（采样失效、掉帧）；模糊只给底栏和浮层 |
| 5 | **颜色只从 token 取** | 页面代码不允许出现 `Color(0x…)`，圆角/颜色都走 `AppTokens` |
| 6 | **动效克制、有弹性** | 位移/缩放可以过冲，透明度绝不 |
| 7 | **无分割线** | 列表用间距与按压高亮区分 |
| 8 | **性能优先于极致效果** | 卡片用静态玻璃；真实模糊只出现在固定元素与浮层 |

---

## 2. 架构与数据流

```
用户选皮肤 → DesignLanguage.resolve() → DesignSystem.buildTheme()
    → ThemeData（含 AppTokens 扩展）
        → 页面读 AppTokens.of(context).xxx
```

**页面代码禁止出现写死的颜色**，一律 `tokens.xxx`。

### 2.1 三个概念

| 概念 | 含义 |
|---|---|
| `DesignLanguage` | 用户在设置里选的皮肤：`md3` / `glass` |
| `DesignSystem` | 皮肤实现，产出 `ThemeData` |
| `AppTokens` | 挂在 `ThemeData.extensions` 上的语义 token，页面只读这一层 |

### 2.2 DesignSystem 接口

```dart
abstract interface class DesignSystem {
  String get id;      // 'md3' / 'glass'
  String get label;   // 设置页显示名
  ThemeData buildTheme({
    required Brightness brightness,
    required Color seed,
    ColorScheme? dynamicScheme,   // Material You 取色
  });
}

enum DesignLanguage {
  md3,
  glass;

  static DesignSystem resolve(DesignLanguage l) => switch (l) {
        DesignLanguage.md3 => const Md3DesignSystem(),
        DesignLanguage.glass => const GlassDesignSystem(),
      };
}
```

### 2.3 ThemeController（外观状态）

| 持久化 key | 类型 | 含义 |
|---|---|---|
| `appearance.mode` | int | system / light / dark |
| `appearance.use_dynamic_color` | bool | Material You 取色 |
| `appearance.seed` | int (ARGB32) | 强调色 |
| `appearance.design_language` | int | `DesignLanguage.index` |
| `appearance.glass_refraction` | bool | 底栏是否真实模糊/折射 |
| `appearance.glass_all_cards` | bool | 卡片是否走玻璃质感（默认 true） |
| `appearance.wallpaper` | String? | 壁纸路径 |
| `appearance.wallpaper_dim` | double | 压暗 0~0.9，默认 0.35 |

```dart
final controller = ThemeScope.of(context);        // 有断言
final maybe = ThemeScope.maybeOf(context);        // 可能为 null（测试）
```

---

## 3. Token 规格

### 3.1 字段清单

| 字段 | 用途 |
|---|---|
| `background` | 页面底色 |
| `surfaceCard` | 卡片 |
| `surfaceCardAlt` | 内嵌块 / 弹层底 |
| `outline` | 强描边（选中边、焦点边） |
| `outlineSoft` | 弱描边（卡片边、分隔） |
| `textPrimary / textSecondary / textDisabled` | 三级文字 |
| `accent / onAccent` | 强调色及其前景 |
| `accentSoft / onAccentSoft` | 强调色容器 |
| `highlight / onHighlight` | 第三色 |
| `success / warning / danger` | 状态色 |
| `track` | 关闭态轨道 / 进度轨道 |
| `glass` | 是否玻璃主题 |
| `surfaceFloating`（getter） | 弹层实色底 = `surfaceCardAlt` 去 alpha |
| `cardRadius = 16`（static const） | 卡片圆角全局唯一来源 |

### 3.2 玻璃主题取值

| token | 深色 | 浅色 |
|---|---|---|
| background | `#12161D` | `#E6EAF2` |
| surfaceCard | 白 12% | 白 48% |
| surfaceCardAlt | `#1B2028` 94% | 白 96% |
| outline | 白 12% | 黑 10% |
| outlineSoft | 白 8% | 黑 6% |
| track | 白 16% | 黑 50% |
| textPrimary | `scheme.onSurface` | 同左 |
| textSecondary | `scheme.onSurfaceVariant` | 同左 |
| textDisabled | `onSurface` 38% | 同左 |
| accent | `scheme.primary` | 同左 |
| success | `#6DD58C` | `#1B7F45` |
| warning | `#F3C969` | `#9A6B00` |
| danger | `scheme.error` | 同左 |
| glass | `true` | `true` |

> 深色背景取 `#12161D` 而不是纯黑：纯黑下玻璃卡片完全没有层次。

### 3.3 MD3 主题取值

```dart
AppTokens tokensFromColorScheme(ColorScheme scheme) => AppTokens(
      background: scheme.surface,
      surfaceCard: scheme.surfaceContainer,
      surfaceCardAlt: scheme.surfaceContainerHigh,
      outline: scheme.outline,
      outlineSoft: scheme.outlineVariant,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textDisabled: scheme.onSurface.withValues(alpha: 0.38),
      accent: scheme.primary,
      onAccent: scheme.onPrimary,
      accentSoft: scheme.primaryContainer,
      onAccentSoft: scheme.onPrimaryContainer,
      highlight: scheme.tertiary,
      onHighlight: scheme.onTertiary,
      success: isDark ? const Color(0xFF6DD58C) : const Color(0xFF1B7F45),
      warning: isDark ? const Color(0xFFF3C969) : const Color(0xFF9A6B00),
      danger: scheme.error,
      track: scheme.surfaceContainerHighest,
    );
```

### 3.4 生成代码（玻璃）

```dart
final scheme = dynamicScheme ??
    ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
final base = tokensFromColorScheme(scheme);
final tokens = base.copyWith(
  background: isDark ? const Color(0xFF12161D) : const Color(0xFFE6EAF2),
  surfaceCard: Colors.white.withValues(alpha: isDark ? 0.12 : 0.48),
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

## 4. 层级与透明度

| 层级 | 组件 | 底色 | 圆角 | 描边 |
|---|---|---|---|---|
| L1 卡片 | `GlassCard` | `surfaceCard`（白 12% / 48%） | 16 | 渐变 + 多层描边，无阴影 |
| L2 内嵌块 | 卡片内分组块、地址块、统计块、列表项 | `surfaceCardAlt` 22% | 12 | **无描边** |
| L3 标签 | 状态 / 类型标签 | 强调色 14% | 5~6 | 强调色 25%（玻璃） |
| 浮层 | 弹窗 / 菜单 / toast / 对话框 | `GlassSurface`：`surfaceFloating` 36~56% | 12/16/20/24 | 厚度描边 |

**L2 不要描边**：L1 已有一圈玻璃边缘，L2 再描边就是"卡片里贴卡片"，页面会碎。

**L3 不要反色**：标签禁止「实心 accent + 白字」；正确的是同色系文字 +
低透明度底，像光透过彩色玻璃。

**选中态**：

| 主题 | 选中底色 | 描边 | 文字 |
|---|---|---|---|
| glass 深色 | 白 22% | accent 75%，1.2px | textPrimary |
| glass 浅色 | accent 26% | accent 75%，1.2px | textPrimary |
| glass 未选 | 白 4%（深）/ 28%（浅） | outlineSoft 1px | textSecondary |
| md3 | accentSoft（实心） | outlineSoft | onAccentSoft |

约束：选中/未选亮度差 **≥ 4 倍**（22% vs 4%），否则户外不可辨；
所有"一组选一个"的控件统一走 `segmentStyle(context, tokens)`，**禁止页面内联 ButtonStyle**。

---

## 5. 圆角 / 间距 / 字号

### 5.1 圆角

| 元素 | 值 |
|---|---|
| 卡片（全局常量） | **16** |
| 内嵌块 | 12 |
| 输入框 / 分段按钮 / 选择框 | 12~14 |
| 标签 | 5~6 |
| 底部弹窗 / 悬浮面板 | 24 |
| 确认框 | 20 |
| 菜单 / toast | 16 / 12 |
| 底栏胶囊 / 高亮 | 22 / 16 |
| 图标按钮 | 40×40 圆形 |

### 5.2 间距

- 页面左右：主 Tab 16~20，二级页 20
- 卡片内边距：16~20（紧凑列表 12）
- 卡片间距：12~16
- 列表底部留白：110（给玻璃底栏让位）
- 图标与文字：8~10

### 5.3 字号

| 用途 | 字号 | 字重 |
|---|---|---|
| 二级页标题 | 19 | bold |
| 区块 / 卡片标题 | 15~15.5 | bold |
| 列表行标题 | 13~13.5 | normal / 600 |
| 正文 / 说明 | 12~13（行高 1.35~1.4） | normal |
| 次级说明 | 11~11.5 | normal |
| 标签 | 9~11 | 600~bold |
| 仪表盘数字 | 26 | w700 + `tabularFigures` |
| 速率单位 | 11 | w600 |

数字类统一 `fontFeatures: [FontFeature.tabularFigures()]`，避免每秒刷新抖动。

---

## 6. 主题配置全表

### 6.1 基础

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  brightness: brightness,
  // 页面 Scaffold 必须透明，否则盖住背景层
  scaffoldBackgroundColor: Colors.transparent,
  // Navigator 默认底色也透明，避免 push 瞬间露底色
  canvasColor: Colors.transparent,
  visualDensity: VisualDensity.adaptivePlatformDensity,
  splashFactory: InkSparkle.splashFactory,
)
```

### 6.2 AppBar

透明底、`elevation: 0`、`scrolledUnderElevation: 0`、`centerTitle: false`、
标题 19 w600、`actionsPadding: right 10`（让右上圆钮与卡片边缘对齐）、
系统状态栏/导航栏透明且图标跟随明暗反色。

### 6.3 Card（仅非玻璃回退）

```dart
cardTheme: CardThemeData(
  color: tokens.surfaceCard,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  margin: EdgeInsets.zero,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppTokens.cardRadius),
    side: BorderSide(color: tokens.outlineSoft, width: 1),
  ),
)
```

### 6.4 图标按钮

玻璃主题下裸图标不成体系，统一 40×40 圆形 + 白 8%/40% 底：

```dart
iconButtonTheme: IconButtonThemeData(
  style: IconButton.styleFrom(
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

### 6.5 输入框

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

### 6.6 按钮族

**FilledButton（主按钮 = 彩色玻璃）**

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

**OutlinedButton**：白 8%/42% 底 + `outlineSoft` 边 + 胶囊圆角。
**TextButton**：前景 accent，胶囊圆角。
**ElevatedButton**：白 12%/55% 底、`elevation: 0`、`outlineSoft` 边（不用 M3 阴影）。

### 6.7 分段按钮（主题级）

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

> 用 `ButtonStyle` + `WidgetStateProperty` 而非 `styleFrom`，
> 避免选中色被 MD3 默认态覆盖。
> 页面级仍应使用 `segmentStyle(context, tokens)`（见 8.6），保持一致。

### 6.8 其余组件

| 组件 | 配置要点 |
|---|---|
| `listTileTheme` | `selectedTileColor: accent 12%`、`iconColor: textSecondary` |
| `expansionTileTheme` | 背景/收起背景透明、`shape`/`collapsedShape: Border()`（避免自带边框） |
| `chipTheme` | 白 8%/42% 底 + `outlineSoft` 边 + `textSecondary` 标签 |
| `sliderTheme` | 轨道 accent 85%、inactive 白 10%/42%、thumb 白、overlay accent 12% |
| `dividerTheme` | `outlineSoft`、1px、`space: 1`（列表不用，仅表单分隔） |
| `tooltipTheme` | 半透明 `surfaceFloating`（玻璃 90%）+ `outlineSoft` 描边 + 圆角 8 + 11.5 字 + 等待 450ms |
| `bottomSheetTheme` / `dialogTheme` / `snackBarTheme` / `popupMenuTheme` | **刻意留空**：这些系统组件已全部由自绘浮层替代，配置留着会误导 |

---

## 7. 背景系统

### 7.1 层级总览

```
MaterialApp 之外
└── Directionality
    └── Stack
        ├── RepaintBoundary(背景层)        ← 所有路由共享
        │     ├── 无壁纸：GlassBackdrop（光斑）
        │     └── 有壁纸：Image.file + 压暗
        └── MaterialApp
            └── Navigator
                ├── AppShell（Tab 页，Scaffold 透明）
                └── push 页面（WallpaperPage 自带背景）
```

背景层必须包 `RepaintBoundary`：转场时不重绘，避免闪屏。

### 7.2 光斑（无壁纸）

| 位置 | 尺寸 | 透明度 |
|---|---|---|
| `top: -110, left: -80` | 300 | `strength` |
| `top: 140, right: -90` | 260 | `strength × 0.7` |
| `bottom: -120, left: 40` | 320 | `strength × 0.55` |

`strength`：QClash 深色 **0.68** / 浅色 **0.58**（浅色底亮，需要更强才看得出来）。
每个光斑是 `RadialGradient(colors: [color, color 透明], stops: [0, 1])`。

### 7.3 壁纸

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
    ColoredBox(
      color: (isDark ? Colors.black : Colors.white)
          .withValues(alpha: wallpaperDim),
    ),
    child,
  ],
)
```

- `wallpaperDim` 0~0.9，默认 0.35
- 壁纸文件**必须**用时间戳命名（`wallpaper_<ms>.img`），
  否则 `Image.file` 按路径缓存，换图不生效

### 7.4 Tab 页 vs push 页

| | Tab 页 | push 页 |
|---|---|---|
| 背景来源 | 全局背景层透上来 | `WallpaperPage` 自己画 |
| Scaffold | 透明 | 透明（背景由 WallpaperPage 提供） |
| 光斑/壁纸 | 与全局一致 | 无壁纸时 `GlassBackdrop`，有壁纸时同一张图 |
| 压暗 | 全局 `wallpaperDim` | `wallpaperDim + 0.06`（更深一档，形成"第二层"） |

**没有背景光斑时，玻璃卡片就是一块灰板。** 背景是风格的组成部分。

---

## 8. 组件规范

### 8.1 GlassCard

**不做 BackdropFilter**——滚动容器里 backdrop 会随内容平移失效（模糊忽隐忽现），
卡片是列表里最常见的元素，必须稳定。

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(AppTokens.cardRadius),
  child: Stack(
    children: [
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
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: GlassEdgePainter(
              isDark: isDark,
              radius: AppTokens.cardRadius,
            ),
          ),
        ),
      ),
      Material(color: Colors.transparent, clipBehavior: clipBehavior, child: child),
    ],
  ),
)
```

参数与 `Card` 对齐：`margin / elevation / color / shape / clipBehavior / borderRadius`。

启用条件：`refraction ?? ThemeScope.maybeOf(context)?.glassAllCards ?? true`
且 `tokens.glass == true`，否则退化为普通 `Card`。

**卡片内点击**：`InkWell(borderRadius: BorderRadius.circular(AppTokens.cardRadius))`。

### 8.2 GlassEdgePainter（厚度）

三层绘制，卡片与底栏共用：

| 层 | 参数 | 作用 |
|---|---|---|
| 外圈亮线 | 宽 `1.2 × strength`，内缩 0.6，白 55%→18%（日）/ 22%→6%（夜）纵向渐变 | 外缘反光 |
| 内圈暗线 | 宽 `1 × strength`，内缩 2.0，黑 5%（日）/ 22%（夜） | "两层边"的厚度分界 |
| 顶部高光 | 宽 `1.6 × strength`，内缩 1.0，白 55%→16%→0（stops 0/0.32/0.62） | 光从上方打进来 |

`strength`：卡片 1.0，底栏 1.15。
**顶部高光必须用渐变淡出**，不能用 `clipRect` 硬切（会留下生硬断口）。

### 8.3 LiquidGlass（真实模糊容器）

用于固定元素（底栏）：

```dart
ClipRRect(
  borderRadius: borderRadius,      // 默认 22
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),  // 默认 3
    child: Stack(children: [
      if (tint > 0) ColoredBox(...),                          // 默认 0.06
      DecoratedBox(LinearGradient[白 0.55×depth, 透明, 黑 0.28×depth]), // depth 0.16
      CustomPaint(GlassEdgePainter(isDark: isDark, radius: r, strength: 1.15)),
      child,
    ]),
  ),
)
```

**不要**在 filter 里用 `ImageFilter.matrix`（放大采样在滚动/转场时越界，
玻璃整块失效）。`ImageFilter.shader` 也不可用（部分机型返回白色）。

### 8.4 GlassSurface（浮层玻璃）

- `BackdropFilter` 模糊 16~24
- 底色渐变（顶部 +6% 高光）+ `GlassEdgePainter` 厚度描边
- 阴影画在裁剪层**外面**（否则被 `ClipRRect` 裁掉）
- 参数：`borderRadius / blur / opacity / padding / showEdge / shadow`
- 非玻璃主题自动 `opacity = 1`（实色）

**禁止在包含 `BackdropFilter` 的子树外套 `Opacity` / `FadeTransition`**：
离屏层会导致模糊采样失效（"框先出来、毛玻璃延迟出现"）。

### 8.5 GlassSwitch / GlassSwitchTile

| 属性 | 值 |
|---|---|
| 尺寸 | 48 × 28（紧凑 42 × 24），滑块 = height - 6 |
| 轨道（开） | accent 72% / 禁用 30% |
| 轨道（关） | 白 10%（深）/ 黑 10%（浅），几乎融进卡片 |
| 描边 | 开：accent 85%；关：outlineSoft |
| 光晕（开） | accent 26%，blur 10 |
| 滑块 | 开 `onAccent`，关白色 |
| 过渡 | 轨道 220ms；按下 120ms；支持拖动（≥10px 才切换） |

`GlassSwitchTile`：标题 14 + 副标题 11.5（行高 1.35）+ 右侧开关，上下 padding 8；
禁用时标题 `textDisabled`。

### 8.6 GlassSlider + segmentStyle

- `GlassSlider`：高 28、轨道 5、滑块 18；玻璃主题滑块白色、轨道 accent 85%；
  手动 `GestureDetector` 拖拽（不是 Material Slider）
- `segmentStyle(context, tokens)`：圆角 12、最小高度 34；
  选中 深白 22% / 浅 accent 26% + accent 45% 描边，文字 `textPrimary`；
  未选 白 4% / 28%，文字 `textSecondary`；
  4 段以上标签缩 2 字 + `softWrap: false`，全名放 `tooltip`

### 8.7 GlassBottomNavBar

| 参数 | 值 |
|---|---|
| 高度 | 66 |
| 内边距 `_pad` | 5 |
| 布局 | 左右各 16 撑满整行 |
| 圆角 | 22 |
| 模糊 | sigma 16 |
| 底盘 | 日 白 14% / 夜 黑 16% |
| 高亮胶囊 | 日 accent 13% / 夜 白 10%，边框白 12% |
| 高亮圆角 | 16 |
| 高亮位移 | 260ms `easeOutCubic` |
| 拖动放大 | 1.26 倍（`AnimatedScale` 180ms） |
| 图标 / 标签 | 20 / 10.5 |

**结构关键**：内容层不裁剪（`Stack(clipBehavior: Clip.none)`），高亮才能溢出；
底层用 `ClipRRect + BackdropFilter` 做模糊。

**对齐公式**：高亮宽度 `= (总宽 - 2×pad) / count`，
按钮行必须包在 `Padding(horizontal: _pad)` 里，否则越靠右偏得越多。

**切页**：点击用 `animateToPage`（280ms `easeOutCubic`）；
**拖动必须 `jumpToPage`**（`animateToPage` 每跨一格起一段动画，叠加成幻灯片卡顿）。

### 8.8 PageShell / InstantPageRoute

- `PageShell`：透明 Scaffold + 透明 AppBar（返回图标 20、标题 19 bold、
  `centerTitle: false`）+ `SafeArea(top: false)`
- `InstantPageRoute`：`opaque: true` + `WallpaperPage` 铺底；
  260ms 进 / 220ms 出，`easeOutCubic`；新页右侧滑入，旧页视差左移 22%

```dart
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({required WidgetBuilder builder, super.settings,
      super.maintainState, super.fullscreenDialog})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, a, b) => WallpaperPage(child: builder(context)),
          transitionsBuilder: (context, animation, secondary, child) {
            final incoming = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(animation);
            final outgoing = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.22, 0))
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

### 8.9 ExpandableSection / CopyableText

- `ExpandableSection`：320ms `easeInOutCubic`；`SizeTransition` 高度 +
  Fade（延迟 25%）+ 8px 上移；箭头 `AnimatedRotation(turns: expanded ? 0.5 : 0)` 200ms
- `CopyableText`：替代 `SelectableText`（高频列表会抢滚动）；长按复制 + toast

### 8.10 状态标签 / 内嵌块

- 标签：强调色 14% 底 + 25% 描边 + 圆角 6 + 11px w600；
  非玻璃主题为实色 accent 底 + `onAccentSoft` 文字
- 内嵌块：`surfaceCardAlt` 22%（玻璃）/ 实色（MD3），圆角 12，**无描边**

### 8.11 连接按钮（四态主开关）

| 状态 | 表现 |
|---|---|
| 未连接 | accent 渐变圆 62 + play 图标 |
| 连接中 | 圆收缩到 50 + 外圈自绘旋转弧（84° 主弧 + 20% 拖尾），1000ms/圈 |
| 已连接 | success 渐变圆 62 + power + 呼吸光晕 2200ms + 外圈细环 76 |
| 按需暂停 | warning 圆 + pause，静止 |

外框 84；尺寸 `AnimatedContainer` 480ms `easeOutBack`；
按下 0.90（110ms `easeOut`）→ 松手 `elasticOut` 420ms 回弹；
图标 `AnimatedSwitcher` 320ms（Fade `easeOut`，Scale `elasticOut`）；
连上瞬间 620ms 高光斜扫（白色渐变条裁进圆内）。

### 8.12 搜索框 / 图标按钮

- 搜索框：`textAlignVertical: center` + `isDense: true` +
  `prefixIconConstraints: BoxConstraints(minWidth: 36)`，圆角 12~14
- 图标按钮：玻璃主题统一 40×40 圆形白 8%/40% 底；
  行内小按钮用 `BoxConstraints.tightFor(width: 28, height: 28)` 避免撑高行

### 8.13 工具页模板（可选）

| 组件 | 规格 |
|---|---|
| `ToolCard` | 卡片容器，内部 `Column` + 16 padding |
| `ToolField` | 带标签输入框，走主题 `inputDecorationTheme` |
| `ToolPrimaryButton` | 全宽、纯文字（不用 `.icon`，否则文字偏右） |
| `ToolNotice` | 提示/错误行（图标 + 文字） |
| `ToolSectionTitle` | 结果区小标题 |

主按钮 loading 态：`onPressed` 不能设 null（禁用态文字只有 60% 不透明度），
改为空回调 + 内容换成「16×16 转圈 + 8 间距 + 文案」。

下拉刷新：

```dart
RefreshIndicator(
  color: tokens.accent,
  backgroundColor: isDark ? const Color(0xFF2A2F38)
      : Colors.white.withValues(alpha: 0.92),
  strokeWidth: 2.2,
  displacement: 32,
  onRefresh: ...,
  child: ...,
)
```

结果列表（Ping 每一包、Traceroute 每一跳）必须包进 `ToolCard`，不能裸排。

---

## 9. 浮层体系

浮层 = `GlassSurface` 外壳 + 自定义动画。
**不使用系统 SnackBar / AlertDialog / PopupMenu / Dropdown。**

### 9.1 showGlassToast

```dart
showGlassToast(context, '文案', tone: GlassToastTone.success);
```

- 位置 `left/right 16`、`bottom 96 + safeArea`；圆角 12、模糊 16、
  `opacity 0.38`、内边距 14
- 260ms 上滑 35% + 淡入；停留 2s；点击立即关；同一时刻只留一条
- tone：`info` / `success` / `error` 决定图标与颜色

### 9.2 showGlassMenu

```dart
final value = await showGlassMenu<String>(
  context: context,
  anchorKey: _addButtonKey,      // 或 anchorRect: 点击位置
  width: 200,
  items: const [
    GlassMenuItem(value: 'a', label: '订阅链接', icon: Icons.rss_feed_rounded),
  ],
);
```

- 锚点 `GlobalKey` 或 `Rect`；右对齐、贴边夹紧、空间不足翻到上方
- 圆角 16、模糊 16、`opacity 0.36`、内边距 6；项高 44、圆角 10、按压 accent 12%
- 190ms：scale `0.86 → 1`（`easeOutBack`），**缩放原点指向锚点中心**；
  **不做淡入**（避免 BackdropFilter 失效）；收起 `easeOutCubic`
- 支持 `icon / subtitle / selected`；选择器场景选中项右侧 ✓ + 文字 accent，
  不要额外加圆点图标（圆点 + 勾重复）

### 9.3 showGlassSheet

- 悬浮式：左右 10、底部 `10 + 手势条 + 键盘`；四角圆角 24
  （贴屏幕底会被屏幕物理圆角裁断描边）
- 模糊 18、`opacity 0.46`、barrier `black 0.32`
- 自绘拖拽条 36×4（`showDragHandle: false`）
- 结构：标题 17 bold → 内容 `SingleChildScrollView` → 底部按钮行

### 9.4 showGlassConfirm

圆角 20、模糊 18、`opacity 0.46`、barrier `black 0.30`；
标题 15.5 bold（危险操作 danger 色）+ 正文 13 + 等宽按钮；返回 `bool`。

### 9.5 GlassSelectField

点击弹出 `showGlassMenu`（宽度 = 锚点宽度），显示当前值 + `expand_more`；
选中项右侧 ✓ + 文字 accent。

---

## 10. 动效规范

| 场景 | 时长 | 曲线 |
|---|---|---|
| 页面转场（进/出） | 260 / 220ms | `easeOutCubic` |
| 底栏点击切页 / 拖动 | 280ms / `jumpToPage` | `easeOutCubic` / — |
| 折叠卡片 | 320ms | `easeInOutCubic` + fade 延迟 25% |
| 开关轨道 / 按下 | 220 / 120ms | 默认 |
| 菜单弹出 / 收起 | 190ms | `easeOutBack` / `easeOutCubic` |
| toast 进出 | 260ms | `easeOutCubic` / `easeInCubic` |
| 底栏选中 / 文字 / 按压 | 260 / 220 / 180ms | 默认 |
| 连接按钮尺寸 / 回弹 / 高光 | 480 / 420 / 620ms | `easeOutBack` / `elasticOut` / 线性 |
| 呼吸光晕 | 2200ms 往复 | 线性 |
| 状态点呼吸 | 1600ms 循环 | 线性 |
| 图标替换 | 280~320ms | Fade `easeOut` + Scale 0.7→1（`easeOutBack`） |

**硬性规则**

1. `FadeTransition.opacity` 只能接 `[0,1]` 曲线，**禁止 `easeOutBack` / `elasticOut`**
   （越界断言红块，报错指向 `curves.dart`，很难定位）。
2. 过冲曲线只能给 `scale` / `offset`。
3. `reverseCurve` 用 easeOut 系（先快后慢）；用 easeIn 会"先慢慢动、最后一帧突然跳完"。
4. 状态切换一定要有过渡：`Icon(cond ? A : B)` 是瞬间替换，必须 `AnimatedSwitcher`。

---

## 11. 交互规范

| 交互 | 行为 | 参数 |
|---|---|---|
| 切换设计语言 | 瞬时，无渐变 | `themeAnimationDuration: Duration.zero` |
| 页面 push/back | 新页右侧滑入，旧页视差 | 260 / 220ms，22% |
| 底栏点击 | `animateToPage` | 280ms `easeOutCubic` |
| 底栏拖动 | 水平拖动跟手 | `jumpToPage`（瞬时） |
| 底栏拖动高亮 | 放大 1.26 倍并溢出 | `AnimatedScale` 180ms |
| 列表按压 | accent 12%（按下）/ 6%（hover） | 圆角 10，左右内缩 2px |
| 卡片内按压 | `InkWell.borderRadius` = 卡片圆角（16） | — |
| 返回键 | 不在首页 → 回首页；首页 → 再按一次退出 | toast |
| 危险操作 | `showGlassConfirm(danger: true)` | — |

**列表禁止 `Divider`**：分割线 + 满宽灰块叠在一起，边界全是直角，会显脏。

**运行中状态变化**（连接 / 断开 / 切节点 / 暂停）**不弹提示**，
由按钮、徽章、通知栏表达；只有失败、需用户操作、下载结果才弹 toast。

每秒刷新的数字用等宽数字 + `FittedBox(scaleDown)`，禁止换行。

---

## 12. 已知限制与陷阱

### 12.1 弹层模糊的边界

- `showModalBottomSheet` 在部分 Flutter 版本中跨 route 的 `RepaintBoundary`
  会让 `BackdropFilter` 失效（QShell 时期的结论）；
- QClash 当前版本实测**底部弹窗内 BackdropFilter 生效**（barrier 调浅后可见）；
- 若要绝对可控，改用 `OverlayEntry` 自绘（菜单 / toast 就是这么做的），
  代价是滑入动画、遮罩点击、下滑拖拽、返回键拦截都要自己写（约 200~300 行）；
- **无论哪种实现，`Opacity` 包住 `BackdropFilter` 都会让模糊失效。**

### 12.2 卡片不能做背景模糊

滚动容器内 `BackdropFilter` 会随内容平移失效；卡片改用静态玻璃（见 8.1）。

### 12.3 转场与透明页面

页面若透明，转场时新旧两页同屏 → 内容重影。
解法：push 页面用 `WallpaperPage` 自带不透明背景（见 7.4）。

### 12.4 RepaintBoundary 破坏 backdrop

`PageView` 的 children 不要包 `RepaintBoundary`，否则页面被隔离成独立图层，
`BackdropFilter` 采样不到背景。

### 12.5 ImageFilter.shader 不可用

`shaders/liquid_glass.frag` 保留但**未启用**：部分机型上 `ImageFilter.shader`
的背景采样返回白色，玻璃变成奶白块。Impeller 修复后可再启用。

### 12.6 系统日夜切换需要主动重建

背景层在 `MaterialApp` 之外，`themeMode: system` 只让 `MaterialApp` 跟随，
背景层不会。必须用 `WidgetsBindingObserver`：

```dart
@override
void didChangePlatformBrightness() {
  if (mounted) setState(() {});   // 背景层在 MaterialApp 外，必须主动重建
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  // 部分 ROM 不回调上面的方法，回前台补一次
  if (state == AppLifecycleState.resumed && mounted) setState(() {});
}
```

否则会出现「主页还是日间、二级页面已是夜间」。

### 12.7 输入框与表单（4 条）

| # | 陷阱 | 修法 |
|---|---|---|
| 1 | 主题 `filled: true` 在自定义淡底里叠出直角灰罩 | 该 `InputDecoration` 显式 `filled: false` |
| 2 | `border: InputBorder.none` 关不掉边框 | `border` / `enabledBorder` / `focusedBorder` 三处同时设 |
| 3 | 固定高容器里文字偏上 | `textAlignVertical: center` + `isDense: true` + `prefixIconConstraints` |
| 4 | `AlertDialog` 宽度由 `IntrinsicWidth` 决定 | 改 `showGlassSheet` / `showGlassConfirm` |

### 12.8 其他陷阱总表

| # | 陷阱 | 现象 | 修法 |
|---|---|---|---|
| 1 | `IconButton` 默认 48 点击区 | 行高被撑到 50+ | `BoxConstraints.tightFor(28, 28)` + `padding: zero` |
| 2 | 固定宽度底栏 | 宽屏上歪 | 左右各 16 撑满 |
| 3 | `SelectableText` 高频列表 | 抢滚动、清空选区 | `CopyableText` |
| 4 | 每秒 `notifyListeners` | 后台 Tab 全重建 | 仅当前 Tab 可见时广播 |
| 5 | 拖拽条叠两条 | 顶部双重手柄 | 显式 `showDragHandle: false` + 自绘 |
| 6 | 4 段以上分段按钮长文案 | 文字折两行 | 缩 2 字 + `softWrap: false` |
| 7 | 弹层半透明无模糊 | 下层文字透上来 | 必须 `BackdropFilter`；非玻璃回实色 |
| 8 | 弹层贴屏幕底 | 左右描边被屏幕圆角裁断 | 悬浮式：四周留 10dp、底部让出手势条 |
| 9 | `Opacity` 包住 `BackdropFilter` | 毛玻璃延迟出现 | 模糊子树只做 scale/位移 |
| 10 | 卡片里用 `BackdropFilter` | 滚动时闪烁/失效 | 卡片用半透明 + 渐变模拟 |
| 11 | 多套圆角（16/20/22） | 视觉不统一 | 统一 `AppTokens.cardRadius` |
| 12 | barrier 太黑（0.5+） | 模糊后发灰 | 0.30~0.32 |
| 13 | 深色卡片配黑描边 | 边界消失 | 描边与背景反色 |
| 14 | 没有背景光斑 | 卡片是灰板 | 必须有 `GlassBackdrop` |
| 15 | `easeOutBack` 给 opacity | 断言红块 | 见 10 节规则 1 |
| 16 | 玻璃标签用实心 accent | 像塑料片 | 同色文字 + 14% 底 |

---

## 13. 迁移与落地

### 13.1 最小文件集

```
lib/design/
├── tokens.dart
├── design_system.dart
├── design_switcher.dart
├── md3_design_system.dart
├── glass_design_system.dart
├── glass_card.dart
├── glass_edge_painter.dart
├── glass_surface.dart
├── glass_switch.dart
├── glass_slider.dart
├── segment_style.dart
├── bottom_nav_bar.dart
├── page_shell.dart
├── wallpaper_page.dart
├── instant_route.dart
├── expandable_section.dart
├── copyable_text.dart
├── glass_sheet.dart
├── glass_menu.dart
├── glass_dialog.dart
├── glass_toast.dart
└── glass_select.dart
lib/state/
├── theme_controller.dart
└── theme_scope.dart
```

### 13.2 接入步骤

1. 复制上面两组文件
2. `main.dart` 改成 `Directionality > Stack[背景层, MaterialApp]`
3. 主题统一走 `DesignLanguage.resolve(...).buildTheme(...)`；
   把原来手写的 `ColorScheme.fromSeed`、`appBarTheme` 搬进 DesignSystem
4. 已有外观设置的项目：让 `ThemeController` **委托读取**而不是各存一份，避免两个来源打架
5. `MaterialPageRoute` → `InstantPageRoute`（全项目替换，`builder` 签名一致）
6. `Card` → `GlassCard`（非玻璃主题下自动退化为 `Card`）
7. 自定义 AppBar 里按 `tokens.glass` 分支
8. Android `windowBackground` 对齐主题底色，关闭预测返回

### 13.3 Android 侧配置

```xml
<!-- values/styles.xml -->
<item name="android:windowBackground">#FFE6EAF2</item>

<!-- values-night/styles.xml -->
<item name="android:windowBackground">#FF12161D</item>
```

```xml
<!-- AndroidManifest.xml -->
<application android:enableOnBackInvokedCallback="false" ...>
```

### 13.4 验收清单

- [ ] 所有页面 Scaffold 透明，根层有背景（光斑或壁纸）
- [ ] push 页面一律 `InstantPageRoute`
- [ ] 卡片 `GlassCard`，InkWell 圆角 = `cardRadius`
- [ ] 浮层只用 `showGlassToast / showGlassMenu / showGlassSheet / showGlassConfirm`
- [ ] 选择器用 `GlassSelectField`，开关/滑块用自绘版本
- [ ] 列表无分割线，按压 accent 12%
- [ ] 弹层四周留白、barrier ≤ 0.32
- [ ] 带 BackdropFilter 的子树没有 Opacity/Fade
- [ ] 按第 12 节逐条自查

### 13.5 主题分组与隔离（防止两种风格混用）

**分组分两层，不要理解成"两套组件"。**

| 层 | 做法 | 位置 |
|---|---|---|
| 主题层 | **物理分离**：两套 `DesignSystem` 各自产出 ThemeData + tokens，只共享 token 结构与 `tokensFromColorScheme` | `md3_design_system.dart` / `glass_design_system.dart` |
| 组件层 | **单实现 + `tokens.glass` 分支** | 各组件文件内 |
| 结构性参数 | **共用、不分支**：圆角、间距、字号、动效时长、布局 | 各组件 |

组件层不做物理两套，原因：同一个 bug 要修两遍、布局逻辑重复、容易漂移。
Material 本身也是"主题驱动单组件"，我们只是把主题换成自定义 token。

**分支审计表**（新增组件时对照）

| 组件 | GLASS 分支 | MD3 分支 |
|---|---|---|
| 背景 `GlassBackdrop` | 光斑 / 壁纸 | 纯色 `background` |
| 卡片 `GlassCard` | 自绘半透明 + 渐变 + 厚度边 | 退化为标准 `Card`（outlined） |
| 浮层 `GlassSurface`（toast/菜单/弹窗/确认框） | 模糊 + 半透明 + `GlassEdgePainter` | **纯色 + 阴影，无描边、无模糊** |
| 开关 `GlassSwitch` | 半透明轨道 + 光晕 | 实心 accent 轨道 |
| 滑块 `GlassSlider` | 白滑块 + 半透明轨道 | accent 滑块 |
| 分段按钮 `segmentStyle` | 透光高光（白 22% / accent 26%） | `accentSoft` 实心 |
| 底栏 `GlassBottomNavBar` | 模糊胶囊 + 厚度边 | 普通卡片底 + 描边 + 阴影 |
| 状态标签 | 14% 底 + 25% 同色描边 | 实心 accent 底 + `onAccentSoft` 文字 |
| 内嵌块 | `surfaceCardAlt` 22% | `surfaceCardAlt` 实色 |
| 连接按钮 | 渐变 + 呼吸光晕 + 外环 + 连上高光 | 实心强调色，无光晕/外环/高光 |
| `iconButtonTheme` | 40 圆形玻璃底 | Material 默认 |
| `tooltipTheme` | 半透明 + 描边 | 实色 |

**新增组件时的硬规则**

1. 任何"质感 / 光影 / 透明 / 模糊"差异 → 必须 `tokens.glass` 分支，
   并在分支处写 `// GLASS:` / `// MD3:` 注释。
2. 结构性参数（间距、圆角、字号、动画时长）**不要分支**——否则会变成两套会漂移的实现。
3. 页面代码禁止直接判断主题写颜色；要么用 `tokens`，要么封装进组件。
4. 带 `BackdropFilter`、`GlassEdgePainter`、渐变的代码必须被 `tokens.glass` 守卫，
   不能泄漏到 MD3。
5. 新增组件后**切到 MD3 走查**：浮层、按钮、开关、标签、内嵌块、底栏六类。

**MD3 走查清单（切换主题后重点看）**

- [ ] 弹窗 / 菜单 / toast：无描边、无模糊、纯色 + 阴影
- [ ] 底部导航：普通卡片底，不是模糊胶囊
- [ ] 卡片：outlined（1px 描边），无渐变厚度边
- [ ] 开关 / 滑块：实心强调色，无光晕
- [ ] 标签：实色底，不是 14% 淡底 + 同色描边
- [ ] 连接按钮：实心圆，无外环、无光晕、无高光扫过

---

## 14. 调参速查

### 想更透

| 位置 | 参数 | 当前值 | 方向 |
|---|---|---|---|
| `glass_card.dart` | 卡片底色 | 0.40 / 0.075 | 调小 |
| `bottom_nav_bar.dart` | 底盘 | 0.14 / 0.16 | 调小 |
| `liquid_glass.dart` | `tint` | 0.06 | 调小到 0 |
| 浮层 | `GlassSurface.opacity` | 0.36 ~ 0.56 | 调小（0.30 起） |
| 浮层 | `GlassSurface.blur` | 16 ~ 24 | 调小（12 起），越低越像液态玻璃 |
| 设置页 | 壁纸压暗 | 0.35 | 调小 |

### 想更有厚度

| 位置 | 参数 | 当前值 |
|---|---|---|
| `glass_edge_painter.dart` | 各层 alpha | 见 8.2 |
| `glass_card.dart` | 渐变 stops | 0 / 0.48 / 1 |
| `liquid_glass.dart` | `depth` | 0.16 |

### 性能

- 玻璃卡片数量多会掉帧：设置里给了「卡片折射 / 全量玻璃」开关
- 静态玻璃卡片几乎无额外开销（无 BackdropFilter）
- 真实模糊只用于底栏与浮层

### 其他

| 想要 | 改哪里 |
|---|---|
| 卡片圆角 | `AppTokens.cardRadius` |
| 光斑强度 | `GlassBackdrop` 的 0.68 / 0.58 |
| 选中亮度差 | `segment_style.dart` 的 0.22 / 0.04 |
| 内嵌块淡不淡 | `surfaceCardAlt.withValues(alpha: 0.22)` |
| 底栏高/圆角/模糊 | `bottom_nav_bar.dart` 的 66 / 22 / 16 |
| 菜单动画 | `glass_menu.dart` 的 190ms / 0.86 / `easeOutBack` |
| toast 停留/位置 | `glass_toast.dart` 的 2s / `bottom 96` |
| 连接按钮 | `_ConnectButton` 的 62 / 50 / 84 / 480ms |
| 页面转场 | `instant_route.dart` 的 260 / 220 / 0.22 |

---

## 15. 变更记录

| 版本 | 外观相关变更 |
|---|---|
| QShell `+1` | MD3 基底、可切换设计语言骨架 |
| QShell `+3` | 液态玻璃第一版：光斑、半透明卡片、模糊底栏 |
| QShell `+4` | 玻璃细节打磨：透明度、描边、图标按钮、搜索框、下拉刷新、卡片折射开关 |
| QShell `+5` | 主按钮 loading 态、MD3 下误显示玻璃开关、结果列表裸排 |
| QShell 未发版 | 二级页面背景改回光斑、系统日夜切换跟随、弹层方案回滚 |
| 2026-11-04 | 三级层级、选中态透光、GlassSwitch、GlassSheet、列表按压与动效、输入框陷阱 |
| 2026-11-05 | 节点面板折叠动画；浮层玻璃化（菜单/确认框/选择器/底部弹窗） |
| 2026-11-06 | 抽出 `GlassSurface`（模糊 + 厚度边 + 顶部高光）；浮层统一并调浅 barrier；菜单缩放弹出与收起曲线；四态连接按钮；玻璃 toast；Tooltip 玻璃化；本文件合并重写 |

---

> 本文档已合并原 `DESIGN-SYSTEM.legacy.md`（QShell 时期）的全部有效内容，
> 旧文件不再保留。后续改动请直接更新本文件。
