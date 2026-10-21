import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import 'desktop_popup_tokens.dart';

class DesktopMenuItem<T> {
  const DesktopMenuItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.badge,
    this.leading,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
  });

  final T value;
  final String label;
  /// Also supplies the visible reason for a disabled command.
  final String? subtitle;
  final String? badge;
  final Widget? leading;
  final bool enabled;
  final bool selected;
  final bool destructive;
}

/// Shared single-choice menu body. Selection commits immediately.
class DesktopChoiceList<T> extends StatefulWidget {
  const DesktopChoiceList({
    super.key,
    required this.items,
    required this.onSelected,
    this.title,
    this.searchable = false,
  });

  final List<DesktopMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String? title;
  final bool searchable;

  @override
  State<DesktopChoiceList<T>> createState() => _DesktopChoiceListState<T>();
}

class _DesktopChoiceListState<T> extends State<DesktopChoiceList<T>> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  late List<FocusNode> _nodes;
  int _active = -1;

  bool get _hasSearch => widget.searchable &&
      widget.items.length > DesktopPopupTokens.searchThreshold;
  bool get _composing => _search.value.composing.isValid &&
      !_search.value.composing.isCollapsed;

  List<int> get _visible {
    final query = _search.text.trim().toLowerCase();
    return [for (var i = 0; i < widget.items.length; i++)
      if (query.isEmpty || widget.items[i].label.toLowerCase().contains(query) ||
          (widget.items[i].subtitle?.toLowerCase().contains(query) ?? false)) i];
  }

  @override
  void initState() {
    super.initState();
    _nodes = [for (final item in widget.items) FocusNode(debugLabel: item.label)];
    _active = widget.items.indexWhere((item) => item.enabled && item.selected);
    if (_active < 0) _active = widget.items.indexWhere((item) => item.enabled);
    _search.addListener(_filterChanged);
  }

  @override
  void didUpdateWidget(covariant DesktopChoiceList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      for (final node in _nodes) { node.dispose(); }
      _nodes = [for (final item in widget.items) FocusNode(debugLabel: item.label)];
      _active = widget.items.indexWhere((item) => item.enabled && item.selected);
      if (_active < 0) _active = widget.items.indexWhere((item) => item.enabled);
    }
  }

  void _filterChanged() {
    // Composition updates must not rebuild away the active IME editor.
    final enabled = _visible.where((i) => widget.items[i].enabled).toList();
    setState(() {
      if (!enabled.contains(_active)) _active = enabled.isEmpty ? -1 : enabled.first;
    });
  }

  void _move(int direction, {bool edge = false}) {
    final enabled = _visible.where((i) => widget.items[i].enabled).toList();
    if (enabled.isEmpty) return;
    final current = enabled.indexOf(_active);
    final position = edge ? (direction > 0 ? enabled.length - 1 : 0)
        : current < 0 ? (direction > 0 ? 0 : enabled.length - 1)
        : (current + direction) % enabled.length;
    setState(() => _active = enabled[position]);
    _nodes[_active].requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _active < 0) return;
      final target = _nodes[_active].context;
      if (target != null) {
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 80), alignment: 0.5);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_composing) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (!_searchFocus.hasFocus &&
        (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end)) {
      _move(key == LogicalKeyboardKey.end ? 1 : -1, edge: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_active >= 0 && widget.items[_active].enabled && _visible.contains(_active)) {
        widget.onSelected(widget.items[_active].value);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _search.removeListener(_filterChanged);
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    for (final node in _nodes) { node.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final visible = _visible;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.xxs, AppSpace.xs, AppSpace.xs),
                child: Text(widget.title!, style: Theme.of(context).textTheme.labelLarge),
              ),
            if (_hasSearch)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  autofocus: true,
                  onSubmitted: (_) {
                    if (!_composing && _active >= 0 &&
                        widget.items[_active].enabled && _visible.contains(_active)) {
                      widget.onSelected(widget.items[_active].value);
                    }
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '搜索',
                    prefixIcon: Icon(Icons.search, size: AppIconSize.sm),
                  ),
                ),
              ),
            Flexible(
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (visible.isEmpty)
                        const Padding(padding: EdgeInsets.all(AppSpace.md), child: Text('没有匹配项')),
                      for (final index in visible) _row(context, brightness, index),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Brightness brightness, int index) {
    final item = widget.items[index];
    final color = !item.enabled ? AppColors.textTertiary(brightness)
        : item.destructive ? AppColors.dangerText(brightness)
        : AppColors.textPrimary(brightness);
    return Semantics(
      selected: item.selected,
      enabled: item.enabled,
      button: true,
      child: InkWell(
        focusNode: _nodes[index],
        autofocus: !_hasSearch && index == _active,
        canRequestFocus: item.enabled,
        borderRadius: AppRadius.xsAll,
        onTap: item.enabled ? () => widget.onSelected(item.value) : null,
        onFocusChange: (focused) {
          if (focused && mounted) setState(() => _active = index);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: item.subtitle == null
              ? DesktopPopupTokens.rowHeight : DesktopPopupTokens.detailRowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: AppSpace.xxs),
            child: Row(
              children: [
                if (item.leading != null) ...[
                  IconTheme(data: IconThemeData(color: color, size: AppIconSize.sm), child: item.leading!),
                  const SizedBox(width: AppSpace.xs),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpace.xs,
                        runSpacing: AppSpace.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(item.label, style: TextStyle(color: color, fontSize: AppFontSize.label)),
                          if (item.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.textTertiary(brightness).withValues(alpha: 0.10),
                                borderRadius: AppRadius.xsAll,
                              ),
                              child: Text(item.badge!, style: TextStyle(
                                color: AppColors.textSecondary(brightness),
                                fontSize: AppFontSize.caption,
                              )),
                            ),
                        ],
                      ),
                      if (item.subtitle != null)
                        Text(item.subtitle!, style: TextStyle(
                          color: AppColors.textTertiary(brightness), fontSize: AppFontSize.caption)),
                    ],
                  ),
                ),
                if (item.selected) ...[
                  const SizedBox(width: AppSpace.xs),
                  Icon(Icons.check, size: AppIconSize.sm, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
