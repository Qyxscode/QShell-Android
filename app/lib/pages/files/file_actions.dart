import 'dart:io';

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
  return showModalBottomSheet<FileAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
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
              leading: Icon(Icons.open_in_new_rounded, color: tokens.accent),
              title: Text(AppStrings.of(context).filesOpen),
              onTap: () => Navigator.pop(context, FileAction.open),
            ),
            ListTile(
              leading: Icon(Icons.download_rounded, color: tokens.accent),
              title: Text(AppStrings.of(context).filesDownload),
              subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, FileAction.download),
            ),
          ],
          ListTile(
            leading: Icon(Icons.drive_file_rename_outline_rounded,
                color: tokens.accent),
            title: Text(AppStrings.of(context).filesRename),
            onTap: () => Navigator.pop(context, FileAction.rename),
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: tokens.accent),
            title: Text(AppStrings.of(context).filesProperties),
            onTap: () => Navigator.pop(context, FileAction.properties),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: tokens.danger),
            title: Text(AppStrings.of(context).commonDelete, style: TextStyle(color: tokens.danger)),
            onTap: () => Navigator.pop(context, FileAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 把远程文件下载到缓存目录，然后交给系统应用打开。
Future<String> downloadToCacheAndOpen(
  String name,
  Future<void> Function(String localPath) downloader,
) async {
  final dir = await getTemporaryDirectory();
  final target = File('${dir.path}/$name');
  await downloader(target.path);
  if (await target.exists()) {
    await OpenFilex.open(target.path);
  }
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
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppStrings.of(context).filesProperties),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(AppStrings.of(context).commonName, name),
            row(AppStrings.of(context).filesType, isDirectory ? AppStrings.of(context).filesFolder : AppStrings.of(context).filesFile),
            if (sizeText != null) row(AppStrings.of(context).filesSize, sizeText),
            if (modifiedText != null && modifiedText.isNotEmpty)
              row(AppStrings.of(context).filesModified, modifiedText),
            row(AppStrings.of(context).filesPath, path),
            if (extra != null && extra.isNotEmpty) row(AppStrings.of(context).filesExtra, extra),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.of(context).filesClose),
        ),
      ],
    ),
  );
}

/// 重命名输入框，返回新名字（null 表示取消）。
Future<String?> askNewName(BuildContext context, String current) async {
  final controller = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppStrings.of(context).filesRename),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: AppStrings.of(context).filesNewName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(AppStrings.of(context).commonConfirmBtn),
        ),
      ],
    ),
  );
  if (result == null || result.isEmpty || result == current) return null;
  return result;
}
