import 'dart:developer' as developer;
import 'dart:io';

import 'video_preview_page.dart';
import '../../design/instant_route.dart';
import 'image_preview_page.dart';
import '../../design/glass_sheet.dart';
import '../../design/glass_dialog.dart';
import '../../design/glass_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../design/tokens.dart';
import '../../i18n/app_strings.dart';

/// 文件操作菜单的选项。
enum FileAction { open, download, rename, delete, properties }

/// 单击文件弹出的上拉菜单。
Future<FileAction?> showFileActionSheet(
  BuildContext context, {
  required String name,
  required bool isDirectory,
  required String subtitle,
}) {
  final tokens = AppTokens.of(context);
  final text = Theme.of(context).textTheme;
  developer.log('menu=$name label=${openActionLabel(name)}', name: 'QShell');
  return showGlassSheet<FileAction>(
    context,
    title: '',
    showHeader: false,
    builder: (context, close) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isDirectory) ...[
            ListTile(
              leading: Icon(
                isPlayableVideo(name)
                    ? Icons.play_circle_outline_rounded
                    : isPreviewableImage(name)
                        ? Icons.image_outlined
                        : Icons.open_in_new_rounded,
                color: tokens.accent,
              ),
              title: Text(openActionLabel(name)),
              subtitle: isPlayableVideo(name)
                  ? const Text('在线播放，边下边播')
                  : isPreviewableImage(name)
                      ? const Text('应用内查看')
                      : null,
              onTap: () => close(FileAction.open),
            ),
            ListTile(
              leading: Icon(Icons.download_rounded, color: tokens.accent),
              title: Text(AppStrings.of(context).filesDownload),
              subtitle: Text('保存到本地 · $subtitle',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => close(FileAction.download),
            ),
          ],
          ListTile(
            leading: Icon(Icons.drive_file_rename_outline_rounded,
                color: tokens.accent),
            title: Text(AppStrings.of(context).filesRename),
            onTap: () => close(FileAction.rename),
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: tokens.accent),
            title: Text(AppStrings.of(context).filesProperties),
            onTap: () => close(FileAction.properties),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: tokens.danger),
            title: Text(AppStrings.of(context).commonDelete, style: TextStyle(color: tokens.danger)),
            onTap: () => close(FileAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 按文件类型给「打开」换成更明确的文案。
String openActionLabel(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (const {'mp4', 'mkv', 'avi', 'mov', 'flv', 'webm', 'm4v', '3gp'}
      .contains(ext)) {
    return '播放';
  }
  if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'}
      .contains(ext)) {
    return '预览';
  }
  if (ext == 'apk' || ext == 'aab') return '安装';
  return '打开';
}

/// 视频扩展名：应用内播放。
bool isPlayableVideo(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  const exts = {'mp4', 'mkv', 'avi', 'mov', 'flv', 'webm', 'm4v', '3gp'};
  return exts.contains(name.substring(dot + 1).toLowerCase());
}

/// 图片扩展名：这些类型走应用内预览，不交给系统相册。
bool isPreviewableImage(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  const exts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
  };
  return exts.contains(name.substring(dot + 1).toLowerCase());
}

/// 把远程文件下载到缓存目录，然后交给系统应用打开。
///
/// 图片交给 ImagePreviewPage：系统相册能看但删不掉、也找不到源文件。
Future<String> downloadToCacheAndOpen(
  String name,
  Future<void> Function(String localPath) downloader, {
  BuildContext? context,
  /// 同目录里的其他图片：传了就进图库，可左右翻页
  List<ImagePreviewItem>? gallery,
  int galleryStart = 0,
}) async {
  final dir = await getTemporaryDirectory();
  final target = File('${dir.path}/$name');
  await downloader(target.path);
  if (!await target.exists()) return target.path;

  if (context != null && context.mounted && isPlayableVideo(name)) {
    if (context.mounted) {
      await Navigator.of(context).push(
        InstantPageRoute<void>(
          builder: (_) => VideoPreviewPage(name: name, filePath: target.path),
        ),
      );
    }
    return target.path;
  }
  if (context != null && context.mounted && isPreviewableImage(name)) {
    final bytes = await target.readAsBytes();
    if (context.mounted) {
      // 有同目录图片列表就进图库，否则退化成单图
      final items = gallery ??
          [ImagePreviewItem(name: name, bytes: bytes)];
      if (gallery != null) items[galleryStart].bytes = bytes;
      await Navigator.of(context).push(
        InstantPageRoute<void>(
          builder: (_) => ImagePreviewPage(
            items: items,
            initialIndex: gallery == null ? 0 : galleryStart,
          ),
        ),
      );
    }
    return target.path;
  }

  await OpenFilex.open(target.path);
  return target.path;
}

/// 属性对话框。
Future<void> showFileProperties(
  BuildContext context, {
  required String name,
  required String path,
  required bool isDirectory,
  String? sizeText,
  String? modifiedText,
  String? extra,
}) {
  final tokens = AppTokens.of(context);
  final text = Theme.of(context).textTheme;
  Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              child: Text(label,
                  style:
                      text.bodySmall?.copyWith(color: tokens.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: text.bodyMedium?.copyWith(color: tokens.textPrimary)),
            ),
          ],
        ),
      );
  return showGlassInfo(
    context,
    title: AppStrings.of(context).filesProperties,
    closeText: AppStrings.of(context).filesClose,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(AppStrings.of(context).commonName, name),
        row(AppStrings.of(context).filesType, isDirectory ? AppStrings.of(context).filesFolder : AppStrings.of(context).filesFile),
        if (sizeText != null) row(AppStrings.of(context).filesSize, sizeText),
        if (modifiedText != null && modifiedText.isNotEmpty)
          row(AppStrings.of(context).filesModified, modifiedText),
        row(AppStrings.of(context).filesPath, path),
        if (extra != null && extra.isNotEmpty)
          row(AppStrings.of(context).filesExtra, extra),
      ],
    ),
  );
}

/// 重命名输入框，返回新名字（null 表示取消）。
Future<String?> askNewName(BuildContext context, String current) async {
  final result = await showGlassInput(
    context,
    title: AppStrings.of(context).filesRename,
    label: AppStrings.of(context).filesNewName,
    initial: current,
    confirmText: AppStrings.of(context).commonConfirmBtn,
    cancelText: AppStrings.of(context).commonCancel,
  );
  if (result == null || result.isEmpty || result == current) return null;
  return result;
}

/// 清理「打开」时落到临时目录的文件。
///
/// 这些文件只在交给系统应用或预览时用一次，留着只会越积越多。
Future<void> clearOpenCache() async {
  try {
    final dir = await getTemporaryDirectory();
    if (!dir.existsSync()) return;
    for (final e in dir.listSync()) {
      try {
        await e.delete(recursive: true);
      } catch (_) {
        // 正在被播放器占用的文件删不掉，跳过
      }
    }
  } catch (_) {}
}