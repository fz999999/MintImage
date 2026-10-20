import 'package:flutter/material.dart';
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

    return GestureDetector(
      onTap: () => _showQuantityModal(context),
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
            SelectorChipLabel(value: '$count'),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuantityModal(BuildContext context) async {
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
                    color: active
                        ? AppColors.primary(b)
                        : AppColors.border(b),
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
