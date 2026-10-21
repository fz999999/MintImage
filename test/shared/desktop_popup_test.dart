import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_image/shared/widgets/desktop/desktop_dialog.dart';
import 'package:mint_image/shared/widgets/desktop/desktop_menu.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  _windowsTestWidgets('菜单选中标记跨搜索保留，禁用项不可提交，选择返回真实值', (tester) async {
    final results = <int?>[];
    await _pumpLauncher(tester, (context) async {
      results.add(await showDesktopMenu<int>(context: context, searchable: true,
        items: [
          const DesktopMenuItem(value: 0, label: '当前模型', selected: true),
          const DesktopMenuItem(value: 1, label: '不可用模型', enabled: false),
          for (var i = 2; i < 12; i++) DesktopMenuItem(value: i, label: '模型 $i'),
        ],
      ));
    });
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: find.ancestor(of: find.text('当前模型'), matching: find.byType(InkWell)).first,
      matching: find.byIcon(Icons.check),
    ), findsOneWidget);
    await tester.tap(find.text('不可用模型'));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '模型 9');
    await tester.pumpAndSettle();
    expect(find.text('当前模型'), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is Text && widget.data == '模型 9'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: find.ancestor(of: find.text('当前模型'), matching: find.byType(InkWell)).first,
      matching: find.byIcon(Icons.check),
    ), findsOneWidget);
    await tester.enterText(find.byType(TextField), '模型 9');
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Text && widget.data == '模型 9'));
    await tester.pumpAndSettle();
    expect(results, [9]);
  });

  _windowsTestWidgets('菜单方向键跳过禁用项，Enter只提交当前可用项', (tester) async {
    final results = <int?>[];
    await _pumpLauncher(tester, (context) async {
      results.add(await showDesktopMenu<int>(context: context, items: const [
        DesktopMenuItem(value: 10, label: '当前项', selected: true),
        DesktopMenuItem(value: 20, label: '禁用项', enabled: false),
        DesktopMenuItem(value: 30, label: '下一项'),
      ]));
    });
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(results, [30]);
  });

  _windowsTestWidgets('菜单Esc和外部点击返回null，关闭手势不触发背景操作', (tester) async {
    final results = <int?>[];
    var outsideTaps = 0;
    await _pumpLauncher(tester, (context) async {
      results.add(await showDesktopMenu<int>(context: context,
        items: const [DesktopMenuItem(value: 3, label: '选择三')],
      ));
    }, onOutsideTap: () => outsideTaps++);
    final outside = tester.getCenter(find.byKey(const Key('outside-action')));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, [null]);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tapAt(outside);
    await tester.pumpAndSettle();
    expect(results, [null, null]);
    expect(outsideTaps, 0);
    await tester.tapAt(outside);
    await tester.pump();
    expect(outsideTaps, 1);
  });

  _windowsTestWidgets('440×320与1.5倍文本下长菜单可滚动选择，无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(440, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final results = <int?>[];
    await _pumpLauncher(tester, (context) async {
      results.add(await showDesktopMenu<int>(context: context, searchable: true,
        items: [for (var i = 0; i < 40; i++)
          DesktopMenuItem(value: i, label: '长列表选项 $i')],
      ));
    }, textScale: 1.5);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('长列表选项 39'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('长列表选项 39'));
    await tester.pumpAndSettle();
    expect(results, [39]);
    expect(tester.takeException(), isNull);
  });

  _windowsTestWidgets('440×320与1.5倍文本下长确认文案可滚动且取消始终可用', (tester) async {
    tester.view.physicalSize = const Size(440, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final results = <bool>[];
    await _pumpLauncher(tester, (context) async {
      results.add(await showDesktopConfirm(context: context, title: '确认删除',
        message: List.generate(40, (i) => '第$i行：删除后无法恢复，请确认图片。').join('\n'),
      ));
    }, textScale: 1.5);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(tester.takeException(), isNull);
  });

  _windowsTestWidgets('危险确认默认焦点在取消，直接Enter不会执行删除', (tester) async {
    final results = <bool>[];
    var deleted = 0;
    await _pumpLauncher(tester, (context) async {
      final confirmed = await showDesktopConfirm(
        context: context, title: '删除图片', message: '此操作不能撤销',
      );
      results.add(confirmed);
      if (confirmed) deleted++;
    });
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final cancel = find.widgetWithText(TextButton, '取消');
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextButton>(),
      same(tester.widget<TextButton>(cancel)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(deleted, 0);
    expect(results, [false]);
    expect(find.byType(Dialog), findsNothing);
  });

  _windowsTestWidgets('危险确认Esc返回false，只有显式点击删除才返回true', (tester) async {
    final results = <bool>[];
    await _pumpLauncher(tester, (context) async {
      results.add(await showDesktopConfirm(
        context: context, title: '删除图片', message: '此操作不能撤销',
      ));
    });
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, [false]);

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });
}

// Let flutter_test restore the override before its debug-variable invariant check.
void _windowsTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, callback,
    variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  Future<void> Function(BuildContext) onOpen, {
  VoidCallback? onOutsideTap,
  double textScale = 1,
}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: Stack(children: [
    Align(alignment: Alignment.topLeft, child: TextButton(
      key: const Key('outside-action'),
      onPressed: onOutsideTap ?? () {}, child: const Text('背景操作'),
    )),
    Align(alignment: Alignment.bottomCenter, child: Padding(
      padding: const EdgeInsets.all(16),
      child: Builder(builder: (context) => TextButton(
        onPressed: () => onOpen(context), child: const Text('打开'),
      )),
    )),
  ]))));
  await tester.pumpAndSettle();
}
