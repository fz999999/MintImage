import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import 'desktop_popup_tokens.dart';

/// [anchorRect] is in global logical pixels (e.g. a pointer's position).
/// Without it the caller's RenderBox is used. Pop with Navigator.pop(value).
Future<T?> showDesktopPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 360,
  double maxHeight = 420,
  Rect? anchorRect,
  bool preferAbove = true,
}) async {
  if (!context.mounted) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay;
  if (overlay == null) return null;
  final render = context.findRenderObject();
  if (anchorRect == null && (render is! RenderBox || !render.attached || !render.hasSize)) {
    return null;
  }
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final candidate = Focus.maybeOf(context);
  final trigger = candidate != null && candidate.hasFocus ? candidate : null;
  final route = _DesktopPopoverRoute<T>(
    anchorContext: context,
    anchorBox: render is RenderBox ? render : null,
    anchorRect: anchorRect,
    width: width,
    maxHeight: maxHeight,
    preferAbove: preferAbove,
    builder: (context) => themes.wrap(Builder(builder: builder)),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  );
  final result = await navigator.push<T>(route);
  // Wait until the popup no longer owns focus. Do not focus an enclosing scope:
  // it could select the prompt editor instead of the original trigger.
  await route.completed;
  if (context.mounted && navigator.mounted &&
      trigger != null && trigger is! FocusScopeNode &&
      trigger.context != null && trigger.canRequestFocus &&
      (FocusManager.instance.primaryFocus?.context != null)) {
    trigger.requestFocus();
  }
  return result;
}

class _DesktopPopoverRoute<T> extends PopupRoute<T> {
  _DesktopPopoverRoute({
    required this.anchorContext,
    required this.anchorBox,
    required this.anchorRect,
    required this.width,
    required this.maxHeight,
    required this.preferAbove,
    required this.builder,
    required String barrierLabel,
  }) : _barrierLabel = barrierLabel,
       super(requestFocus: true, traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final BuildContext anchorContext;
  final RenderBox? anchorBox;
  final Rect? anchorRect;
  final double width;
  final double maxHeight;
  final bool preferAbove;
  final WidgetBuilder builder;
  final String _barrierLabel;

  @override
  Color get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => _barrierLabel;
  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) => _PopoverPositioner<T>(route: this);
}

class _PopoverPositioner<T> extends StatefulWidget {
  const _PopoverPositioner({required this.route});
  final _DesktopPopoverRoute<T> route;
  @override
  State<_PopoverPositioner<T>> createState() => _PopoverPositionerState<T>();
}

class _PopoverPositionerState<T> extends State<_PopoverPositioner<T>>
    with WidgetsBindingObserver {
  Timer? _anchorWatch;
  Rect? _lastAnchor;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _anchorWatch = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      final anchor = _readAnchor();
      if (anchor == null) {
        _close();
      } else if (anchor != _lastAnchor) {
        setState(() => _lastAnchor = anchor);
      }
    });
  }

  @override
  void didChangeMetrics() => _close();

  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.route.isActive) return;
      final navigator = widget.route.navigator;
      if (navigator == null) return;
      if (widget.route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(widget.route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Rect? _readAnchor() {
    final route = widget.route;
    if (!route.anchorContext.mounted) return null;
    final overlayBox = route.navigator?.overlay?.context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.attached || !overlayBox.hasSize) return null;
    final fixed = route.anchorRect;
    if (fixed != null) {
      return Rect.fromPoints(overlayBox.globalToLocal(fixed.topLeft),
          overlayBox.globalToLocal(fixed.bottomRight));
    }
    final box = route.anchorBox;
    if (box == null || !box.attached || !box.hasSize) return null;
    return Rect.fromPoints(
      overlayBox.globalToLocal(box.localToGlobal(Offset.zero)),
      overlayBox.globalToLocal(box.localToGlobal(box.size.bottomRight(Offset.zero))),
    );
  }

  @override
  void dispose() {
    _anchorWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _readAnchor();
    if (anchor == null) {
      _close();
      return const SizedBox.shrink();
    }
    _lastAnchor = anchor;
    final brightness = Theme.of(context).brightness;
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor: anchor, width: widget.route.width,
          maxHeight: widget.route.maxHeight, preferAbove: widget.route.preferAbove,
          padding: MediaQuery.paddingOf(context)),
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (widget.route.isCurrent) Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          // Keep unhandled activation keys inside the popup route.
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
          child: Material(
            color: AppColors.surface(brightness),
            elevation: 8,
            shadowColor: AppColors.shadowStrong(brightness),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll,
                side: BorderSide(color: AppColors.border(brightness))),
            clipBehavior: Clip.antiAlias,
            child: Builder(builder: widget.route.builder),
          ),
        ),
      ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({required this.anchor, required this.width, required this.maxHeight,
    required this.preferAbove, required this.padding});
  final Rect anchor;
  final double width;
  final double maxHeight;
  final bool preferAbove;
  final EdgeInsets padding;

  Rect _bounds(Size size) => Rect.fromLTRB(
    math.min(size.width, padding.left + DesktopPopupTokens.viewportMargin),
    math.min(size.height, padding.top + DesktopPopupTokens.viewportMargin),
    math.max(padding.left + DesktopPopupTokens.viewportMargin,
        size.width - padding.right - DesktopPopupTokens.viewportMargin),
    math.max(padding.top + DesktopPopupTokens.viewportMargin,
        size.height - padding.bottom - DesktopPopupTokens.viewportMargin),
  );

  double _above(Rect bounds) => math.max(0.0, anchor.top - DesktopPopupTokens.anchorGap - bounds.top);
  double _below(Rect bounds) => math.max(0.0, bounds.bottom - anchor.bottom - DesktopPopupTokens.anchorGap);
  bool _useAbove(Rect bounds, double height) {
    final preferred = preferAbove ? _above(bounds) : _below(bounds);
    final other = preferAbove ? _below(bounds) : _above(bounds);
    return preferred >= height || preferred >= other ? preferAbove : !preferAbove;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final bounds = _bounds(constraints.biggest);
    final available = math.max(_above(bounds), _below(bounds));
    final w = math.min(math.max(0.0, width), math.max(0.0, bounds.width));
    return BoxConstraints(minWidth: w, maxWidth: w,
      maxHeight: math.min(math.max(0.0, maxHeight), math.min(bounds.height, available)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bounds = _bounds(size);
    final above = _useAbove(bounds, childSize.height);
    final x = anchor.left.clamp(bounds.left, math.max(bounds.left, bounds.right - childSize.width));
    final rawY = above ? anchor.top - DesktopPopupTokens.anchorGap - childSize.height
        : anchor.bottom + DesktopPopupTokens.anchorGap;
    final y = rawY.clamp(bounds.top, math.max(bounds.top, bounds.bottom - childSize.height));
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(covariant _PopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor || width != oldDelegate.width ||
      maxHeight != oldDelegate.maxHeight || preferAbove != oldDelegate.preferAbove ||
      padding != oldDelegate.padding;
}
