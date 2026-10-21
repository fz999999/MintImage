import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_image/features/settings/api_configuration_row.dart';
import 'package:mint_image/shared/theme.dart';

void main() {
  testWidgets('configuration row adapts without overflow and omits unavailable balance', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.5]) {
      for (final width in [320.0, 600.0, 620.0, 652.0, 760.0, 820.0, 962.0, 1080.0, 1440.0, 1472.0]) {
        tester.view.physicalSize = Size(width, 1200);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: SingleChildScrollView(child: ApiConfigurationRow(
              name: '很长的服务商名称 · API configuration',
              protocol: 'OpenAI Images',
              url: 'https://example.com/a/very/long/provider/path',
              models: const ['gpt-image-2', 'second-model', 'third-model'],
              currentModel: 'gpt-image-2',
              isActive: false,
              onEnable: () {}, onEdit: () {}, onDelete: () {},
              onTest: () {},
            ))),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width px / $scale text');
        expect(find.textContaining('账户余额', findRichText: true), findsNothing);
        expect(find.text('备用'), findsOneWidget);
        expect(find.text('second-model'), findsOneWidget);
        expect(find.text('third-model'), findsOneWidget);
        expect(find.textContaining('更多模型'), findsNothing);
        final editRect = tester.getRect(find.text('编辑'));
        final nameRect = tester.getRect(find.text('很长的服务商名称 · API configuration'));
        expect(nameRect.width, greaterThan(120),
          reason: 'name keeps readable space at $width px / $scale text');
        if (width == 820 && scale == 1) {
          expect((editRect.top - nameRect.top).abs(), lessThan(30),
            reason: 'regular desktop actions stay on the name row');
        }
        if (width == 320) {
          expect(tester.getRect(find.text('设为当前')).left, lessThan(60),
            reason: 'narrow actions start on the left without an empty right-aligned row');
        }
      }
    }
  });

  testWidgets('configuration actions, model anchor and URL copy remain independent', (tester) async {
    var enabled = 0;
    var edited = 0;
    var deleted = 0;
    var tested = 0;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApiConfigurationRow(
      name: 'Provider', protocol: 'OpenAI', url: 'https://example.com',
      models: const ['one', 'two', 'three', 'four', 'five', 'six'], isActive: false,
      onEnable: () => enabled++, onEdit: () => edited++,
      onDelete: () => deleted++, onTest: () => tested++,
    ))));
    await tester.tap(find.text('设为当前'));
    await tester.tap(find.text('编辑'));
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试连接'));
    expect(find.text('four'), findsOneWidget);
    expect(find.text('five'), findsNothing);
    await tester.tap(find.text('更多模型 (2)'));
    await tester.pumpAndSettle();
    expect(find.text('five'), findsOneWidget);
    expect(find.text('six'), findsOneWidget);
    expect(find.text('four'), findsOneWidget);
    await tester.tap(find.text('收起更多模型'));
    await tester.pumpAndSettle();
    expect(find.text('five'), findsNothing);
    expect(find.text('four'), findsOneWidget);
    await tester.tap(find.byTooltip('复制 API 地址'));
    await tester.pump();
    expect([enabled, edited, deleted, tested], [1, 1, 1, 1]);
    expect(copied, 'https://example.com');
    expect(find.text('API 地址已复制'), findsOneWidget);
  });

  testWidgets('active state is singular and optional operations respect availability', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApiConfigurationRow(
      name: 'Active', protocol: 'OpenAI', url: 'https://example.com',
      models: const ['one'], isActive: true, canDelete: false, balance: null,
      onEnable: () {}, onEdit: () {}, onDelete: () {},
    ))));
    expect(find.text('当前使用'), findsOneWidget);
    expect(find.text('设为当前'), findsNothing);
    expect(find.text('测试连接'), findsNothing);
    expect(find.textContaining('账户余额', findRichText: true), findsNothing);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    final delete = tester.widget<PopupMenuItem<String>>(find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<String>));
    expect(delete.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
