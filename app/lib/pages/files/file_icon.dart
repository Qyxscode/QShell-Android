import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 文件类型分组，决定图标与色调。
enum _FileKind {
  folder(Icons.folder_rounded),
  archive(Icons.folder_zip_rounded),
  android(Icons.android_rounded),
  package(Icons.inventory_2_outlined),
  image(Icons.image_rounded),
  video(Icons.movie_rounded),
  audio(Icons.audio_file_rounded),
  pdf(Icons.picture_as_pdf_rounded),
  doc(Icons.description_rounded),
  sheet(Icons.table_chart_rounded),
  slide(Icons.slideshow_rounded),
  text(Icons.notes_rounded),
  code(Icons.code_rounded),
  disk(Icons.album_rounded),
  database(Icons.storage_rounded),
  other(Icons.insert_drive_file_outlined);

  const _FileKind(this.icon);
  final IconData icon;
}

_FileKind _kindOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return _FileKind.other;
  final ext = name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'zip' || 'tar' || 'gz' || 'tgz' || 'xz' || '7z' || 'rar' || 'bz2' =>
      _FileKind.archive,
    'apk' || 'aab' => _FileKind.android,
    'deb' || 'rpm' || 'pkg' => _FileKind.package,
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' || 'svg' || 'heic' =>
      _FileKind.image,
    'mp4' || 'mkv' || 'avi' || 'mov' || 'flv' || 'webm' => _FileKind.video,
    'mp3' || 'flac' || 'wav' || 'aac' || 'ogg' => _FileKind.audio,
    'pdf' => _FileKind.pdf,
    'doc' || 'docx' => _FileKind.doc,
    'xls' || 'xlsx' || 'csv' => _FileKind.sheet,
    'ppt' || 'pptx' => _FileKind.slide,
    'txt' || 'md' || 'log' || 'conf' || 'ini' || 'yaml' || 'yml' =>
      _FileKind.text,
    'json' || 'xml' || 'html' || 'htm' || 'css' || 'js' || 'ts' || 'dart' ||
    'py' || 'sh' || 'c' || 'cpp' || 'h' || 'go' || 'rs' || 'java' || 'kt' =>
      _FileKind.code,
    'iso' || 'img' => _FileKind.disk,
    'db' || 'sqlite' => _FileKind.database,
    _ => _FileKind.other,
  };
}

/// 类型色调：同类文件在列表里形成稳定色块，扫视时更容易定位。
Color _toneOf(_FileKind kind, AppTokens tokens, bool isDark) {
  Color base;
  switch (kind) {
    case _FileKind.folder:
      base = tokens.accent;
    case _FileKind.archive:
      base = const Color(0xFFB98A2E);
    case _FileKind.android:
      base = const Color(0xFF3DDC84);
    case _FileKind.package:
      base = const Color(0xFF9B6BD6);
    case _FileKind.image:
      base = const Color(0xFF4CB782);
    case _FileKind.video:
      base = const Color(0xFF8E7CC3);
    case _FileKind.audio:
      base = const Color(0xFFD98E4A);
    case _FileKind.pdf:
      base = const Color(0xFFD9534F);
    case _FileKind.doc:
      base = const Color(0xFF4A82C8);
    case _FileKind.sheet:
      base = const Color(0xFF3E9A6B);
    case _FileKind.slide:
      base = const Color(0xFFCB7A46);
    case _FileKind.text:
      base = tokens.textSecondary;
    case _FileKind.code:
      base = const Color(0xFF3FA0A6);
    case _FileKind.disk:
      base = const Color(0xFF7A8CA8);
    case _FileKind.database:
      base = const Color(0xFF6A8FB0);
    case _FileKind.other:
      base = tokens.textSecondary;
  }
  // 深色下提亮，浅色下压深，保证图标始终可辨
  return isDark ? Color.lerp(base, Colors.white, 0.28)! : base;
}

/// 按文件后缀给一个图标。
IconData fileIconFor(String name) => _kindOf(name).icon;

/// 统一的条目行：彩色图标块 + 名称 + 副标题。
class RemoteEntryTile extends StatelessWidget {
  const RemoteEntryTile({
    super.key,
    required this.name,
    required this.isDirectory,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.iconColor,
    this.textColor,
    this.trailing,
    this.thumbnail,
  });

  final String name;
  final bool isDirectory;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  /// 图片缩略图（本地文件可直接用），有值时替代图标块
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final kind = isDirectory ? _FileKind.folder : _kindOf(name);
    final tone = iconColor ?? _toneOf(kind, tokens, isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              // 图片优先显示缩略图，其余用彩色图标块区分类型
              if (thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: thumbnail,
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: isDark ? 0.18 : 0.13),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tone.withValues(alpha: isDark ? 0.28 : 0.18),
                    ),
                  ),
                  child: Icon(kind.icon, size: 20, color: tone),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        color: textColor ?? tokens.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            fontSize: 11,
                            color: tokens.textDisabled,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 「返回上级」行，与 [RemoteEntryTile] 视觉一致。
class ParentDirectoryTile extends StatelessWidget {
  const ParentDirectoryTile({super.key, required this.onTap, this.label = '返回上级'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_upward_rounded,
                    size: 19, color: tokens.accent),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: text.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: tokens.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
