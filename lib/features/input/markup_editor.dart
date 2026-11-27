import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/attachment_picker_service.dart';
import '../../core/services/markup_validation.dart';
import '../../shared/theme.dart';
import 'markup_canvas.dart';

class MarkupEditorResult {
  const MarkupEditorResult(this.pngBytes);

  /// Null removes the annotation; a null dialog result cancels all changes.
  final Uint8List? pngBytes;
}

Future<MarkupEditorResult?> showMarkupEditor(
  BuildContext context, {
  required String referencePath,
  String? markupPath,
  required AttachmentPickerService picker,
}) => showDialog<MarkupEditorResult>(
  context: context,
  barrierDismissible: false,
  builder: (context) {
    // Landscape phones are wide but short; a windowed dialog leaves no canvas.
    final compact = MediaQuery.sizeOf(context).shortestSide < 600;
    final editor = MarkupEditor(
      referencePath: referencePath,
      markupPath: markupPath,
      picker: picker,
    );
    return compact
        ? Dialog.fullscreen(child: editor)
        : Dialog(
            insetPadding: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            backgroundColor: AppThemeTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 850),
              child: editor,
            ),
          );
  },
);

class MarkupEditor extends StatefulWidget {
  const MarkupEditor({
    super.key,
    required this.referencePath,
    this.markupPath,
    required this.picker,
  });
  final String referencePath;
  final String? markupPath;
  final AttachmentPickerService picker;

  @override
  State<MarkupEditor> createState() => _MarkupEditorState();
}

class _MarkupEditorState extends State<MarkupEditor> {
  final _transform = TransformationController();
  final _viewportKey = GlobalKey();
  final List<ui.Image> _images = [];
  ui.Image? _reference;
  MarkupDocument? _document;
  MarkupTool _tool = MarkupTool.brush;
  Color _color = const Color(0xFFEF4444);
  double _brushWidth = 24;
  bool _showOverlay = true;
  bool _busy = false;
  String? _loadError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<ui.Image> _decodeRgba(MarkupReference reference) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(reference.rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: reference.width,
      height: reference.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  Future<void> _load() async {
    ui.Image? reference;
    ui.Image? overlay;
    try {
      final (width, height) = await readMarkupReferenceSize(
        widget.referencePath,
      );
      try {
        // The engine applies EXIF orientation natively and is much faster.
        reference = await _decode(
          await File(widget.referencePath).readAsBytes(),
        );
      } catch (_) {
        reference = null;
      }
      if (reference == null ||
          reference.width != width ||
          reference.height != height) {
        reference?.dispose();
        reference = await _decodeRgba(
          await prepareMarkupReference(widget.referencePath),
        );
      }
      if (widget.markupPath != null) {
        final error = await validateMarkupAttachment(
          widget.referencePath,
          widget.markupPath!,
        );
        if (error != null) throw FormatException(error);
        overlay = await _decode(await File(widget.markupPath!).readAsBytes());
      }
      if (!mounted) {
        reference.dispose();
        overlay?.dispose();
        return;
      }
      _images.add(reference);
      if (overlay != null) _images.add(overlay);
      setState(() {
        _reference = reference;
        _document = MarkupDocument(
          width: reference!.width,
          height: reference.height,
          base: overlay,
        );
        _brushWidth = (reference.width / 60).clamp(2.0, 128.0);
      });
    } catch (error) {
      reference?.dispose();
      overlay?.dispose();
      if (mounted) setState(() => _loadError = error.toString());
    }
  }

  @override
  void dispose() {
    _document?.dispose();
    _transform.dispose();
    for (final image in _images) {
      image.dispose();
    }
    super.dispose();
  }

  void _selectTool(MarkupTool tool) => setState(() {
    _tool = tool;
    _showOverlay = true;
  });

  Future<void> _apply() async {
    if (_busy || _document == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await _document!.exportPng();
      if (mounted) Navigator.pop(context, MarkupEditorResult(bytes));
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final selected = await widget.picker.pickMarkup();
      if (selected == null) return;
      final error = await validateMarkupAttachment(
        widget.referencePath,
        selected.path,
      );
      if (error != null) throw FormatException(error);
      final overlay = await _decode(await File(selected.path).readAsBytes());
      if (!mounted) {
        overlay.dispose();
        return;
      }
      _images.add(overlay);
      setState(() {
        _document!.importOverlay(overlay);
        _showOverlay = true;
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 8.0);
    if (next == 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box?.size.center(Offset.zero) ?? Offset.zero;
    final anchor = _transform.toScene(center);
    // Keep the scaled content covering the viewport, like InteractiveViewer.
    final size = box?.size ?? Size.zero;
    final matrix = Matrix4.identity()
      ..setTranslationRaw(
        (center.dx - anchor.dx * next).clamp(size.width * (1 - next), 0.0),
        (center.dy - anchor.dy * next).clamp(size.height * (1 - next), 0.0),
        0,
      )
      ..scaleByDouble(next, next, 1, 1);
    _transform.value = matrix;
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
        if (!_busy) _document?.undo();
      },
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): () {
        if (!_busy) _document?.redo();
      },
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
        if (!_busy) _document?.redo();
      },
      const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
        if (!_busy) _document?.undo();
      },
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        meta: true,
        shift: true,
      ): () {
        if (!_busy) _document?.redo();
      },
    },
    child: Focus(
      autofocus: true,
      child: SafeArea(
        child: Material(
          key: const Key('markup-editor'),
          color: AppThemeTokens.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Expanded(
                child: _reference == null
                    ? Center(
                        child: _loadError == null
                            ? const CircularProgressIndicator()
                            : Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _loadError!,
                                  style: const TextStyle(
                                    color: AppThemeTokens.dangerText,
                                  ),
                                ),
                              ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _toolbar(),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9EFF5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppThemeTokens.border,
                                  ),
                                ),
                                child: Stack(
                                  key: _viewportKey,
                                  children: [
                                    Positioned.fill(
                                      child: AbsorbPointer(
                                        absorbing: _busy,
                                        child: MarkupCanvas(
                                          reference: _reference!,
                                          document: _document!,
                                          tool: _tool,
                                          brushWidth: _brushWidth,
                                          color: _color,
                                          transformation: _transform,
                                          showOverlay: _showOverlay,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: _zoomControls(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (constraints.maxHeight >= 360)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  10,
                                ),
                                child: Text(
                                  !_showOverlay
                                      ? '正在查看原图 · 再点眼睛图标恢复标注'
                                      : _tool == MarkupTool.pan
                                      ? '拖动平移 · 双指或滚轮缩放 · 切回画笔继续绘制'
                                      : '圈选或涂画修改区域 · 双指或滚轮缩放，并在提示词中说明修改要求',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppThemeTokens.textSecondary,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: AppThemeTokens.dangerText),
                  ),
                ),
              _footer(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppThemeTokens.surfaceSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.draw_rounded, color: AppThemeTokens.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '标注引导',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _reference == null
                    ? '在参考图上表达修改意图'
                    : '第一张参考图 · ${_reference!.width} × ${_reference!.height}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppThemeTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Tooltip(
          message:
              '透明 PNG 标注层通过 markup 发送，需要服务商及模型支持。标注用于表达修改意图，不能保证像素级限制修改区域。',
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppThemeTokens.textSecondary,
          ),
        ),
        IconButton(
          key: const Key('markup-close'),
          tooltip: '取消并关闭',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 20),
        ),
      ],
    ),
  );

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _toolButton(
                      'brush',
                      '画笔',
                      Icons.brush_outlined,
                      MarkupTool.brush,
                    ),
                    const SizedBox(width: 4),
                    _toolButton(
                      'eraser',
                      '擦除',
                      Icons.auto_fix_normal_rounded,
                      MarkupTool.eraser,
                    ),
                    const SizedBox(width: 4),
                    _toolButton(
                      'pan',
                      '移动',
                      Icons.pan_tool_outlined,
                      MarkupTool.pan,
                    ),
                  ],
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _document!,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('markup-undo'),
                    tooltip: '撤销 · Ctrl / ⌘ Z',
                    onPressed: _busy || !_document!.canUndo
                        ? null
                        : _document!.undo,
                    icon: const Icon(Icons.undo_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    key: const Key('markup-redo'),
                    tooltip: '重做 · Ctrl / ⌘ Shift Z / Ctrl Y',
                    onPressed: _busy || !_document!.canRedo
                        ? null
                        : _document!.redo,
                    icon: const Icon(Icons.redo_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              key: const Key('markup-more'),
              tooltip: '更多操作',
              enabled: !_busy,
              onSelected: (value) {
                if (value == 'import') {
                  _import();
                } else {
                  _document!.clear();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.file_upload_outlined),
                    title: Text('导入 PNG 标注层'),
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  enabled: _document!.hasContent,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_sweep_outlined),
                    title: Text('清空标注（可撤销）'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final colors = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in const [
                  Color(0xFFEF4444),
                  Color(0xFFF59E0B),
                  Color(0xFF10B981),
                  Color(0xFF3B82F6),
                  Color(0xFFFFFFFF),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Semantics(
                      button: true,
                      selected: _color == color,
                      label: '标注颜色 ${color.toARGB32().toRadixString(16)}',
                      child: InkWell(
                        onTap: _busy
                            ? null
                            : () => setState(() {
                                _color = color;
                                _tool = MarkupTool.brush;
                                _showOverlay = true;
                              }),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 28,
                          height: 28,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == color
                                  ? AppThemeTokens.primary
                                  : AppThemeTokens.border,
                              width: _color == color ? 2 : 1,
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
            final widthControl = Row(
              children: [
                Text('粗细', style: Theme.of(context).textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    key: const Key('markup-brush-width'),
                    value: _brushWidth,
                    min: 2,
                    max: 128,
                    label: '${_brushWidth.round()} px',
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _brushWidth = value),
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${_brushWidth.round()} px',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
            return constraints.maxWidth < 460
                ? Column(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: colors),
                      SizedBox(height: 38, child: widthControl),
                    ],
                  )
                : Row(
                    children: [
                      colors,
                      const SizedBox(width: 16),
                      Expanded(child: widthControl),
                    ],
                  );
          },
        ),
      ],
    ),
  );

  Widget _toolButton(
    String key,
    String label,
    IconData icon,
    MarkupTool tool,
  ) => Tooltip(
    message: label,
    child: TextButton.icon(
      key: ValueKey('markup-tool-$key'),
      onPressed: _busy ? null : () => _selectTool(tool),
      style: TextButton.styleFrom(
        minimumSize: Size(MediaQuery.sizeOf(context).width < 400 ? 40 : 64, 40),
        backgroundColor: _tool == tool
            ? AppThemeTokens.surfaceMuted
            : Colors.transparent,
        foregroundColor: _tool == tool
            ? AppThemeTokens.primaryStrong
            : AppThemeTokens.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 17),
      label: MediaQuery.sizeOf(context).width < 400
          ? const SizedBox.shrink()
          : Text(label),
    ),
  );

  Widget _zoomControls() => Material(
    color: Colors.white.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('markup-preview'),
          tooltip: _showOverlay ? '查看原图' : '显示标注',
          onPressed: _busy
              ? null
              : () => setState(() => _showOverlay = !_showOverlay),
          icon: Icon(
            _showOverlay
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
          ),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          key: const Key('markup-zoom-out'),
          tooltip: '缩小',
          onPressed: () => _zoom(0.8),
          icon: const Icon(Icons.remove_rounded, size: 18),
          visualDensity: VisualDensity.compact,
        ),
        ValueListenableBuilder<Matrix4>(
          valueListenable: _transform,
          builder: (_, value, _) => TextButton(
            key: const Key('markup-fit'),
            onPressed: () => _transform.value = Matrix4.identity(),
            child: Text(
              '${(value.getMaxScaleOnAxis() * 100).round()}%',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        IconButton(
          key: const Key('markup-zoom-in'),
          tooltip: '放大',
          onPressed: () => _zoom(1.25),
          icon: const Icon(Icons.add_rounded, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  Widget _footer() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppThemeTokens.border)),
    ),
    child: Row(
      children: [
        TextButton(
          key: const Key('markup-cancel'),
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const Spacer(),
        FilledButton.icon(
          key: const Key('markup-apply'),
          onPressed: _busy || _document == null ? null : _apply,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_busy ? '处理中…' : '使用标注'),
        ),
      ],
    ),
  );
}
