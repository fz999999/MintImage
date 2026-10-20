import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// 余额显示槽（决策 18）。
///
/// 本期**没有数据源**（仓库无 balance / billing 代码，`ImageRecord` 也无费用字段），
/// 调用处统一传 `null`，此时整块不渲染（连占位空白都不留），绝不摆假数字。
/// 以后接上数据源时，只改传值那一处即可。
class BalanceLabel extends StatelessWidget {
  const BalanceLabel({super.key, this.value, this.onTap});

  /// 已格式化好的余额文本，如 `1,420 元`；`null` 表示暂无数据。
  final String? value;

  /// 点击回调；`null` 时不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) {
      return const SizedBox.shrink();
    }

    final b = Theme.of(context).brightness;
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
          color: AppColors.textSecondary(b),
        ),
        const SizedBox(width: AppSpace.xxs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '余额: ', style: textStyle),
              TextSpan(
                text: value,
                style: textStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(b),
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

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xxs,
          vertical: 2,
        ),
        child: content,
      ),
    );
  }
}
