import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/core/providers/settings_provider.dart';
import 'package:mint_image/features/settings/image_api_section.dart';
import 'package:mint_image/shared/theme.dart';

void main() {
  testWidgets('provider rows fit narrow and desktop widths and filter active profile', (tester) async {
    final profiles = [
      ApiProfile(id: 'one', name: '万川', baseUrl: 'https://example.com', apiKey: '', models: ['gpt-image-2', 'second-model', 'third-model', 'fourth-model']),
      ApiProfile(id: 'two', name: 'Aihub', baseUrl: 'https://example.com/a/very/long/provider/path', apiKey: '', models: ['gpt-image-2.5-flare']),
    ];
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      initialSettingsModelProvider.overrideWithValue(SettingsModel(profiles: profiles, activeProfileId: 'one')),
    ]);
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final width in [1080.0, 600.0, 1400.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: SingleChildScrollView(child: ImageApiSection(onAdd: () {}, onEdit: (_) {}, onDelete: (_) {})))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'layout width $width');
    }
    expect(find.text('模型 · 4 个'), findsOneWidget);
    expect(find.textContaining('当前模型'), findsWidgets);
    expect(find.text('second-model'), findsOneWidget);
    expect(find.text('third-model'), findsOneWidget);
    expect(find.text('fourth-model'), findsOneWidget);
    expect(find.textContaining('更多模型'), findsNothing);
    expect(find.text('Aihub'), findsOneWidget);
    await tester.tap(find.text('当前使用 (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Aihub'), findsNothing);
    expect(find.text('万川'), findsOneWidget);
    await tester.tap(find.text('全部 (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为当前'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).activeProfileId, 'two');
    expect(tester.takeException(), isNull);
  });
}
