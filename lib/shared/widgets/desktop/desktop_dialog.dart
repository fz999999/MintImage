import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import 'desktop_popup_tokens.dart';

/// Fixed title/actions with a shrinking, independently scrolling body.
class DesktopDialog extends StatelessWidget {
  const DesktopDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.width = 440,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = math.max(0.0, media.size.height - media.viewInsets.vertical -
        media.padding.vertical - DesktopPopupTokens.dialogMargin * 2);
    return _DialogKeyboardBoundary(child: Dialog(
      insetPadding: const EdgeInsets.all(DesktopPopupTokens.dialogMargin),
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
                child: Semantics(namesRoute: true, child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: content,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: AppSpace.xs,
                    overflowSpacing: AppSpace.xs,
                    children: actions,
                  ),
                )
              else
                const SizedBox(height: AppSpace.lg),
            ],
          ),
        ),
      ),
    ));
  }
}

Future<bool> showDesktopConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '删除',
  String cancelLabel = '取消',
  bool destructive = true,
}) async {
  if (!context.mounted) return false;
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    requestFocus: true,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (dialogContext) => _DialogKeyboardBoundary(
      child: DesktopDialog(
        title: title,
        content: SelectableText(message),
        actions: [
          FilledButton(
            style: destructive ? FilledButton.styleFrom(
              backgroundColor: AppColors.dangerText(Theme.of(dialogContext).brightness),
              foregroundColor: Colors.white,
            ) : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        ],
      ),
    ),
  ) ?? false;
}

Future<void> showDesktopInfo({
  required BuildContext context,
  required String title,
  required String text,
  bool copyAll = true,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    requestFocus: true,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (dialogContext) => _DialogKeyboardBoundary(
      child: DesktopDialog(
        title: title,
        width: DesktopPopupTokens.formWidth,
        content: SelectableText(text),
        actions: [
          if (copyAll)
            TextButton.icon(
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: text));
                } on PlatformException {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                      const SnackBar(content: Text('复制失败，请选择文本后复制')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.copy_outlined, size: AppIconSize.sm),
              label: const Text('复制全部'),
            ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    ),
  );
}

class _DialogKeyboardBoundary extends StatelessWidget {
  const _DialogKeyboardBoundary({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        return KeyEventResult.skipRemainingHandlers;
      }
      return KeyEventResult.ignored;
    },
    child: Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: child,
    ),
  );
}
