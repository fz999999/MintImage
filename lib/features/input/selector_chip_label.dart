import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme.dart';

class SelectorChipLabel extends StatelessWidget {
  const SelectorChipLabel({super.key, required this.value, this.label});
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Text(
      label == null ? value : '$label:$value',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppFontSize.label,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: AppColors.textPrimary(b),
      ),
    );
  }
}

/// One pointer handler and one keyboard handler share the same guarded action.
class SelectorChipTrigger extends StatefulWidget {
  const SelectorChipTrigger({
    super.key,
    required this.onOpen,
    required this.child,
  });
  final Future<void> Function(BuildContext context) onOpen;
  final Widget child;

  @override
  State<SelectorChipTrigger> createState() => _SelectorChipTriggerState();
}

class _SelectorChipTriggerState extends State<SelectorChipTrigger> {
  final _focus = FocusNode();
  bool _opening = false;
  bool _focused = false;

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    if (defaultTargetPlatform == TargetPlatform.windows) _focus.requestFocus();
    try {
      await widget.onOpen(context);
    } finally {
      _opening = false;
      if (mounted && defaultTargetPlatform == TargetPlatform.windows) {
        _focus.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointer = GestureDetector(onTap: _open, child: widget.child);
    if (defaultTargetPlatform != TargetPlatform.windows) return pointer;
    return Focus(
      focusNode: _focus,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (_, event) {
        final key = event.logicalKey;
        final activates =
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            (key == LogicalKeyboardKey.arrowDown &&
                HardwareKeyboard.instance.isAltPressed);
        if (!activates) return KeyEventResult.ignored;
        if (event is KeyDownEvent) _open();
        return KeyEventResult.handled;
      },
      child: Semantics(
        button: true,
        onTap: _open,
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: _focused
                ? Border.all(
                    color: AppColors.primary(Theme.of(context).brightness),
                    width: 2,
                  )
                : null,
          ),
          child: pointer,
        ),
      ),
    );
  }
}

/// 图标由调用方使用内联常量传入，确保 release tree-shaking 保留。
class SelectorChipShell extends StatefulWidget {
  const SelectorChipShell({
    super.key,
    required this.child,
    this.active = false,
    this.enabled = true,
  });
  final Widget child;
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
    final background = widget.active
        ? AppColors.primarySoft(b)
        : _hovered && widget.enabled
        ? AppColors.surfaceMuted(b)
        : AppColors.surfaceSoft(b);
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: widget.active
                ? AppColors.primary(b).withValues(alpha: 0.55)
                : _hovered && widget.enabled
                ? AppColors.borderStrong(b)
                : AppColors.border(b),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

Rect? selectorChipAnchor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
