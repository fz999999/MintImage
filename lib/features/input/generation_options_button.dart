import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/generation_request.dart';

typedef GenerationOptions = ({
  int frameCount,
  int frameDurationMs,
  ImageComplexity? complexity,
});

class GenerationOptionsButton extends StatelessWidget {
  const GenerationOptionsButton({
    super.key,
    required this.isGif,
    required this.frameCount,
    required this.frameDurationMs,
    required this.complexity,
    required this.onSelected,
  });

  final bool isGif;
  final int frameCount;
  final int frameDurationMs;
  final ImageComplexity? complexity;
  final ValueChanged<GenerationOptions> onSelected;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('generation-options-button'),
      onPressed: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final result = await showDialog<GenerationOptions>(
          context: context,
          builder: (_) => _OptionsDialog(
            isGif: isGif,
            frameCount: frameCount,
            frameDurationMs: frameDurationMs,
            complexity: complexity,
          ),
        );
        if (result != null) onSelected(result);
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
      child: Text(
        isGif
            ? '$frameCount 帧 · $frameDurationMs ms'
            : '复杂度 ${complexity?.label ?? '默认'}',
      ),
    );
  }
}

class _OptionsDialog extends StatefulWidget {
  const _OptionsDialog({
    required this.isGif,
    required this.frameCount,
    required this.frameDurationMs,
    required this.complexity,
  });
  final bool isGif;
  final int frameCount;
  final int frameDurationMs;
  final ImageComplexity? complexity;

  @override
  State<_OptionsDialog> createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<_OptionsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _frames = TextEditingController(text: '${widget.frameCount}');
  late final _duration = TextEditingController(
    text: '${widget.frameDurationMs}',
  );
  late ImageComplexity? _complexity = widget.complexity;

  @override
  void dispose() {
    _frames.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isGif ? 'GIF 动画设置' : '生成设置'),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('规划复杂度（GPT Image 2.6）'),
                DropdownButton<ImageComplexity?>(
                  key: const Key('complexity-selector'),
                  value: _complexity,
                  hint: const Text('服务端默认'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('服务端默认')),
                    for (final value in ImageComplexity.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) => setState(() => _complexity = value),
                ),
                if (widget.isGif) ...[
                  TextFormField(
                    key: const Key('gif-frame-count'),
                    controller: _frames,
                    decoration: const InputDecoration(labelText: '帧数（2–64）'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final count = int.tryParse(value ?? '');
                      return count == null || count < 2 || count > 64
                          ? '请输入 2–64'
                          : null;
                    },
                  ),
                  TextFormField(
                    key: const Key('gif-frame-duration'),
                    controller: _duration,
                    decoration: const InputDecoration(
                      labelText: '每帧毫秒（20–2000）',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final duration = int.tryParse(value ?? '');
                      return duration == null ||
                              duration < 20 ||
                              duration > 2000
                          ? '请输入 20–2000'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '仅支持文生图，自动关闭流式请求。帧时长由服务端按 10 毫秒取整；大尺寸或多帧超出预算时，请减少帧数或选择自动尺寸。',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              frameCount: int.parse(_frames.text),
              frameDurationMs: int.parse(_duration.text),
              complexity: _complexity,
            ));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
