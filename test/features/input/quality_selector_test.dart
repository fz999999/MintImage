import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/features/input/quality_selector.dart';
import 'package:mint_image/features/input/quality_settings_modal.dart';
import 'package:mint_image/features/input/image_model_capability_badge.dart';
import 'package:mint_image/shared/theme.dart';

void main() {
  testWidgets(
    'quality and complexity are applied together and default can clear complexity',
    (tester) async {
      QualitySettingsSelection? selection;
      await _pumpSelector(
        tester,
        complexity: ImageComplexity.medium,
        onSelected: (value) => selection = value,
      );
      await _open(tester);
      expect(find.text('图像质量'), findsOneWidget);
      expect(find.text('规划复杂度'), findsOneWidget);
      expect(find.text('GIF 动画'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('quality-option-xhigh')));
      await tester.tap(find.byKey(const ValueKey('complexity-option-default')));
      expect(selection, isNull);
      await tester.tap(find.byKey(const Key('quality-settings-apply')));
      await tester.pumpAndSettle();
      expect(selection!.quality, ImageQuality.xhigh);
      expect(selection!.complexity, isNull);
    },
  );

  testWidgets('closing discards pending quality and complexity changes', (
    tester,
  ) async {
    QualitySettingsSelection? selection;
    await _pumpSelector(tester, onSelected: (value) => selection = value);
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('quality-option-max')));
    await tester.tap(find.byKey(const ValueKey('complexity-option-low')));
    await tester.tap(find.byKey(const Key('quality-settings-close')));
    await tester.pumpAndSettle();
    expect(selection, isNull);
    await _open(tester);
    final quality = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byKey(const ValueKey('quality-option-auto')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(quality.properties.selected, isTrue);
  });

  testWidgets(
    'advanced quality and complexity show quiet model badges with details on tap',
    (tester) async {
      await _pumpSelector(tester);
      await _open(tester);
      expect(find.byType(ImageModelCapabilityBadge), findsNWidgets(3));
      expect(find.text('2.6 标记项需 GPT Image 2.6 或兼容模型。'), findsOneWidget);
      for (final value in ['auto', 'low', 'medium', 'high']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('quality-option-$value')),
            matching: find.byType(ImageModelCapabilityBadge),
          ),
          findsNothing,
        );
      }
      for (final value in ['xhigh', 'max']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('quality-option-$value')),
            matching: find.byType(ImageModelCapabilityBadge),
          ),
          findsOneWidget,
        );
      }
      final badge = find.descendant(
        of: find.byKey(const Key('complexity-model-capability')),
        matching: find.byType(Tooltip),
      );
      final message = tester.widget<Tooltip>(badge).message!;
      expect(message, contains('规划复杂度 需 GPT Image 2.6 或兼容模型支持。'));
      expect(message, contains('选择“默认”时不发送复杂度参数'));
      expect(find.text(message), findsNothing);
      await tester.tap(badge);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      await tester.tap(find.byKey(const Key('quality-settings-close')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsNothing);
    },
  );

  testWidgets(
    'Responses mode keeps quality options without showing complexity',
    (tester) async {
      await _pumpSelector(tester, showComplexity: false);
      await _open(tester);
      expect(find.text('图像质量'), findsOneWidget);
      expect(find.text('规划复杂度'), findsNothing);
      expect(find.byKey(const ValueKey('quality-option-max')), findsOneWidget);
    },
  );

  for (final size in [
    const Size(316, 562),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'quality modal fits $size and keeps actions reachable with keyboard',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pumpSelector(tester);
        await _open(tester);
        final panel = tester.getRect(
          find.byKey(const Key('quality-settings-panel')),
        );
        expect(panel.left, greaterThanOrEqualTo(0));
        expect(panel.right, lessThanOrEqualTo(size.width));
        expect(panel.top, greaterThanOrEqualTo(0));
        expect(panel.bottom, lessThanOrEqualTo(size.height));
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 600 ? 220 : 300,
        );
        await tester.pumpAndSettle();
        final apply = tester.getRect(
          find.byKey(const Key('quality-settings-apply')),
        );
        expect(
          apply.bottom,
          lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
        );
        expect(
          find.byKey(const Key('quality-settings-apply')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quality-settings-button')));
  await tester.pumpAndSettle();
}

Future<void> _pumpSelector(
  WidgetTester tester, {
  bool showComplexity = true,
  ImageComplexity? complexity,
  ValueChanged<QualitySettingsSelection>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppThemeTokens.primary),
      ),
      home: Scaffold(
        body: Center(
          child: QualitySelector(
            selectedQuality: ImageQuality.auto,
            selectedComplexity: complexity,
            showComplexity: showComplexity,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}
