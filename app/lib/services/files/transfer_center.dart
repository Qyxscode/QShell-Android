import 'package:flutter/foundation.dart';

/// 单个传输任务的状态。
enum TransferStatus { running, done, failed, cancelled }

/// 一个上传 / 下载任务。
class TransferTask {
  TransferTask({
    required this.id,
    required this.name,
    required this.upload,
    required this.total,
  });

  final int id;
  final String name;
  final bool upload;

  int total;
  int done = 0;
  TransferStatus status = TransferStatus.running;
  String? message;

  bool _cancelRequested = false;

  bool get cancelRequested => _cancelRequested;

  void cancel() {
    _cancelRequested = true;
  }

  double? get progress {
    if (total <= 0) return null;
    return (done / total).clamp(0.0, 1.0);
  }
}

/// 全局传输中心：允许同时跑多个上传 / 下载。
///
/// 以前每个页面只有一个 `_transferName/_transferDone`，开第二个任务会把
/// 第一个的界面状态顶掉（任务其实还在跑，只是看不见、也无法单独取消）。
/// 现在任务列表集中在这里，页面的进度条只是它的一个视图。
class TransferCenter extends ChangeNotifier {
  TransferCenter._();

  static final TransferCenter instance = TransferCenter._();

  final List<TransferTask> _tasks = <TransferTask>[];
  int _nextId = 1;

  /// 当前所有任务（含刚结束、正在淡出的）
  List<TransferTask> get tasks => List<TransferTask>.unmodifiable(_tasks);

  bool get hasRunning => _tasks.any((t) => t.status == TransferStatus.running);

  TransferTask start({
    required String name,
    required bool upload,
    int total = 0,
  }) {
    final task = TransferTask(
      id: _nextId++,
      name: name,
      upload: upload,
      total: total,
    );
    _tasks.add(task);
    notifyListeners();
    return task;
  }

  void update(TransferTask task, {int? done, int? total}) {
    if (done != null) task.done = done;
    if (total != null && total > 0) task.total = total;
    notifyListeners();
  }

  /// 结束任务：成功的条目停留几秒后自动消失，失败/取消的停留久一点。
  void finish(TransferTask task, TransferStatus status, {String? message}) {
    task.status = status;
    if (message != null) task.message = message;
    notifyListeners();
    final delay = status == TransferStatus.done
        ? const Duration(seconds: 3)
        : const Duration(seconds: 6);
    Future<void>.delayed(delay, () => remove(task));
  }

  void remove(TransferTask task) {
    if (_tasks.remove(task)) notifyListeners();
  }
}
