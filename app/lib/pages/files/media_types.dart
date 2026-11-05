/// 文件类型判断：视频 / 音频 / 图片。
///
/// 单独成文件是为了避免 `file_actions.dart`（菜单）和
/// `video_preview_page.dart`（播放器）互相 import 形成环。
library;

/// 视频：交给播放器，最好能在线边下边播。
const Set<String> videoExtensions = <String>{
  'mp4', 'mkv', 'mov', 'avi', 'flv', 'webm', 'm4v', '3gp', 'ts', 'm2ts', 'wmv',
};

/// 音频：同一个播放器（ExoPlayer）也能放，只是不渲染画面。
const Set<String> audioExtensions = <String>{
  'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'oga', 'opus', 'wma', 'amr',
};

/// 图片：应用内预览，不交给系统相册。
const Set<String> imageExtensions = <String>{
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
};

String _extOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

bool isPlayableVideo(String name) => videoExtensions.contains(_extOf(name));

bool isPlayableAudio(String name) => audioExtensions.contains(_extOf(name));

/// 视频或音频：都进应用内播放页。
bool isPlayableMedia(String name) => isPlayableVideo(name) || isPlayableAudio(name);

bool isPreviewableImage(String name) => imageExtensions.contains(_extOf(name));

/// 按文件类型给「打开」换成更明确的文案。
String openActionLabel(String name) {
  if (isPlayableMedia(name)) return '播放';
  if (isPreviewableImage(name)) return '预览';
  final ext = _extOf(name);
  if (ext == 'apk' || ext == 'aab') return '安装';
  return '打开';
}
