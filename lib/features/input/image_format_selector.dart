import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../shared/theme.dart';
import 'selector_chip_label.dart';

class ImageFormatSelector extends StatelessWidget {
  const ImageFormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onSelected,
  });

  final ImageOutputFormat selectedFormat;
  final ValueChanged<ImageOutputFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return GestureDetector(
      onTap: () => _showSheet(context),
      child: SelectorChipShell(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: AppIconSize.sm,
              color: AppColors.primaryStrong(b),
            ),
            const SizedBox(width: AppSpace.xxs),
            SelectorChipLabel(value: selectedFormat.label),
          ],
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final b = Theme.of(ctx).brightness;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ImageOutputFormat.values.map((format) {
              final active = format == selectedFormat;
              return ListTile(
                leading: Icon(
                  active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: active
                      ? AppColors.primary(b)
                      : AppColors.textTertiary(b),
                ),
                title: Text(format.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onSelected(format);
                },
              );
            }).toList(),
          ),
        );
      },
    );
    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus(
        disposition: UnfocusDisposition.scope,
      );
    }
  }
}
