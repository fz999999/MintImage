import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:mint_image/core/services/attachment_picker_service.dart';
import 'package:mint_image/core/services/markup_validation.dart';
import 'package:mint_image/features/input/markup_canvas.dart';
import 'package:mint_image/features/input/markup_editor.dart';
import 'package:mint_image/shared/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'transparent PNG export preserves dimensions, eraser and undo/redo',
    () async {
      final document = MarkupDocument(width: 120, height: 80);
      addTearDown(document.dispose);
      document.begin(
        const Offset(20, 40),
        width: 16,
        color: Colors.red,
        erase: false,
      );
      document.append(const Offset(100, 40));
      document.end();
      var decoded = image.decodePng((await document.exportPng())!)!;
      expect((decoded.width, decoded.height), (120, 80));
      expect(decoded.getPixel(60, 40).a, 255);
      expect(decoded.getPixel(0, 0).a, 0);
      document.begin(
        const Offset(60, 40),
        width: 24,
        color: Colors.red,
        erase: true,
      );
      document.end();
      decoded = image.decodePng((await document.exportPng())!)!;
      expect(decoded.getPixel(60, 40).a, 0);
      document.undo();
      decoded = image.decodePng((await document.exportPng())!)!;
      expect(decoded.getPixel(60, 40).a, 255);
      document.redo();
      decoded = image.decodePng((await document.exportPng())!)!;
      expect(decoded.getPixel(60, 40).a, 0);
      document.clear();
      expect(await document.exportPng(), isNull);
      document.undo();
      expect(await document.exportPng(), isNotNull);
    },
  );

  testWidgets(
    'drawing after zoom uses source coordinates and excludes the photo',
    (tester) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final reference = await tester.runAsync(() => picture.toImage(100, 100));
      picture.dispose();
      final document = MarkupDocument(width: 100, height: 100);
      final transform = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 200,
                child: MarkupCanvas(
                  reference: reference!,
                  document: document,
                  tool: MarkupTool.brush,
                  brushWidth: 6,
                  color: Colors.red,
                  transformation: transform,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(100, 100));
      final bytes = await tester.runAsync(document.exportPng);
      final decoded = image.decodePng(bytes!)!;
      expect(decoded.getPixel(25, 25).a, 255);
      expect(decoded.getPixel(50, 50).a, 0);
      expect(decoded.getPixel(90, 90).a, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      reference.dispose();
      document.dispose();
      transform.dispose();
    },
  );

  test('rotated JPEG references validate against oriented size', () async {
    final directory = Directory.systemTemp.createTempSync('markup-exif-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final raster = image.Image(width: 40, height: 20)
      ..exif.imageIfd.orientation = 6;
    final reference = File('${directory.path}/reference.jpg')
      ..writeAsBytesSync(image.encodeJpg(raster));
    final overlay = File('${directory.path}/markup.png');
    expect(await readMarkupReferenceSize(reference.path), (20, 40));
    final prepared = await prepareMarkupReference(reference.path);
    expect((prepared.width, prepared.height), (20, 40));
    expect(prepared.rgba.length, 20 * 40 * 4);
    overlay.writeAsBytesSync(
      image.encodePng(image.Image(width: 20, height: 40, numChannels: 4)),
    );
    expect(
      await validateMarkupAttachment(reference.path, overlay.path),
      isNull,
    );
    overlay.writeAsBytesSync(
      image.encodePng(image.Image(width: 40, height: 20, numChannels: 4)),
    );
    expect(
      await validateMarkupAttachment(reference.path, overlay.path),
      contains('20×40'),
    );
  });

  group('canvas input', () {
    late ui.Image reference;
    late MarkupDocument document;
    late TransformationController transform;

    Future<Rect> pumpCanvas(WidgetTester tester) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      reference = (await tester.runAsync(() => picture.toImage(100, 100)))!;
      picture.dispose();
      document = MarkupDocument(width: 100, height: 100);
      transform = TransformationController();
      addTearDown(() {
        reference.dispose();
        document.dispose();
        transform.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 200,
                child: MarkupCanvas(
                  reference: reference,
                  document: document,
                  tool: MarkupTool.brush,
                  brushWidth: 6,
                  color: Colors.red,
                  transformation: transform,
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getRect(find.byKey(const Key('markup-drawing-surface')));
    }

    testWidgets('a second finger cancels the stroke for pinch zoom', (
      tester,
    ) async {
      final rect = await pumpCanvas(tester);
      final first = await tester.startGesture(rect.center);
      await first.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(document.hasContent, isTrue);
      final second = await tester.startGesture(
        rect.center + const Offset(30, 30),
      );
      await tester.pump();
      expect(document.hasContent, isFalse);
      expect(document.canUndo, isFalse);
      await first.moveBy(const Offset(-30, -30));
      await second.moveBy(const Offset(30, 30));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(document.hasContent, isFalse);
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      // A fresh single touch draws again.
      await tester.tapAt(rect.center);
      expect(document.hasContent, isTrue);
    });

    testWidgets('mouse wheel zooms without leaving the brush tool', (
      tester,
    ) async {
      final rect = await pumpCanvas(tester);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(rect.center));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.pump();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      final gesture = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(10, 0));
      await gesture.up();
      expect(document.hasContent, isTrue);
    });

    testWidgets('the stylus eraser end erases', (tester) async {
      final rect = await pumpCanvas(tester);
      final gesture = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.invertedStylus,
      );
      await gesture.up();
      expect(document.canUndo, isTrue);
      expect(document.hasContent, isFalse);
    });
  });

  for (final size in [
    const Size(1100, 850),
    const Size(390, 844),
    const Size(320, 640),
    const Size(844, 390),
  ]) {
    testWidgets('editor draws, undoes, cancels and applies at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('markup-ui-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final reference = File('${directory.path}/reference.png');
      final raster = image.Image(width: 640, height: 400, numChannels: 3);
      image.fill(raster, color: image.ColorRgb8(216, 236, 242));
      image.fillRect(
        raster,
        x1: 60,
        y1: 80,
        x2: 580,
        y2: 320,
        color: image.ColorRgb8(70, 142, 151),
      );
      image.fillRect(
        raster,
        x1: 120,
        y1: 140,
        x2: 280,
        y2: 280,
        color: image.ColorRgb8(255, 246, 226),
      );
      await tester.runAsync(
        () => reference.writeAsBytes(image.encodePng(raster)),
      );
      MarkupEditorResult? result;
      if (Platform.environment['CAPTURE_MARKUP_UI'] == '1') {
        final font = FontLoader('MarkupPreview')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/msyh.ttc').readAsBytesSync(),
              ),
            ),
          );
        await tester.runAsync(font.load);
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await tester.runAsync(icons.load);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: Platform.environment['CAPTURE_MARKUP_UI'] == '1'
                ? 'MarkupPreview'
                : null,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppThemeTokens.primary,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showMarkupEditor(
                    context,
                    referencePath: reference.path,
                    picker: AttachmentPickerService(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('open'));
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find
              .byKey(const Key('markup-drawing-surface'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('markup-drawing-surface')), findsOneWidget);
      }

      await open();
      final surface = find.byKey(const Key('markup-drawing-surface'));
      final rect = tester.getRect(surface);
      await tester.dragFrom(
        rect.center - const Offset(35, 20),
        const Offset(60, 25),
      );
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('markup-undo')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('markup-undo')));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('markup-redo')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('markup-redo')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_MARKUP_UI'] == '1') {
        RenderObject? targetRender = tester.renderObject(
          find.byKey(const Key('markup-editor')),
        );
        while (targetRender != null && targetRender is! RenderRepaintBoundary) {
          targetRender = targetRender.parent;
        }
        final boundary = targetRender! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final screenshot = await boundary.toImage();
          final data = await screenshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final target = File(
            'build/ui_previews/markup-${size.width.toInt()}.png',
          );
          await target.parent.create(recursive: true);
          await target.writeAsBytes(data!.buffer.asUint8List());
          screenshot.dispose();
        });
      }
      await tester.tap(find.byKey(const Key('markup-cancel')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await open();
      await tester.tap(surface);
      await tester.tap(find.byKey(const Key('markup-apply')));
      for (var i = 0; i < 100 && result == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(result?.pngBytes, isNotNull);
      final overlay = image.decodePng(result!.pngBytes!)!;
      expect((overlay.width, overlay.height), (640, 400));
      expect(overlay.getPixel(0, 0).a, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
