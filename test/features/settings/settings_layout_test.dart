import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/features/settings/api_profile_edit_page.dart';
import 'package:mint_image/features/settings/prompt_optimization_profile_edit_page.dart';
import 'package:mint_image/features/settings/settings_page.dart';
import 'package:mint_image/shared/theme.dart';

void main() {
  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final value = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      initialSettingsModelProvider.overrideWithValue(SettingsModel(
        profiles: [ApiProfile(id: 'image', name: '生图服务', baseUrl: 'https://example.com', apiKey: '', models: ['gpt-image-2'])],
        activeProfileId: 'image',
        promptOptimizationProfiles: [PromptOptimizationProfile(id: 'prompt', name: '优化服务', baseUrl: 'https://example.com', apiKey: '', model: 'gpt-4.1', protocol: PromptOptimizationProtocol.openAiResponses)],
        activePromptOptimizationProfileId: 'prompt',
      )),
    ]);
    addTearDown(value.dispose);
    return value;
  }

  Future<void> mount(WidgetTester tester, ProviderContainer state, Widget page,
      {double width = 1600, double height = 1000, double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: state,
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('settings keep intended order, centered width and neutral backup actions', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await container();
    await mount(tester, state, const SettingsPage(), height: 2400);
    final headings = ['生图 API', '提示词优化 API', '生成设置', '备份与数据管理', '关于 大川生图工具'];
    var previous = -1.0;
    for (final heading in headings) {
      final position = tester.getTopLeft(find.text(heading));
      expect(position.dy, greaterThan(previous));
      previous = position.dy;
    }
    final backup = find.ancestor(of: find.text('从文件恢复'), matching: find.byType(OutlinedButton));
    expect(backup, findsOneWidget);
    final timeoutField = find.byType(TextField);
    final card = find.ancestor(of: timeoutField, matching: find.byType(Container)).first;
    expect(tester.getSize(card).width, lessThanOrEqualTo(1120));
    expect(find.textContaining('账户余额', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit forms center at 880 and keep full-width gutter scrolling', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await container();
    for (final page in [const ApiProfileEditPage(), const PromptOptimizationProfileEditPage()]) {
      await mount(tester, state, page, height: 500);
      final field = find.byType(TextFormField).first;
      expect(tester.getSize(field).width, lessThanOrEqualTo(880));
      expect(tester.getCenter(field).dx, closeTo(800, 1));
      Offset? savePosition;
      if (page is ApiProfileEditPage) {
        expect(find.text('取消'), findsOneWidget);
        savePosition = tester.getCenter(find.text('添加并使用'));
        expect(savePosition.dy, lessThan(500));
      }
      final scrollable = find.byType(Scrollable).first;
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      await tester.dragFrom(const Offset(40, 380), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, greaterThan(before));
      if (savePosition != null) {
        expect(tester.getCenter(find.text('添加并使用')), savePosition);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty optimization and unconfigured cloud actions remain clear', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final state = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      initialSettingsModelProvider.overrideWithValue(SettingsModel.initial()),
    ]);
    addTearDown(state.dispose);
    await mount(tester, state, const SettingsPage(), height: 2400);
    expect(find.text('尚未配置提示词优化'), findsOneWidget);
    expect(find.text('添加提示词优化 API'), findsOneWidget);
    for (final label in ['同步到 WebDAV', '从 WebDAV 恢复']) {
      final button = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text(label), matching: find.byType(OutlinedButton)));
      expect(button.onPressed, isNull);
    }
    expect(find.text('删除所有生成记录，保留 API 配置。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings and editors fit narrow screens with enlarged text', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await container();
    for (final page in [const SettingsPage(), const ApiProfileEditPage(), const PromptOptimizationProfileEditPage()]) {
      await mount(tester, state, page, width: 600, height: 1200, scale: 1.5);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page');
    }
  });
}
