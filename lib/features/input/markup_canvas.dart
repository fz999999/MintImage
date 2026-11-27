import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum MarkupTool { brush, eraser, pan }

class MarkupStroke {
  MarkupStroke({
    required this.points,
    required this.width,
    required this.color,
    required this.erase,
  });
  final List<Offset> points;
  final double width;
  final Color color;
  final bool erase;
}

/// Stores coordinates in source-image pixels, independent of zoom or viewport.
class MarkupDocument extends ChangeNotifier {
  MarkupDocument({required this.width, required this.height, ui.Image? base})
    : _base = base;
  final int width;
  final int height;
  ui.Image? _base;
  ui.Image? get base => _base;
  final List<MarkupStroke> _strokes = [];
  final List<_MarkupSnapshot> _undo = [];
  final List<_MarkupSnapshot> _redo = [];
  bool _baseVisible = true;
  bool _drawing = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get hasContent =>
      (base != null && _baseVisible) || _strokes.any((stroke) => !stroke.erase);
  bool get isDrawing => _drawing;

  _MarkupSnapshot _snapshot() =>
      _MarkupSnapshot(List.of(_strokes), _baseVisible, _base);
  void _restore(_MarkupSnapshot state) {
    _strokes
      ..clear()
      ..addAll(state.strokes);
    _baseVisible = state.baseVisible;
    _base = state.base;
    _drawing = false;
    notifyListeners();
  }

  Offset _bounded(Offset point) => Offset(
    point.dx.clamp(0.0, width.toDouble()),
    point.dy.clamp(0.0, height.toDouble()),
  );

  void begin(
    Offset point, {
    required double width,
    required Color color,
    required bool erase,
  }) {
    if (_drawing) end();
    _undo.add(_snapshot());
    _redo.clear();
    _strokes.add(
      MarkupStroke(
        points: [_bounded(point)],
        width: width,
        color: color,
        erase: erase,
      ),
    );
    _drawing = true;
    notifyListeners();
  }

  void append(Offset point) {
    if (!_drawing) return;
    _strokes.last.points.add(_bounded(point));
    notifyListeners();
  }

  void end() {
    _drawing = false;
  }

  void cancelStroke() {
    if (!_drawing) return;
    _restore(_undo.removeLast());
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
  }

  void clear() {
    if (!hasContent) return;
    _undo.add(_snapshot());
    _redo.clear();
    _strokes.clear();
    _baseVisible = false;
    _drawing = false;
    notifyListeners();
  }

  void importOverlay(ui.Image overlay) {
    _undo.add(_snapshot());
    _redo.clear();
    _strokes.clear();
    _base = overlay;
    _baseVisible = true;
    _drawing = false;
    notifyListeners();
  }

  void paint(Canvas canvas) {
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    // Isolate the transparent annotation layer so erasing never touches the photo.
    canvas.saveLayer(bounds, Paint());
    canvas.clipRect(bounds);
    if (base != null && _baseVisible) {
      canvas.drawImage(base!, Offset.zero, Paint());
    }
    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final point in stroke.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint..style = PaintingStyle.stroke);
      }
    }
    canvas.restore();
  }

  Future<Uint8List?> exportPng() async {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final picture = recorder.endRecording();
    final output = await picture.toImage(width, height);
    picture.dispose();
    try {
      final rgba = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('无法读取标注像素');
      var transparent = false;
      var visible = false;
      for (var offset = 3; offset < rgba.lengthInBytes; offset += 4) {
        final alpha = rgba.getUint8(offset);
        transparent |= alpha < 255;
        visible |= alpha > 0;
        if (transparent && visible) break;
      }
      // Clearing/erasing the entire overlay means removing it from the draft.
      if (!visible) return null;
      if (!transparent) throw StateError('请保留部分透明区域，避免标注完全覆盖参考图。');
      final encoded = await output.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) throw StateError('无法保存标注 PNG');
      return encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      );
    } finally {
      output.dispose();
    }
  }
}

class _MarkupSnapshot {
  const _MarkupSnapshot(this.strokes, this.baseVisible, this.base);
  final List<MarkupStroke> strokes;
  final bool baseVisible;
  final ui.Image? base;
}

class MarkupCanvas extends StatefulWidget {
  const MarkupCanvas({
    super.key,
    required this.reference,
    required this.document,
    required this.tool,
    required this.brushWidth,
    required this.color,
    required this.transformation,
    this.showOverlay = true,
  });
  final ui.Image reference;
  final MarkupDocument document;
  final MarkupTool tool;
  final double brushWidth;
  final Color color;
  final TransformationController transformation;
  final bool showOverlay;

  @override
  State<MarkupCanvas> createState() => _MarkupCanvasState();
}

class _MarkupCanvasState extends State<MarkupCanvas> {
  int? _pointer;
  final Set<int> _touches = {};

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(
        constraints.maxWidth / widget.document.width,
        constraints.maxHeight / widget.document.height,
      );
      final size = Size(
        widget.document.width * scale,
        widget.document.height * scale,
      );
      // Touches anywhere in the viewport count, including the margins.
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.touch) return;
          _touches.add(event.pointer);
          // A second finger means pinch-zoom, not a stroke.
          if (_touches.length > 1 && _pointer != null) {
            widget.document.cancelStroke();
            _pointer = null;
          }
        },
        onPointerUp: (event) => _touches.remove(event.pointer),
        onPointerCancel: (event) => _touches.remove(event.pointer),
        child: InteractiveViewer(
          transformationController: widget.transformation,
          // Pinch, wheel and trackpad zoom stay available while drawing; a
          // single pointer only pans in pan mode.
          panEnabled: widget.tool == MarkupTool.pan,
          minScale: 1,
          maxScale: 8,
          child: SizedBox.expand(
            child: Center(
              child: MouseRegion(
                cursor: widget.tool == MarkupTool.pan
                    ? SystemMouseCursors.grab
                    : SystemMouseCursors.precise,
                child: Listener(
                  key: const Key('markup-drawing-surface'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    // The outer listener has not recorded this pointer yet, so
                    // any tracked touch means this finger joins a pinch.
                    if (event.kind == PointerDeviceKind.touch &&
                        _touches.isNotEmpty) {
                      return;
                    }
                    if (widget.tool == MarkupTool.pan ||
                        !widget.showOverlay ||
                        _pointer != null ||
                        event.buttons != 1) {
                      return;
                    }
                    _pointer = event.pointer;
                    widget.document.begin(
                      event.localPosition / scale,
                      width: widget.brushWidth,
                      color: widget.color,
                      erase:
                          widget.tool == MarkupTool.eraser ||
                          event.kind == PointerDeviceKind.invertedStylus,
                    );
                  },
                  onPointerMove: (event) {
                    if (_pointer == event.pointer) {
                      widget.document.append(event.localPosition / scale);
                    }
                  },
                  onPointerUp: (event) {
                    if (_pointer == event.pointer) {
                      widget.document.end();
                      _pointer = null;
                    }
                  },
                  onPointerCancel: (event) {
                    if (_pointer == event.pointer) {
                      widget.document.cancelStroke();
                      _pointer = null;
                    }
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: _MarkupPainter(
                        widget.reference,
                        widget.document,
                        widget.showOverlay,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MarkupPainter extends CustomPainter {
  _MarkupPainter(this.reference, this.document, this.showOverlay)
    : super(repaint: document);
  final ui.Image reference;
  final MarkupDocument document;
  final bool showOverlay;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / document.width, size.height / document.height);
    canvas.drawImage(
      reference,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (showOverlay) document.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkupPainter oldDelegate) =>
      oldDelegate.reference != reference ||
      oldDelegate.document != document ||
      oldDelegate.showOverlay != showOverlay;
}
