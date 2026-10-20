import 'package:flutter/material.dart';

import '../theme.dart';

/// 图墙 / 收藏夹 / 日志页共用的空状态卡片。
///
/// P2 起提示胶囊与图标都改由调用方传入：同一个组件在不同页面要说不同的话，
/// 写死「支持文生图」那三枚只在首页成立。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.hints = const [],
    this.actionLabel,
    this.onAction,
    this.icon = Icons.auto_awesome_rounded,
    this.actionIcon = Icons.settings_rounded,
  });

  final String title;
  final String description;

  /// 卡片底部的提示胶囊文案；空列表则不显示整行。
  final List<String> hints;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 渐变圆里的主图标。
  final IconData icon;

  /// 底部按钮图标，默认仍是「前往设置」的齿轮。
  final IconData actionIcon;

  /// 渐变圆的直径（设计稿 92，不属于现有 token 档位）。
  static const double _badgeSize = 92;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        child: Container(
          decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.lg + AppSpace.xxs,
            AppSpace.lg,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _badgeSize,
                height: _badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.canvasTint(b), AppColors.primarySoft(b)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow(b),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: AppIconSize.lg * 1.5,
                  color: AppColors.primary(b),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: AppFontSize.headline,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(b),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: AppFontSize.body,
                  color: AppColors.textSecondary(b),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (hints.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  alignment: WrapAlignment.center,
                  children: [for (final hint in hints) _HintChip(label: hint)],
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpace.md + AppSpace.xxs),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: AppIconSize.sm),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft(b),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: AppFontSize.label,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryStrong(b),
        ),
      ),
    );
  }
}
