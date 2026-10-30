import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/tokens.dart';
import '../../../i18n/app_strings.dart';
import '../../../services/network_info_service.dart';

/// 链路拓扑：本机 → 上级设备 → 直连出口（有代理时）→ 出口。
///
/// 紧凑单卡布局：一行一个节点，左侧圆点串联，尽量少占高度。
class TopologyCard extends StatelessWidget {
  const TopologyCard({
    super.key,
    required this.snapshot,
    this.onTapNode,
  });

  final NetworkSnapshot snapshot;
  final void Function(String node)? onTapNode;

  bool get _isMobileOnly =>
      snapshot.kinds.contains(ConnectivityResult.mobile) &&
      !snapshot.kinds.contains(ConnectivityResult.wifi);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);

    final rows = <_TopoRowData>[
      _TopoRowData(
        key: 'local',
        title: strings.homeLocal,
        value: snapshot.localIp ?? strings.commonNotObtained,
        hint: snapshot.interfaceLabel,
      ),
      if (!_isMobileOnly)
        _TopoRowData(
          key: 'gateway',
          title: strings.homeUpstream,
          value: _gatewayText(),
          hint: strings.homeDefaultGateway,
          multiline: true,
        ),
      if (snapshot.viaProxy)
        _TopoRowData(
          key: 'direct',
          title: strings.homeDirectExit,
          value: snapshot.directIp ?? strings.commonNotObtained,
          hint: strings.homeDomesticLine,
        ),
      _TopoRowData(
        key: 'public',
        title: snapshot.viaProxy ? strings.homeProxyExit : strings.homePublic,
        value: _publicText(),
        hint: snapshot.region,
        multiline: true,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 16, color: tokens.accent),
                const SizedBox(width: 6),
                Text(
                  strings.homeTopology,
                  style: text.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    snapshot.kindLabel,
                    style: text.labelSmall?.copyWith(
                      color: tokens.onAccentSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++)
              _TopoRow(
                data: rows[i],
                isLast: i == rows.length - 1,
                tokens: tokens,
                text: text,
                onTap: onTapNode,
              ),
            if (snapshot.error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: tokens.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      snapshot.error!,
                      style: text.bodySmall?.copyWith(color: tokens.warning),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _gatewayText() {
    final v4 = snapshot.gatewayV4;
    final v6 = snapshot.gatewayV6;
    if (v4 == null && v6 == null) return AppStrings.zhHans.commonNotObtained;
    if (v4 != null && v6 != null) return '$v4\n$v6';
    return (v4 ?? v6) ?? '未获取';
  }

  /// 公网出口：IPv4 一行，公网 IPv6 若有则换行跟在下面。
  String _publicText() {
    final v4 = snapshot.publicIp;
    final v6 = snapshot.publicIpV6;
    if (v4 == null && v6 == null) return AppStrings.zhHans.commonNotObtained;
    if (v4 != null && v6 != null) return '$v4\n$v6';
    return (v4 ?? v6)!;
  }
}

class _TopoRowData {
  const _TopoRowData({
    required this.key,
    required this.title,
    required this.value,
    this.hint,
    this.multiline = false,
  });

  final String key;
  final String title;
  final String value;
  final String? hint;
  final bool multiline;
}

class _TopoRow extends StatelessWidget {
  const _TopoRow({
    required this.data,
    required this.isLast,
    required this.tokens,
    required this.text,
    this.onTap,
  });

  final _TopoRowData data;
  final bool isLast;
  final AppTokens tokens;
  final TextTheme text;
  final void Function(String node)? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap == null ? null : () => onTap!(data.key),
      // 长按复制该行的值（IP / 域名），方便拿去粘贴
      onLongPress: () {
        final value = data.value.trim();
        final strings = AppStrings.of(context);
        if (value.isEmpty ||
            value == strings.commonNotObtained ||
            value == '--') {
          return;
        }
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('已复制 ${data.title}：$value'),
              duration: const Duration(milliseconds: 1200),
            ),
          );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 18,
              child: Stack(
                alignment: Alignment.topCenter,
                // 允许线画出行边界，跨过两行之间的间距，和下一行圆点接上
                clipBehavior: Clip.none,
                children: [
                  if (!isLast)
                    Positioned(
                      top: 9,
                      // 行间距是 10（右侧内容的 bottom padding），
                      // 往下多画 6px 正好接到下一行圆点的圆心
                      bottom: -6,
                      child: Container(width: 1.5, color: tokens.outlineSoft),
                    ),
                  // 圆点中心对齐右侧第一行文本的垂直中心（文本 padding 1 + 半行高）
                  Positioned(
                    top: 5,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLast ? tokens.highlight : tokens.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  data.title,
                  style: text.labelSmall?.copyWith(color: tokens.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.value,
                      maxLines: data.multiline ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (data.hint != null)
                      Text(
                        data.hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall
                            ?.copyWith(color: tokens.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
