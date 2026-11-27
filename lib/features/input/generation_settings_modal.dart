import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/theme.dart';

Future<T?> showGenerationSettingsModal<T>(
  BuildContext context, {
  required Widget Function(bool compact) builder,
}) {
  final compact = MediaQuery.sizeOf(context).width < 600;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: builder(true),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: builder(false),
    ),
  );
}

class GenerationSettingsPanel extends StatelessWidget {
  const GenerationSettingsPanel({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.compact,
    required this.onApply,
    required this.child,
  });

  final String keyPrefix;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final VoidCallback onApply;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = math.max(
      180.0,
      math.min(
        760.0,
        media.size.height -
            media.viewInsets.bottom -
            media.padding.vertical -
            (compact ? 16 : 48),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 520, maxHeight: height),
      child: Material(
        key: ValueKey('$keyPrefix-panel'),
        color: AppThemeTokens.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: compact
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppThemeTokens.surfaceSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: AppThemeTokens.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppThemeTokens.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppThemeTokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('$keyPrefix-close'),
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      foregroundColor: AppThemeTokens.textSecondary,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: ValueKey('$keyPrefix-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: child,
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppThemeTokens.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Row(
                    children: [
                      TextButton(
                        key: ValueKey('$keyPrefix-cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      const Spacer(),
                      FilledButton(
                        key: ValueKey('$keyPrefix-apply'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppThemeTokens.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onApply,
                        child: const Text('应用设置'),
                      ),
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
}
