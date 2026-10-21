import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// 余额显示槽。
///
/// 本身只负责“怎么显示”，数据由 [ChannelBalanceLabel] 之类的取数组件传进来：
/// - [value] 有值：`余额: $10.68`；
/// - [loading]：`余额: 查询中…`；
/// - [failed]：`余额: 获取失败`（提示里放具体原因，点一下重试）；
/// - 三者都没有：整块不渲染，不摆假数字。
class BalanceLabel extends StatelessWidget {
  const BalanceLabel({
    super.key,
    this.value,
    this.loading = false,
    this.failed = false,
    this.tooltip,
    this.onTap,
  });

  /// 已格式化好的余额文本，如 `$10.68`；`null` 表示暂无数据。
  final String? value;

  /// 正在查询。
  final bool loading;

  /// 上一次查询失败。
  final bool failed;

  /// 悬停提示（来源、说明或错误原因）。
  final String? tooltip;

  /// 点击回调；`null` 时不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null && !loading && !failed) {
      return const SizedBox.shrink();
    }

    final b = Theme.of(context).brightness;
    final accent = failed
        ? AppColors.dangerText(b)
        : AppColors.primary(b);
    final placeholder = loading
        ? '查询中…'
        : failed
        ? '获取失败'
        : '';
    final display = value ?? placeholder;

    final textStyle = TextStyle(
      fontSize: AppFontSize.caption,
      height: 1.3,
      color: AppColors.textSecondary(b),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: AppIconSize.xs,
          color: failed ? AppColors.dangerText(b) : AppColors.textSecondary(b),
        ),
        const SizedBox(width: AppSpace.xxs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '余额: ', style: textStyle),
              TextSpan(
                text: display,
                style: textStyle.copyWith(
                  fontWeight: value == null ? FontWeight.w500 : FontWeight.w700,
                  color: value == null
                      ? AppColors.textTertiary(b)
                      : accent,
                ),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    Widget result = content;
    if (onTap != null) {
      result = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxs,
            vertical: 2,
          ),
          child: result,
        ),
      );
    }

    final tooltip = this.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      result = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: result,
      );
    }

    return result;
  }
}
