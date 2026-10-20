import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// 参数胶囊的内容文本。
///
/// 决策 17：不再显示「尺寸:」「质量:」这类前缀，只显示真实取值，
/// 说明性文字交给左侧的内联常量图标。
/// 用单个 [Text] 承载，宽度受限时整体省略。
class SelectorChipLabel extends StatelessWidget {
  const SelectorChipLabel({super.key, required this.value});

  /// 当前取值，如 `1536×1024` / `高` / `WEBP` / `自动` / `1`。
  final String value;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Text(
      value,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.label,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.primaryStrong(b),
      ),
    );
  }
}

/// 参数胶囊的公共外框：底色、圆角、内边距与 hover 反馈。
///
/// **图标必须由调用方以 `Icon(常量)` 内联传入**（release 的图标 tree-shaking
/// 只认内联常量，从变量/参数传进去的图标会变成空白）。
/// 这里只负责外壳，内容由 [child] 传入，所以每个选择器仍各自书写自己的图标。
class SelectorChipShell extends StatefulWidget {
  const SelectorChipShell({
    super.key,
    required this.child,
    this.active = false,
    this.enabled = true,
  });

  final Widget child;

  /// 选中态（目前只有「透明背景」用到）。
  final bool active;

  final bool enabled;

  @override
  State<SelectorChipShell> createState() => _SelectorChipShellState();
}

class _SelectorChipShellState extends State<SelectorChipShell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final Color background;
    if (widget.active) {
      background = AppColors.primarySoft(b);
    } else if (_hovered && widget.enabled) {
      background = AppColors.surfaceMuted(b);
    } else {
      background = AppColors.surfaceSoft(b);
    }

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: widget.active
                ? AppColors.primary(b).withValues(alpha: 0.55)
                : AppColors.border(b).withValues(alpha: 0.7),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
