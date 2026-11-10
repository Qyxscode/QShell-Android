import 'package:flutter/material.dart';

import '../design/glass_card.dart';
import '../design/tokens.dart';
import '../services/files/transfer_center.dart';

/// 传输面板：列出所有进行中的上传 / 下载，每个任务独立进度与取消。
///
/// 直接订阅 [TransferCenter]，页面里不用再维护任何传输状态。
class TransferPanel extends StatelessWidget {
  const TransferPanel({super.key, this.maxVisible = 3});

  /// 同时显示的条数上限，超出后折叠成「还有 N 项」
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: TransferCenter.instance,
      builder: (context, _) {
        final tasks = TransferCenter.instance.tasks;
        if (tasks.isEmpty) return const SizedBox.shrink();

        final visible = tasks.take(maxVisible).toList();
        final hidden = tasks.length - visible.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: GlassCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final task in visible) ...[
                    _row(context, task, tokens, text),
                    if (task != visible.last) const SizedBox(height: 8),
                  ],
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '还有 $hidden 项传输中',
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    TransferTask task,
    AppTokens tokens,
    TextTheme text,
  ) {
    final progress = task.progress;
    final finished = task.status != TransferStatus.running;
    final color = switch (task.status) {
      TransferStatus.running => tokens.accent,
      TransferStatus.done => tokens.success,
      TransferStatus.failed => tokens.danger,
      TransferStatus.cancelled => tokens.textDisabled,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              finished
                  ? switch (task.status) {
                      TransferStatus.done => Icons.check_circle_rounded,
                      TransferStatus.failed => Icons.error_outline_rounded,
                      _ => Icons.cancel_outlined,
                    }
                  : (task.upload
                      ? Icons.upload_rounded
                      : Icons.download_rounded),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${task.upload ? "上传" : "下载"} ${task.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: tokens.textPrimary),
              ),
            ),
            Text(
              progress == null ? '' : '${(progress * 100).round()}%',
              style: text.labelSmall?.copyWith(color: tokens.textSecondary),
            ),
            if (!finished)
              IconButton(
                tooltip: '取消',
                visualDensity: VisualDensity.compact,
                onPressed: task.cancel,
                icon: Icon(Icons.close_rounded,
                    size: 18, color: tokens.textSecondary),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
        if (!finished)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: tokens.track,
                color: color,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            finished
                ? (task.message ?? _statusText(task.status))
                : '${_fmtSize(task.done)} / ${_fmtSize(task.total)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              color: task.status == TransferStatus.failed
                  ? tokens.danger
                  : tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _statusText(TransferStatus status) => switch (status) {
        TransferStatus.done => '已完成',
        TransferStatus.failed => '失败',
        TransferStatus.cancelled => '已取消',
        TransferStatus.running => '',
      };

  String _fmtSize(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
