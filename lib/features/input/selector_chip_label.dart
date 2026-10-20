import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// 选项 chip 中「固定提示词 + 当前取值」的组合文本。
///
/// 固定提示词（尺寸 / 质量 / 格式 / 数量 / 渠道 / 模型）用弱化颜色，只起说明作用；
/// 当前取值用主色加粗，保持原来的视觉重点。
/// 用单个 [Text.rich] 承载，宽度受限时整体省略，不会像 Row 那样溢出。
class SelectorChipLabel extends StatelessWidget {
  const SelectorChipLabel({
    super.key,
    required this.prefix,
    required this.value,
  });

  final String prefix;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$prefix:',
            style: textStyle?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeTokens.textSecondary,
            ),
          ),
          TextSpan(
            text: value,
            style: textStyle?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppThemeTokens.primaryStrong,
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }
}
