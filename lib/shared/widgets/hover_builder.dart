import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 通用悬停容器。
///
/// 现状问题：全库零 `MouseRegion`，图卡、按钮、设置项都没有悬停反馈，
/// 桌面用户无法判断「哪里可点、哪里可拖、哪里能删」。
/// 全项目悬停态统一走这里，避免各自写一套 alpha 和时长。
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.cursor = SystemMouseCursors.click,
    this.hoverBorderColor,
    this.hoverColor,
    this.hoverElevation = true,
    this.hoverScale = false,
    this.enabled = true,
  });

  /// 悬停时为 true
  final Widget Function(BuildContext context, bool hovered) builder;

  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onLongPress;
  final MouseCursor cursor;

  /// 悬停时描边变为该颜色
  final Color? hoverBorderColor;

  /// 悬停时叠加的底色
  final Color? hoverColor;

  /// 悬停时抬升阴影
  final bool hoverElevation;

  /// 悬停时轻微放大（用于小按钮）
  final bool hoverScale;

  final bool enabled;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  void _set(bool value) {
    if (!mounted || _hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final canInteract =
        widget.enabled && (widget.onTap != null || widget.onLongPress != null);

    Widget content = widget.builder(context, _hovered);

    if (widget.hoverElevation && _hovered) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: AppShadow.raised,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: content,
      );
    }

    if (widget.hoverScale && _hovered) {
      content = Transform.scale(scale: 1.04, child: content);
    }

    if (widget.hoverBorderColor != null || widget.hoverColor != null) {
      final decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: _hovered
            ? widget.hoverColor ?? Colors.transparent
            : Colors.transparent,
      );
      content = AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: decoration,
        child: content,
      );
    }

    return MouseRegion(
      cursor: widget.enabled
          ? (canInteract || widget.onSecondaryTap != null
              ? widget.cursor
              : MouseCursor.defer)
          : SystemMouseCursors.basic,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTap: widget.onSecondaryTap,
        onLongPress: widget.onLongPress,
        child: content,
      ),
    );
  }
}

/// 悬停时显示、移开时隐藏的浮层操作条。
///
/// 用于图卡右上角的操作按钮：常态不占视觉，鼠标进入才出现。
class HoverReveal extends StatefulWidget {
  const HoverReveal({
    super.key,
    required this.child,
    this.alignment = Alignment.topRight,
    this.duration = AppMotion.fast,
  });

  final Widget child;
  final Alignment alignment;
  final Duration duration;

  @override
  State<HoverReveal> createState() => _HoverRevealState();
}

class _HoverRevealState extends State<HoverReveal> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        opacity: _hovered ? 1 : 0,
        duration: widget.duration,
        curve: AppMotion.curve,
        child: IgnorePointer(ignoring: !_hovered, child: widget.child),
      ),
    );
  }
}