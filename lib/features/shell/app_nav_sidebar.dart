import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// 左侧导航栏：品牌区 + 三个 tab 入口。
///
/// 宽度固定 [width]（决策 43），右侧一条 1px 描边与内容区分离。
/// 所有颜色按 `Theme.of(context).brightness` 取值，亮/暗共用一套代码。
class AppNavSidebar extends StatelessWidget {
  const AppNavSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// 侧栏宽度。
  static const double width = 256;

  /// 当前选中的 tab 索引（0 主界面 / 1 日志 / 2 设置）。
  final int selectedIndex;

  /// 点击导航项时回调。
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft(b),
        border: Border(right: BorderSide(color: AppColors.border(b))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandBlock(),
            const SizedBox(height: AppSpace.lg),
            _NavItem(
              index: 0,
              label: '主界面',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            const SizedBox(height: AppSpace.xxs),
            _NavItem(
              index: 1,
              label: '日志',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            const SizedBox(height: AppSpace.xxs),
            _NavItem(
              index: 2,
              label: '设置',
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
          ],
        ),
      ),
    );
  }
}

/// 品牌区：32×32 圆形标识 + 两行文案。
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Row(
      children: [
        Container(
          width: AppSpace.xl,
          height: AppSpace.xl,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer(b),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline,
            size: AppIconSize.sm,
            color: AppColors.onPrimaryContainer(b),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '大川',
                style: TextStyle(
                  fontSize: AppFontSize.label,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(b),
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                '生图工作台',
                style: TextStyle(
                  fontSize: AppFontSize.label,
                  color: AppColors.textTertiary(b),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单个导航项：当前项实底高亮，其余项 hover 时浮出底色。
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  void _handleHover(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    setState(() {
      _hovered = hovered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final selected = widget.selected;
    final foreground = selected
        ? AppColors.onPrimaryContainer(b)
        : _hovered
        ? AppColors.textPrimary(b)
        : AppColors.textSecondary(b);
    final background = selected
        ? AppColors.primaryContainer(b)
        : _hovered
        ? AppColors.surfaceMuted(b)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              // 图标必须内联常量：release 的图标 tree-shaking 只认字面量。
              switch (widget.index) {
                0 => Icon(
                  Icons.palette_outlined,
                  size: AppIconSize.md,
                  color: foreground,
                ),
                1 => Icon(
                  Icons.terminal,
                  size: AppIconSize.md,
                  color: foreground,
                ),
                _ => Icon(
                  Icons.settings_outlined,
                  size: AppIconSize.md,
                  color: foreground,
                ),
              },
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.label,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
