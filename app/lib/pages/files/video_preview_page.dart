import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../design/glass_surface.dart';
import '../../design/glass_toast.dart';
import '../../design/tokens.dart';
import 'media_types.dart';

/// 下载当前媒体：回调里报告进度，返回最终保存路径。
typedef MediaDownloader = Future<String> Function(
  void Function(int received, int total) onProgress,
);

/// 音视频播放页。
///
/// 支持三种来源：
/// - 网络（可带请求头）：边下边播，不用等整个文件下完
/// - 本地文件
/// - 音频文件：只显示封面与控件，不渲染画面
///
/// 交互：
/// - 单击画面：显示/隐藏控件
/// - 双击左/右半屏：后退/前进 15 秒
/// - 画面左右滑动：连续拖动进度（松手生效）
/// - 进度条自带圆形拖动头，拖起来比细线准
class VideoPreviewPage extends StatefulWidget {
  const VideoPreviewPage({
    super.key,
    required this.name,
    this.networkUrl,
    this.httpHeaders,
    this.filePath,
    this.downloader,
  }) : assert(
          networkUrl != null || filePath != null,
          '需要 networkUrl 或 filePath',
        );

  final String name;
  final String? networkUrl;
  final Map<String, String>? httpHeaders;
  final String? filePath;

  /// 为空时隐藏下载按钮（本地文件、下载后播放等场景不需要再存一份）。
  final MediaDownloader? downloader;

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  static const List<double> _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const Duration _skipStep = Duration(seconds: 15);

  VideoPlayerController? _ctrl;
  bool _ready = false;
  String? _error;
  bool _chrome = true;

  double _speed = 1;

  /// 用户手动点过旋转后记下方向；为 null 时按视频比例自动决定。
  Orientation? _manualOrientation;

  /// 拖进度条
  bool _scrubbing = false;
  Duration _scrubPosition = Duration.zero;

  /// 在画面上左右滑动拖进度
  bool _seekDragging = false;
  bool _seekActivated = false;
  double _seekDx = 0;
  Duration _seekStart = Duration.zero;
  Duration? _seekTarget;

  /// 双击位（用来判断左右半屏）
  Offset? _doubleTapPosition;

  /// 下载
  bool _downloading = false;
  double _downloadProgress = 0;
  bool _downloaded = false;

  String? _hint;
  Timer? _hintTimer;

  bool get _isAudio => isPlayableAudio(widget.name);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = widget.networkUrl != null
          ? VideoPlayerController.networkUrl(
              Uri.parse(widget.networkUrl!),
              httpHeaders: widget.httpHeaders ?? const {},
            )
          : VideoPlayerController.file(File(widget.filePath!));
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setPlaybackSpeed(_speed);
      _ctrl = ctrl;
      ctrl.addListener(_onTick);
      setState(() => _ready = true);
      // 横视频转横屏、竖视频转竖屏；音频不动屏幕
      if (!_isAudio) await _applyAutoOrientation(ctrl.value.aspectRatio);
      await ctrl.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  /// 按视频宽高比决定屏幕方向。
  ///
  /// 接近方形（0.87 ~ 1.15）的视频不强制旋转——那种视频横竖都能看，
  /// 强行转屏反而打断用户。
  Future<void> _applyAutoOrientation(double aspect) async {
    if (_manualOrientation != null) return;
    if (aspect >= 1.15) {
      if (!mounted) return;
      await _setOrientation(Orientation.landscape);
    } else if (aspect > 0 && aspect <= 0.87) {
      if (!mounted) return;
      await _setOrientation(Orientation.portrait);
    }
  }

  Future<void> _setOrientation(Orientation orientation) async {
    if (orientation == Orientation.landscape) {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  /// 手动旋转：在横屏 / 竖屏之间切换，并锁住（不再自动跟随视频比例）。
  Future<void> _rotateScreen() async {
    final current = MediaQuery.orientationOf(context);
    final next = current == Orientation.landscape
        ? Orientation.portrait
        : Orientation.landscape;
    _manualOrientation = next;
    await _setOrientation(next);
    if (!mounted) return;
    _flashHint(next == Orientation.landscape ? '横屏' : '竖屏');
  }

  void _onTick() {
    if (!mounted) return;
    // 拖动时由拖动值接管显示，但仍要刷新一次让时长等元信息更新
    setState(() {});
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    // 退出播放页恢复自动旋转（App 其余页面跟随系统）
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 交互

  void _flashHint(String text) {
    _hintTimer?.cancel();
    setState(() => _hint = text);
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Future<void> _seekBy(Duration delta) async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final duration = ctrl.value.duration;
    var target = ctrl.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await ctrl.seekTo(target);
    if (!mounted) return;
    _flashHint(delta.isNegative ? '-15s' : '+15s');
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    final position = _doubleTapPosition;
    _doubleTapPosition = null;
    if (position == null) return;
    final width = MediaQuery.sizeOf(context).width;
    _seekBy(position.dx < width / 2 ? -_skipStep : _skipStep);
  }

  void _onSeekDragStart(DragStartDetails details) {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _seekDragging = true;
    _seekActivated = false;
    _seekDx = 0;
    _seekStart = ctrl.value.position;
    _seekTarget = null;
  }

  void _onSeekDragUpdate(DragUpdateDetails details) {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final duration = ctrl.value.duration;
    if (duration <= Duration.zero) return;
    _seekDx += details.delta.dx;
    // 小于 8px 当作误触，不动进度
    if (!_seekActivated && _seekDx.abs() < 8) return;
    _seekActivated = true;

    final width = MediaQuery.sizeOf(context).width;
    final deltaMs = duration.inMilliseconds * _seekDx / width;
    var target = _seekStart + Duration(milliseconds: deltaMs.round());
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    setState(() => _seekTarget = target);
  }

  Future<void> _onSeekDragEnd(DragEndDetails details) async {
    final target = _seekTarget;
    final activated = _seekActivated;
    setState(() {
      _seekDragging = false;
      _seekActivated = false;
      _seekTarget = null;
    });
    if (activated && target != null) {
      await _ctrl?.seekTo(target);
    }
  }

  Future<void> _setSpeed(double speed) async {
    await _ctrl?.setPlaybackSpeed(speed);
    if (!mounted) return;
    setState(() => _speed = speed);
  }

  Future<void> _download() async {
    final downloader = widget.downloader;
    if (downloader == null || _downloading || _downloaded) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    try {
      final path = await downloader((received, total) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
        });
      });
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloaded = true;
      });
      showGlassToast(context, '已保存到\n$path', tone: GlassToastTone.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      showGlassToast(context, '下载失败：$e', tone: GlassToastTone.error);
    }
  }

  // ---------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final ctrl = _ctrl;
    final value = ctrl?.value;
    final duration = value?.duration ?? Duration.zero;
    final position = _seekDragging
        ? (_seekTarget ?? _seekStart)
        : _scrubbing
            ? _scrubPosition
            : (value?.position ?? Duration.zero);

    return Scaffold(
      backgroundColor: Colors.black,
      // 必须显式撑满：body 给的是 loose 约束，加载态时没有底部控制条
      // 撑高，Stack 会塌成顶部栏那么高，Center 就在那一条里居中
      // （表现就是加载圈和文字跑到屏幕顶上）。
      body: SizedBox.expand(
        child: Stack(
          children: [
          // 内容层：画面 / 加载圈 / 错误。单独一层并忽略触摸，
          // 这样它的定位与手势层互不影响（之前和手势层共用一层，
          // 加载态的居中在转场/重建时容易被带偏）。
          Positioned.fill(
            child: IgnorePointer(
              child: _ready && ctrl != null
                  ? _media(ctrl, tokens)
                  : _statusOrError(tokens),
            ),
          ),

          // 手势层：单击切控件、双击左右 ±15s、画面横滑拖进度
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _ready ? () => setState(() => _chrome = !_chrome) : null,
              onDoubleTapDown: _ready ? _onDoubleTapDown : null,
              onDoubleTap: _ready ? _onDoubleTap : null,
              onHorizontalDragStart: _ready ? _onSeekDragStart : null,
              onHorizontalDragUpdate: _ready ? _onSeekDragUpdate : null,
              onHorizontalDragEnd: _ready ? _onSeekDragEnd : null,
            ),
          ),

          // 拖动时的中央指示
          if (_seekDragging && _seekActivated && _seekTarget != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _SeekBubble(
                    target: _seekTarget!,
                    offset: _seekTarget! - _seekStart,
                    duration: duration,
                  ),
                ),
              ),
            ),

          // 双击 / 快进提示
          if (_hint != null && !_seekActivated)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _hint!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 顶部
          AnimatedSlide(
            offset: _chrome ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_ready) ...[
                      _RoundButton(
                        icon: Icons.screen_rotation_rounded,
                        onTap: _rotateScreen,
                      ),
                      const SizedBox(width: 6),
                      _speedButton(tokens),
                    ],
                    if (widget.downloader != null) ...[
                      const SizedBox(width: 6),
                      _downloadButton(tokens),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 底部控制条
          if (_ready && ctrl != null)
            AnimatedSlide(
              offset: _chrome ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: GlassSurface(
                      borderRadius: 18,
                      blur: 18,
                      opacity: 0.42,
                      padding: const EdgeInsets.fromLTRB(6, 2, 10, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _progressBar(tokens, ctrl, position, duration),
                          Row(
                            children: [
                              IconButton(
                                iconSize: 30,
                                color: Colors.white,
                                icon: Icon(
                                  value?.isPlaying == true
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                onPressed: () {
                                  if (value?.isPlaying == true) {
                                    ctrl.pause();
                                  } else {
                                    ctrl.play();
                                  }
                                  setState(() {});
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _fmt(position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                ' / ${_fmt(duration)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const Spacer(),
                              if (_isAudio)
                                const Row(
                                  children: [
                                    Icon(Icons.graphic_eq_rounded,
                                        size: 14, color: Colors.white54),
                                    SizedBox(width: 4),
                                    Text('音频',
                                        style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11)),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 视频画面 / 音频封面。
  Widget _media(VideoPlayerController ctrl, AppTokens tokens) {
    final aspect = ctrl.value.aspectRatio;
    final player = Center(
      child: AspectRatio(
        aspectRatio: aspect > 0 ? aspect : 16 / 9,
        child: VideoPlayer(ctrl),
      ),
    );
    if (!_isAudio) return player;

    // 音频：把播放器压在封面下面，texture 仍挂在树上（后台播放不会被回收）
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        ColoredBox(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tokens.accent.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      size: 58, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusOrError(AppTokens tokens) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  size: 44, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('无法播放这个文件',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _error = null);
                  _init();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 14),
          Text(
            widget.networkUrl != null ? '正在连接服务器…' : '正在准备…',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 进度条：圆头比细线好按，拖动时暂停跟随播放位置。
  Widget _progressBar(
    AppTokens tokens,
    VideoPlayerController ctrl,
    Duration position,
    Duration duration,
  ) {
    final maxMs = duration.inMilliseconds;
    final valueMs = position.inMilliseconds.clamp(0, maxMs > 0 ? maxMs : 0);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3.5,
        activeTrackColor: tokens.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withValues(alpha: 0.14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: valueMs.toDouble(),
        max: maxMs > 0 ? maxMs.toDouble() : 1,
        onChangeStart: maxMs <= 0
            ? null
            : (v) => setState(() {
                  _scrubbing = true;
                  _scrubPosition = Duration(milliseconds: v.round());
                }),
        onChanged: maxMs <= 0
            ? null
            : (v) => setState(() {
                  _scrubPosition = Duration(milliseconds: v.round());
                }),
        onChangeEnd: maxMs <= 0
            ? null
            : (v) async {
                setState(() {
                  _scrubbing = false;
                  _scrubPosition = Duration(milliseconds: v.round());
                });
                await ctrl.seekTo(Duration(milliseconds: v.round()));
              },
      ),
    );
  }

  Widget _speedButton(AppTokens tokens) {
    return PopupMenuButton<double>(
      tooltip: '倍速',
      initialValue: _speed,
      onSelected: _setSpeed,
      color: const Color(0xF21A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        for (final speed in _speeds)
          PopupMenuItem<double>(
            value: speed,
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: speed == _speed
                      ? Icon(Icons.check_rounded, size: 16, color: tokens.accent)
                      : null,
                ),
                Text(
                  '${_speedLabel(speed)}x',
                  style: TextStyle(
                    color: speed == _speed ? tokens.accent : Colors.white,
                    fontSize: 13,
                    fontWeight:
                        speed == _speed ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (speed == 1) ...[
                  const SizedBox(width: 6),
                  const Text('正常',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_speedLabel(_speed)}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(AppTokens tokens) {
    return _RoundButton(
      icon: _downloaded
          ? Icons.check_rounded
          : Icons.download_rounded,
      onTap: _downloading || _downloaded ? null : _download,
      progress: _downloading ? _downloadProgress : null,
    );
  }

  static String _speedLabel(double speed) =>
      speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : '$speed';

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

/// 中央的拖动指示：目标时间 + 相对偏移。
class _SeekBubble extends StatelessWidget {
  const _SeekBubble({
    required this.target,
    required this.offset,
    required this.duration,
  });

  final Duration target;
  final Duration offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final positive = !offset.isNegative;
    final total = offset.inSeconds.abs();
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${positive ? '+' : '-'}$mm:$ss',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(target)} / ${_fmt(duration)}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

/// 圆形半透明按钮（返回 / 下载），可按需显示环形进度。
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.progress,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// 非空时在按钮中间画进度环（下载中）。
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: progress != null
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: progress == 0 ? null : progress,
                      strokeWidth: 2.2,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: onTap == null ? Colors.white38 : Colors.white,
                ),
        ),
      ),
    );
  }
}
