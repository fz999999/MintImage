import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../shared/widgets/desktop/desktop_popover.dart';
import 'package:flutter/services.dart';

import '../../shared/theme.dart';
import 'selector_chip_label.dart';

class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.count,
    required this.onSelected,
  });

  final int count;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return SelectorChipTrigger(
      onOpen: _showQuantityModal,
      child: SelectorChipShell(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy_all_outlined,
              size: AppIconSize.sm,
              color: AppColors.primaryStrong(b),
            ),
            const SizedBox(width: AppSpace.xxs),
            SelectorChipLabel(label: '数量', value: '$count'),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuantityModal(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final result = await showDesktopPopover<int>(
        context: context,
        width: 280,
        anchorRect: selectorChipAnchor(context),
        builder: (_) => _DesktopQuantityEditor(initial: count),
      );
      if (context.mounted && result != null) onSelected(result);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    final ctrl = TextEditingController(text: count.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _QuantityDialog(controller: ctrl, initial: count),
    );
    ctrl.dispose();
    if (result != null) onSelected(result);
    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    }
  }
}

class _DesktopQuantityEditor extends StatefulWidget {
  const _DesktopQuantityEditor({required this.initial});
  final int initial;
  @override
  State<_DesktopQuantityEditor> createState() => _DesktopQuantityEditorState();
}

class _DesktopQuantityEditorState extends State<_DesktopQuantityEditor> {
  late final TextEditingController _controller;
  int? get _value => int.tryParse(_controller.text.trim());
  String? get _error {
    if (_controller.text.trim().isEmpty) return '请输入生成数量';
    if (!RegExp(r'^\d+$').hasMatch(_controller.text.trim()) || _value == null) {
      return '请输入整数';
    }
    if (_value! < 1 || _value! > 16) return '生成数量须在 1–16 之间';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.value.composing.isValid &&
        !_controller.value.composing.isCollapsed) {
      return;
    }
    if (_error == null) Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('生成数量', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '数量（1–16）',
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [1, 2, 4, 8, 16]
              .map(
                (n) => ChoiceChip(
                  label: Text('$n'),
                  selected: _error == null && _value == n,
                  onSelected: (_) => setState(() {
                    _controller.value = TextEditingValue(
                      text: '$n',
                      selection: TextSelection.collapsed(offset: '$n'.length),
                    );
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: _error == null ? _submit : null,
              child: const Text('确定'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.controller, required this.initial});

  final TextEditingController controller;
  final int initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final v = int.tryParse(widget.controller.text.trim());
    if (v != null && v >= 1 && v <= 16) {
      setState(() => _value = v);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('生成数量'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _MaxValueFormatter(16),
            ],
            decoration: const InputDecoration(
              hintText: '1 - 16',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _buildQuickPicks(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildQuickPicks() {
    final b = Theme.of(context).brightness;
    const picks = [1, 2, 4, 8, 16];
    return Row(
      children: picks.map((n) {
        final active = _value == n;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: n != 16 ? AppSpace.xs : 0),
            child: GestureDetector(
              onTap: () {
                widget.controller.text = '$n';
                widget.controller.selection = TextSelection.collapsed(
                  offset: '$n'.length,
                );
                setState(() => _value = n);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primarySoft(b)
                      : AppColors.surfaceSoft(b),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: active ? AppColors.primary(b) : AppColors.border(b),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: AppFontSize.label,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppColors.primaryStrong(b)
                        : AppColors.textSecondary(b),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MaxValueFormatter extends TextInputFormatter {
  _MaxValueFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final v = int.tryParse(newValue.text);
    if (v == null || v < 1) return oldValue;
    if (v > max) {
      return TextEditingValue(
        text: '$max',
        selection: TextSelection.collapsed(offset: '$max'.length),
      );
    }
    return newValue;
  }
}
