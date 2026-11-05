import 'package:flutter/material.dart';

import '../../core/models/generation_request.dart';
import '../../shared/theme.dart';
import 'generation_settings_modal.dart';
import 'image_model_capability_badge.dart';

typedef QualitySettingsSelection = ({
  ImageQuality quality,
  ImageComplexity? complexity,
});

Future<QualitySettingsSelection?> showQualitySettingsModal(
  BuildContext context, {
  required ImageQuality quality,
  required ImageComplexity? complexity,
  required bool showComplexity,
}) => showGenerationSettingsModal<QualitySettingsSelection>(
  context,
  builder: (compact) => _QualitySettingsPanel(
    quality: quality,
    complexity: complexity,
    showComplexity: showComplexity,
    compact: compact,
  ),
);

class _QualitySettingsPanel extends StatefulWidget {
  const _QualitySettingsPanel({
    required this.quality,
    required this.complexity,
    required this.showComplexity,
    required this.compact,
  });

  final ImageQuality quality;
  final ImageComplexity? complexity;
  final bool showComplexity;
  final bool compact;

  @override
  State<_QualitySettingsPanel> createState() => _QualitySettingsPanelState();
}

class _QualitySettingsPanelState extends State<_QualitySettingsPanel> {
  late ImageQuality _quality = widget.quality;
  late ImageComplexity? _complexity = widget.complexity;

  @override
  Widget build(BuildContext context) => GenerationSettingsPanel(
    keyPrefix: 'quality-settings',
    title: '质量与生成设置',
    subtitle: widget.showComplexity ? '调整画面细节与规划方式' : '调整画面的渲染精细程度',
    icon: Icons.tune_rounded,
    compact: widget.compact,
    onApply: () =>
        Navigator.pop(context, (quality: _quality, complexity: _complexity)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(title: '图像质量', description: '控制画面的渲染精细程度'),
        const SizedBox(height: 12),
        _qualityChoices(),
        const SizedBox(height: 10),
        const _Hint('2.6 标记项需 GPT Image 2.6 或兼容模型。'),
        if (widget.showComplexity) ...[
          const _SectionDivider(),
          const _SectionHeading(
            title: '规划复杂度',
            description: '控制构图与内容的规划深度，与画质独立',
            capabilityFeature: '规划复杂度',
          ),
          const SizedBox(height: 12),
          _complexityChoices(),
          const SizedBox(height: 10),
          _Hint(switch (_complexity) {
            null => '默认：跟随模型的规划设置。',
            ImageComplexity.low => '低：适合简单调整与快速尝试。',
            ImageComplexity.medium => '中：均衡规划，适合日常创作。',
            ImageComplexity.high => '高：适合密集文字与复杂构图。',
          }),
        ],
      ],
    ),
  );

  Widget _qualityChoices() {
    const descriptions = {
      ImageQuality.auto: '由模型决定',
      ImageQuality.low: '轻量草稿',
      ImageQuality.medium: '日常创作',
      ImageQuality.high: '精细成图',
      ImageQuality.xhigh: '更高细节',
      ImageQuality.max: '最高精度',
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 260 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final quality in ImageQuality.values)
              SizedBox(
                width: width,
                child: _ChoiceCard(
                  key: ValueKey('quality-option-${quality.apiValue}'),
                  label: quality.label,
                  description: descriptions[quality]!,
                  capabilityFeature:
                      quality == ImageQuality.xhigh ||
                          quality == ImageQuality.max
                      ? '${quality.label}画质'
                      : null,
                  selected: _quality == quality,
                  onTap: () => setState(() => _quality = quality),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _complexityChoices() {
    const descriptions = {
      null: '跟随模型',
      ImageComplexity.low: '简单调整',
      ImageComplexity.medium: '均衡规划',
      ImageComplexity.high: '复杂构图',
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 260 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final complexity in [null, ...ImageComplexity.values])
              SizedBox(
                width: width,
                child: _ChoiceCard(
                  key: ValueKey(
                    'complexity-option-${complexity?.apiValue ?? 'default'}',
                  ),
                  label: complexity?.label ?? '默认',
                  description: descriptions[complexity]!,
                  compact: true,
                  selected: _complexity == complexity,
                  onTap: () => setState(() => _complexity = complexity),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.description,
    this.capabilityFeature,
  });
  final String title;
  final String description;
  final String? capabilityFeature;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppThemeTokens.textPrimary,
            ),
          ),
          if (capabilityFeature != null)
            ImageModelCapabilityBadge(
              key: const Key('complexity-model-capability'),
              feature: capabilityFeature!,
              details: '仅限 Images API；选择“默认”时不发送复杂度参数。',
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppThemeTokens.textSecondary,
          height: 1.5,
        ),
      ),
    ],
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: AppThemeTokens.border),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppThemeTokens.textSecondary,
      fontSize: 11,
      height: 1.5,
    ),
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.capabilityFeature,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final String? capabilityFeature;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppThemeTokens.surfaceSoft : AppThemeTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected ? AppThemeTokens.primary : AppThemeTokens.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 11 : 10,
            ),
            child: compact
                ? Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppThemeTokens.primaryStrong
                            : AppThemeTokens.textPrimary,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AppThemeTokens.primaryStrong
                                        : AppThemeTokens.textPrimary,
                                  ),
                            ),
                          ),
                          if (capabilityFeature != null) ...[
                            const SizedBox(width: 4),
                            ImageModelCapabilityBadge(
                              feature: capabilityFeature!,
                            ),
                          ] else if (selected)
                            const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: AppThemeTokens.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
