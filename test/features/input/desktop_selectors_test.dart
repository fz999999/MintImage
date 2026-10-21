import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_image/features/input/quantity_selector.dart';
import 'package:mint_image/features/input/size_selector.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  _windowsTestWidgets('数量空输入及17显示错误并禁用确定，不提交旧数量', (tester) async {
    final values = <int>[];
    await _pumpSelector(tester, QuantitySelector(count: 4, onSelected: values.add));
    await tester.tap(find.byType(QuantitySelector));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('请输入生成数量'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确定')).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(values, isEmpty);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '17');
    await tester.pumpAndSettle();
    expect(find.text('生成数量须在 1–16 之间'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确定')).onPressed, isNull);
    expect(values, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(values, isEmpty);
  });

  for (final count in [1, 7, 16]) {
    _windowsTestWidgets('数量$count在1–16范围内仅确定后回调一次', (tester) async {
      final values = <int>[];
      await _pumpSelector(tester, QuantitySelector(count: 4, onSelected: values.add));
      await tester.tap(find.byType(QuantitySelector));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '$count');
      await tester.pumpAndSettle();
      expect(values, isEmpty);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确定')).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();
      expect(values, [count]);
      expect(find.byType(TextField), findsNothing);
    });
  }

  _windowsTestWidgets('数量草稿按取消、Esc或外部点击均不提交，外部点击不穿透', (tester) async {
    final values = <int>[];
    var outsideTaps = 0;
    await _pumpSelector(tester, QuantitySelector(count: 4, onSelected: values.add),
      onOutsideTap: () => outsideTaps++);
    final outside = tester.getCenter(find.byKey(const Key('outside-action')));

    for (final dismissal in ['取消', 'Esc', '外部']) {
      await tester.tap(find.byType(QuantitySelector));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8');
      await tester.pumpAndSettle();
      if (dismissal == '取消') {
        await tester.tap(find.text('取消'));
      } else if (dismissal == 'Esc') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.tapAt(outside);
      }
      await tester.pumpAndSettle();
      expect(values, isEmpty, reason: dismissal);
      expect(find.byType(TextField), findsNothing);
    }
    expect(outsideTaps, 0);
    await tester.tapAt(outside);
    await tester.pump();
    expect(outsideTaps, 1);
  });

  _windowsTestWidgets('尺寸先显示快捷菜单，更多尺寸才打开Dialog，取消不回调', (tester) async {
    final sizes = <(int, int)>[];
    await _pumpSelector(tester, SizeSelector(currentWidth: 1024, currentHeight: 1024,
      onSizeSelected: (w, h) => sizes.add((w, h))));
    await tester.tap(find.byType(SizeSelector));
    await tester.pumpAndSettle();
    expect(find.text('更多尺寸…'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('更多尺寸…'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('设置图像尺寸'), findsOneWidget);
    expect(sizes, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(sizes, isEmpty);
  });

  _windowsTestWidgets('尺寸自定义空值、非整数和零不静默回退1024，修正后才提交', (tester) async {
    final sizes = <(int, int)>[];
    await _pumpSelector(tester, SizeSelector(currentWidth: 1024, currentHeight: 1024,
      onSizeSelected: (w, h) => sizes.add((w, h))));
    await tester.tap(find.byType(SizeSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多尺寸…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    final width = find.widgetWithText(TextField, '宽度');
    final height = find.widgetWithText(TextField, '高度');
    for (final entry in [('', '请输入宽度和高度'), ('abc', '宽高须为整数'), ('0', '宽高须大于 0')]) {
      await tester.enterText(width, entry.$1);
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确定')).onPressed, isNull);
      expect(sizes, isEmpty);
      expect(find.byType(Dialog), findsOneWidget);
    }
    await tester.enterText(width, '1536');
    await tester.enterText(height, '1024');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();
    expect(sizes, [(1536, 1024)]);
  });

  _windowsTestWidgets('尺寸快捷项直接提交，无需打开完整Dialog', (tester) async {
    final sizes = <(int, int)>[];
    await _pumpSelector(tester, SizeSelector(currentWidth: 1024, currentHeight: 1024,
      onSizeSelected: (w, h) => sizes.add((w, h))));
    await tester.tap(find.byType(SizeSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3:2 · 1K'));
    await tester.pumpAndSettle();
    expect(sizes, [(1536, 1024)]);
    expect(find.byType(Dialog), findsNothing);
  });
}

// Let flutter_test restore the override before its debug-variable invariant check.
void _windowsTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, callback,
    variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

Future<void> _pumpSelector(WidgetTester tester, Widget selector, {
  VoidCallback? onOutsideTap,
}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [
    Align(alignment: Alignment.topLeft, child: TextButton(
      key: const Key('outside-action'),
      onPressed: onOutsideTap ?? () {}, child: const Text('背景操作'),
    )),
    Align(alignment: Alignment.bottomCenter, child: Padding(
      padding: const EdgeInsets.all(24), child: selector,
    )),
  ]))));
  await tester.pumpAndSettle();
}
