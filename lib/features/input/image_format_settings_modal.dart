import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/generation_request.dart';
import '../../shared/theme.dart';
import 'generation_settings_modal.dart';
import 'image_model_capability_badge.dart';

typedef ImageFormatSettingsSelection = ({
  ImageOutputFormat format,
  int frameCount,
  int frameDurationMs,
  SvgOptions? svgOptions,
});

Future<ImageFormatSettingsSelection?> showImageFormatSettingsModal(
  BuildContext context, {
  required ImageOutputFormat format,
  required int frameCount,
  required int frameDurationMs,
  SvgOptions? svgOptions,
}) => showGenerationSettingsModal<ImageFormatSettingsSelection>(
  context,
  builder: (compact) => _ImageFormatSettingsPanel(
    format: format,
    frameCount: frameCount,
    frameDurationMs: frameDurationMs,
    svgOptions: svgOptions,
    compact: compact,
  ),
);

class _ImageFormatSettingsPanel extends StatefulWidget {
  const _ImageFormatSettingsPanel({
    required this.format,
    required this.frameCount,
    required this.frameDurationMs,
    required this.compact,
    this.svgOptions,
  });

  final ImageOutputFormat format;
  final int frameCount;
  final int frameDurationMs;
  final bool compact;
  final SvgOptions? svgOptions;

  @override
  State<_ImageFormatSettingsPanel> createState() =>
      _ImageFormatSettingsPanelState();
}

class _ImageFormatSettingsPanelState extends State<_ImageFormatSettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  late ImageOutputFormat _format = widget.format;
  late bool _customSvg = widget.svgOptions != null;
  late final _svgModel = TextEditingController(
    text: widget.svgOptions?.model ?? '',
  );
  late SvgReasoningEffort? _svgEffort = widget.svgOptions?.reasoningEffort;
  late final _frames = TextEditingController(text: '${widget.frameCount}');
  late final _duration = TextEditingController(
    text: '${widget.frameDurationMs}',
  );

  @override
  void dispose() {
    _frames.dispose();
    _duration.dispose();
    _svgModel.dispose();
    super.dispose();
  }

  void _apply() {
    final isGif = _format == ImageOutputFormat.gif;
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      format: _format,
      frameCount: isGif ? int.parse(_frames.text) : widget.frameCount,
      frameDurationMs: isGif
          ? int.parse(_duration.text)
          : widget.frameDurationMs,
      svgOptions: _customSvg
          ? SvgOptions(
              model: _svgModel.text.trim(),
              reasoningEffort: _svgEffort,
            )
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) => GenerationSettingsPanel(
    keyPrefix: 'format-settings',
    title: '图片格式',
    subtitle: '选择输出格式，按需调整动画与矢量参数',
    icon: Icons.image_rounded,
    compact: widget.compact,
    onApply: _apply,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeading(title: '静态图像', description: '按使用场景选择合适的文件格式'),
          const SizedBox(height: 12),
          _formatChoices(const [
            ImageOutputFormat.png,
            ImageOutputFormat.jpeg,
            ImageOutputFormat.webp,
          ], columns: 3),
          const SizedBox(height: 16),
          const _SectionHeading(
            title: '动画与矢量',
            description: '让画面动起来，或使用可缩放的矢量图',
          ),
          const SizedBox(height: 12),
          _formatChoices(const [
            ImageOutputFormat.gif,
            ImageOutputFormat.svg,
          ], columns: 2),
          const SizedBox(height: 10),
          Text(
            'GIF / SVG 需 GPT Image 2.6 或兼容模型 · Images API 文生图',
            key: const Key('format-model-support-hint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppThemeTokens.textSecondary,
              height: 1.5,
            ),
          ),
          if (_format == ImageOutputFormat.gif) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppThemeTokens.border),
            ),
            _animationSettings(),
          ],
          if (_format == ImageOutputFormat.svg) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppThemeTokens.border),
            ),
            _svgSettings(),
          ],
        ],
      ),
    ),
  );

  Widget _formatChoices(
    List<ImageOutputFormat> formats, {
    required int columns,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 260 ? 2 : columns;
        final width = (constraints.maxWidth - (count - 1) * 8) / count;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in formats)
              SizedBox(
                width: width,
                child: _FormatCard(
                  format: format,
                  compact: constraints.maxWidth < 340,
                  selected: _format == format,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _format = format);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _svgSettings() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppThemeTokens.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppThemeTokens.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('svg-custom-model-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('自定义 SVG 绘制模型'),
          subtitle: const Text('默认交由服务端选择；开启后需有对应模型权限'),
          value: _customSvg,
          onChanged: (value) => setState(() => _customSvg = value),
        ),
        if (_customSvg) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('svg-model-field'),
            controller: _svgModel,
            decoration: const InputDecoration(
              labelText: 'SVG 绘制模型',
              hintText: '填写服务商支持的模型 ID',
              helperText: '与主生图模型分开，用于编写 SVG',
              helperMaxLines: 2,
              filled: true,
              fillColor: AppThemeTokens.surface,
            ),
            validator: (value) =>
                _format == ImageOutputFormat.svg &&
                    _customSvg &&
                    (value == null || value.trim().isEmpty)
                ? '请输入模型 ID，或关闭自定义模型'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('svg-reasoning-effort'),
            initialValue: _svgEffort?.name ?? 'default',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'SVG 推理强度',
              helperText: '可用档位取决于绘制模型与服务商',
              helperMaxLines: 2,
              filled: true,
              fillColor: AppThemeTokens.surface,
            ),
            items: [
              const DropdownMenuItem(value: 'default', child: Text('服务端默认')),
              for (final effort in SvgReasoningEffort.values)
                DropdownMenuItem(value: effort.name, child: Text(effort.name)),
            ],
            onChanged: (value) => setState(() {
              _svgEffort = SvgReasoningEffort.fromApiValue(value);
            }),
          ),
        ],
      ],
    ),
  );

  Widget _animationSettings() {
    final frames = int.tryParse(_frames.text);
    final duration = int.tryParse(_duration.text);
    final valid =
        frames != null &&
        frames >= 2 &&
        frames <= 64 &&
        duration != null &&
        duration >= 20 &&
        duration <= 2000;
    final total = valid ? (frames * duration / 1000).toStringAsFixed(2) : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionHeading(
                title: 'GIF 动画',
                description: '设置帧数与每帧停留时间',
              ),
            ),
            const Tooltip(
              message: '帧时长由服务端按 10 ms 取整。大尺寸、多帧超出预算时，请减少帧数或选择自动尺寸。',
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppThemeTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              _numberField(
                label: '帧数',
                hint: '2–64 帧',
                suffix: '帧',
                controller: _frames,
                fieldKey: 'gif-frame-count',
                min: 2,
                max: 64,
              ),
              _numberField(
                label: '每帧时长',
                hint: '20–2000 毫秒',
                suffix: 'ms',
                controller: _duration,
                fieldKey: 'gif-frame-duration',
                min: 20,
                max: 2000,
              ),
            ];
            if (constraints.maxWidth < 320) {
              return Column(
                children: [fields[0], const SizedBox(height: 14), fields[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppThemeTokens.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.loop_rounded,
                size: 18,
                color: AppThemeTokens.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '单轮播放约 $total 秒',
                  key: const Key('gif-duration-summary'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeTokens.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required String hint,
    required String suffix,
    required TextEditingController controller,
    required String fieldKey,
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          key: ValueKey(fieldKey),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeTokens.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            filled: true,
            fillColor: AppThemeTokens.surface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: _inputBorder(AppThemeTokens.border),
            enabledBorder: _inputBorder(AppThemeTokens.border),
            focusedBorder: _inputBorder(AppThemeTokens.primary),
            errorBorder: _inputBorder(AppThemeTokens.dangerText),
            focusedErrorBorder: _inputBorder(AppThemeTokens.dangerText),
          ),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            return number == null || number < min || number > max
                ? '请输入 $min–$max'
                : null;
          },
        ),
      ],
    );
  }

  OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppThemeTokens.textPrimary,
        ),
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

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.format,
    required this.compact,
    required this.selected,
    required this.onTap,
  });
  final ImageOutputFormat format;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, description) = switch (format) {
      ImageOutputFormat.png => (
        Icons.photo_outlined,
        compact ? '无损保存' : '无损 · 通用',
      ),
      ImageOutputFormat.jpeg => (
        Icons.landscape_outlined,
        compact ? '照片压缩' : '照片 · 体积小',
      ),
      ImageOutputFormat.webp => (
        Icons.language_rounded,
        compact ? '轻量图片' : '轻量 · 网络图片',
      ),
      ImageOutputFormat.gif => (Icons.animation_rounded, '循环动画'),
      ImageOutputFormat.svg => (Icons.polyline_rounded, '矢量 · 任意缩放'),
    };
    return Semantics(
      key: ValueKey('format-option-${format.apiValue}'),
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppThemeTokens.surfaceSoft : AppThemeTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppThemeTokens.primary : AppThemeTokens.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: AppThemeTokens.primary),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: selected
                          ? AppThemeTokens.primary
                          : AppThemeTokens.border,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      format.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppThemeTokens.primaryStrong
                            : AppThemeTokens.textPrimary,
                      ),
                    ),
                    if (format.requiresImagesGeneration) ...[
                      const SizedBox(width: 6),
                      ImageModelCapabilityBadge(
                        feature: '${format.label} 格式',
                        details: '仅限 Images API 文生图，自动关闭流式返回。',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.4,
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
