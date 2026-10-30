import 'package:flutter/material.dart';

/// 按文件后缀给一个图标，方便在文件列表里快速辨认。
IconData fileIconFor(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) {
    return Icons.insert_drive_file_outlined;
  }
  final ext = name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'zip' || 'tar' || 'gz' || 'tgz' || 'xz' || '7z' || 'rar' || 'bz2' =>
      Icons.folder_zip_rounded,
    'apk' || 'aab' => Icons.android_rounded,
    'deb' || 'rpm' || 'pkg' => Icons.inventory_2_outlined,
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' || 'svg' || 'heic' =>
      Icons.image_rounded,
    'mp4' || 'mkv' || 'avi' || 'mov' || 'flv' || 'webm' =>
      Icons.movie_rounded,
    'mp3' || 'flac' || 'wav' || 'aac' || 'ogg' => Icons.audio_file_rounded,
    'pdf' => Icons.picture_as_pdf_rounded,
    'doc' || 'docx' => Icons.description_rounded,
    'xls' || 'xlsx' || 'csv' => Icons.table_chart_rounded,
    'ppt' || 'pptx' => Icons.slideshow_rounded,
    'txt' || 'md' || 'log' || 'conf' || 'ini' || 'yaml' || 'yml' =>
      Icons.notes_rounded,
    'json' ||
    'xml' ||
    'html' ||
    'htm' ||
    'css' ||
    'js' ||
    'ts' ||
    'dart' ||
    'py' ||
    'sh' ||
    'c' ||
    'cpp' ||
    'h' ||
    'go' ||
    'rs' ||
    'java' ||
    'kt' =>
      Icons.code_rounded,
    'iso' || 'img' => Icons.album_rounded,
    'db' || 'sqlite' => Icons.storage_rounded,
    _ => Icons.insert_drive_file_outlined,
  };
}

/// 统一的条目行：图标 + 名称 + 副标题。
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
  });

  final String name;
  final bool isDirectory;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Icon(
        isDirectory ? Icons.folder_rounded : fileIconFor(name),
        size: 30,
        color: iconColor,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodyMedium?.copyWith(color: textColor),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: textColor?.withValues(alpha: 0.7),
              ),
            ),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
