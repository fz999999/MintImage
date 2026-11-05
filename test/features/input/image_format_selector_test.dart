import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/features/input/image_format_selector.dart';
import 'package:mint_image/features/input/image_format_settings_modal.dart';
import 'package:mint_image/features/input/image_model_capability_badge.dart';
import 'package:mint_image/shared/theme.dart';

void main() {
  testWidgets(
    'SVG author controls validate, persist and reset to provider defaults',
    (tester) async {
      ImageFormatSettingsSelection? selection;
      await _pumpSelector(
        tester,
        format: ImageOutputFormat.svg,
        onSelected: (value) => selection = value,
      );
      await _open(tester);
      final toggle = find.byKey(const Key('svg-custom-model-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('format-settings-apply')));
      await tester.pumpAndSettle();
      expect(selection, isNull);
      final field = find.byKey(const Key('svg-model-field'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'svg-author');
      final effort = find.byKey(const Key('svg-reasoning-effort'));
      await tester.ensureVisible(effort);
      await tester.tap(effort);
      await tester.pumpAndSettle();
      await tester.tap(find.text('high').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('format-settings-apply')));
      await tester.pumpAndSettle();
      expect(selection!.svgOptions!.toJson(), {
        'model': 'svg-author',
        'reasoning': {'effort': 'high'},
      });
      await _pumpSelector(
        tester,
        format: ImageOutputFormat.svg,
        svgOptions: selection!.svgOptions,
        onSelected: (value) => selection = value,
      );
      await _open(tester);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('format-settings-apply')));
      await tester.pumpAndSettle();
      expect(selection!.svgOptions, isNull);
    },
  );
  testWidgets(
    'groups every format and applies selection only on confirmation',
    (tester) async {
      ImageFormatSettingsSelection? selection;
      await _pumpSelector(tester, onSelected: (value) => selection = value);
      await _open(tester);
      expect(find.text('静态图像'), findsOneWidget);
      expect(find.text('动画与矢量'), findsOneWidget);
      for (final format in ImageOutputFormat.values) {
        expect(
          find.byKey(ValueKey('format-option-${format.apiValue}')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('gif-frame-count')), findsNothing);
      await tester.tap(find.byKey(const Key('format-option-webp')));
      expect(selection, isNull);
      await tester.tap(find.byKey(const Key('format-settings-apply')));
      await tester.pumpAndSettle();
      expect(selection!.format, ImageOutputFormat.webp);
      expect(selection!.frameCount, 9);
      expect(selection!.frameDurationMs, 200);
    },
  );

  testWidgets('closing or cancelling discards pending format and GIF edits', (
    tester,
  ) async {
    ImageFormatSettingsSelection? selection;
    await _pumpSelector(tester, onSelected: (value) => selection = value);
    await _open(tester);
    await tester.tap(find.byKey(const Key('format-option-gif')));
    await tester.pumpAndSettle();
    final frames = find.byKey(const Key('gif-frame-count'));
    await tester.ensureVisible(frames);
    await tester.enterText(frames, '12');
    await tester.tap(find.byKey(const Key('format-settings-close')));
    await tester.pumpAndSettle();
    expect(selection, isNull);
    await _open(tester);
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('format-option-png')))
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('format-option-gif')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(frames).controller!.text, '9');
    await tester.tap(find.byKey(const Key('format-settings-cancel')));
    await tester.pumpAndSettle();
    expect(selection, isNull);
  });

  testWidgets(
    'only GIF and SVG show model badges and keep requirements available before selecting',
    (tester) async {
      await _pumpSelector(tester);
      await _open(tester);
      expect(find.byType(ImageModelCapabilityBadge), findsNWidgets(2));
      expect(
        find.text('GIF / SVG 需 GPT Image 2.6 或兼容模型 · Images API 文生图'),
        findsOneWidget,
      );
      for (final value in ['png', 'jpeg', 'webp']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('format-option-$value')),
            matching: find.byType(ImageModelCapabilityBadge),
          ),
          findsNothing,
        );
      }
      for (final value in ['gif', 'svg']) {
        final badge = find.descendant(
          of: find.byKey(ValueKey('format-option-$value')),
          matching: find.byType(ImageModelCapabilityBadge),
        );
        expect(badge, findsOneWidget);
        final tooltip = find.descendant(
          of: badge,
          matching: find.byType(Tooltip),
        );
        final message = tester.widget<Tooltip>(tooltip).message!;
        expect(message, contains('GPT Image 2.6 或兼容模型'));
        expect(message, contains('自动关闭流式返回'));
      }
      final svgBadge = find.descendant(
        of: find.byKey(const Key('format-option-svg')),
        matching: find.byType(ImageModelCapabilityBadge),
      );
      await tester.tap(svgBadge);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('SVG 格式 需 GPT Image 2.6 或兼容模型支持。'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GIF fields validate limits and show playback duration', (
    tester,
  ) async {
    ImageFormatSettingsSelection? selection;
    await _pumpSelector(
      tester,
      format: ImageOutputFormat.gif,
      onSelected: (value) => selection = value,
    );
    await _open(tester);
    final frames = find.byKey(const Key('gif-frame-count'));
    final duration = find.byKey(const Key('gif-frame-duration'));
    await tester.ensureVisible(duration);
    await tester.enterText(frames, '65');
    await tester.enterText(duration, '19');
    await tester.tap(find.byKey(const Key('format-settings-apply')));
    await tester.pump();
    expect(selection, isNull);
    expect(find.text('请输入 2–64'), findsOneWidget);
    expect(find.text('请输入 20–2000'), findsOneWidget);
    await tester.enterText(frames, '1');
    await tester.enterText(duration, '2001');
    await tester.pump();
    expect(find.text('请输入 2–64'), findsOneWidget);
    expect(find.text('请输入 20–2000'), findsOneWidget);
    await tester.enterText(frames, '12');
    await tester.enterText(duration, '150');
    await tester.pump();
    expect(find.text('单轮播放约 1.80 秒'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: frames, matching: find.byType(TextField)),
          )
          .decoration
          ?.labelText,
      isNull,
    );
    await tester.tap(find.byKey(const Key('format-settings-apply')));
    await tester.pumpAndSettle();
    expect(selection!.format, ImageOutputFormat.gif);
    expect(selection!.frameCount, 12);
    expect(selection!.frameDurationMs, 150);
  });

  testWidgets(
    'switching format keeps GIF draft and hides animation settings for SVG',
    (tester) async {
      await _pumpSelector(tester);
      await _open(tester);
      await tester.tap(find.byKey(const Key('format-option-gif')));
      await tester.pumpAndSettle();
      final frames = find.byKey(const Key('gif-frame-count'));
      await tester.ensureVisible(frames);
      await tester.enterText(frames, '16');
      final svg = find.byKey(const Key('format-option-svg'));
      await tester.ensureVisible(svg);
      await tester.tap(svg);
      await tester.pumpAndSettle();
      expect(frames, findsNothing);
      expect(
        find.text('GIF / SVG 需 GPT Image 2.6 或兼容模型 · Images API 文生图'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('format-option-gif')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(frames).controller!.text, '16');
    },
  );

  testWidgets(
    'hidden invalid GIF draft does not block a static format or overwrite saved animation',
    (tester) async {
      ImageFormatSettingsSelection? selection;
      await _pumpSelector(
        tester,
        format: ImageOutputFormat.gif,
        onSelected: (value) => selection = value,
      );
      await _open(tester);
      final frames = find.byKey(const Key('gif-frame-count'));
      await tester.ensureVisible(frames);
      await tester.enterText(frames, '');
      final png = find.byKey(const Key('format-option-png'));
      await tester.ensureVisible(png);
      await tester.tap(png);
      await tester.pumpAndSettle();
      expect(frames, findsNothing);
      await tester.tap(find.byKey(const Key('format-settings-apply')));
      await tester.pumpAndSettle();
      expect(selection!.format, ImageOutputFormat.png);
      expect(selection!.frameCount, 9);
      expect(selection!.frameDurationMs, 200);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(316, 562),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'format modal fits $size with reachable actions above keyboard',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pumpSelector(tester, format: ImageOutputFormat.gif);
        await _open(tester);
        final panel = tester.getRect(
          find.byKey(const Key('format-settings-panel')),
        );
        expect(panel.left, greaterThanOrEqualTo(0));
        expect(panel.right, lessThanOrEqualTo(size.width));
        expect(panel.top, greaterThanOrEqualTo(0));
        expect(panel.bottom, lessThanOrEqualTo(size.height));
        final frames = find.byKey(const Key('gif-frame-count'));
        final duration = find.byKey(const Key('gif-frame-duration'));
        await tester.ensureVisible(duration);
        await tester.pumpAndSettle();
        if (size.width < 360) {
          expect(
            tester.getRect(duration).top,
            greaterThan(tester.getRect(frames).bottom),
          );
        } else {
          expect(
            tester.getRect(duration).left,
            greaterThan(tester.getRect(frames).right),
          );
        }
        await tester.tap(duration);
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 600 ? 220 : 300,
        );
        await tester.pumpAndSettle();
        final apply = find.byKey(const Key('format-settings-apply'));
        expect(
          tester.getRect(apply).bottom,
          lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
        );
        expect(apply.hitTestable(), findsOneWidget);
        await tester.ensureVisible(duration);
        await tester.enterText(duration, '150');
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('format-settings-panel')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('format-settings-button')));
  await tester.pumpAndSettle();
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  ImageOutputFormat format = ImageOutputFormat.png,
  SvgOptions? svgOptions,
  ValueChanged<ImageFormatSettingsSelection>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppThemeTokens.primary),
      ),
      home: Scaffold(
        body: Center(
          child: ImageFormatSelector(
            selectedFormat: format,
            svgOptions: svgOptions,
            frameCount: 9,
            frameDurationMs: 200,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}
