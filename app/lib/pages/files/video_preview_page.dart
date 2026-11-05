import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../design/glass_surface.dart';
import '../../design/tokens.dart';

/// 视频播放页。
///
/// 支持三种来源：
/// - 网络（可带请求头）：边下边播，不用等整个文件下完
/// - 本地文件
/// - 已下载的字节（远程协议不支持流式时）
class VideoPreviewPage extends StatefulWidget {
  const VideoPreviewPage({
    super.key,
    required this.name,
    this.networkUrl,
    this.httpHeaders,
    this.filePath,
  }) : assert(
          networkUrl != null || filePath != null,
          '需要 networkUrl 或 filePath',
        );

  final String name;
  final String? networkUrl;
  final Map<String, String>? httpHeaders;
  final String? filePath;

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  String? _error;
  bool _chrome = true;

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
      setState(() {
        _ctrl = ctrl;
        _ready = true;
      });
      await ctrl.play();
      ctrl.addListener(_onTick);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_ready && _ctrl != null)
            Center(
              child: AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio,
                child: VideoPlayer(_ctrl!),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded,
                        size: 44, color: Colors.white38),
                    const SizedBox(height: 12),
                    const Text(
                      '无法播放这个视频',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(height: 14),
                  const Text('正在连接服务器…',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  if (widget.networkUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                      child: Text(
                        widget.networkUrl!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          // 点击视频区切换控件
          if (_ready)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _chrome = !_chrome),
                child: const SizedBox.expand(),
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
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                  ],
                ),
              ),
            ),
          ),
          // 底部控制条
          if (_ready && _ctrl != null)
            AnimatedSlide(
              offset: _chrome ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GlassSurface(
                      borderRadius: 16,
                      blur: 18,
                      opacity: 0.42,
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                      child: Row(
                        children: [
                          IconButton(
                            iconSize: 26,
                            color: Colors.white,
                            icon: Icon(
                              _ctrl!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            onPressed: () {
                              setState(() {
                                _ctrl!.value.isPlaying
                                    ? _ctrl!.pause()
                                    : _ctrl!.play();
                              });
                            },
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _ctrl!,
                              allowScrubbing: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              colors: VideoProgressColors(
                                playedColor: tokens.accent,
                                bufferedColor:
                                    Colors.white.withValues(alpha: 0.28),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _fmt(_ctrl!.value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            ' / ${_fmt(_ctrl!.value.duration)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
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
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
