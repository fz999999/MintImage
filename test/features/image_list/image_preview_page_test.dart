import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/features/image_list/image_preview_page.dart';

/// 1x1 透明 PNG，只要能被 Flutter 解码成一张图即可。
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late Directory tempDir;
  late String imagePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mint_preview_test');
    final file = File('${tempDir.path}${Platform.pathSeparator}coffee.png');
    file.writeAsBytesSync(_tinyPng);
    imagePath = file.path;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('预览页默认收起信息面板，只留左下角信息入口', (tester) async {
    await _pumpPreview(tester, imagePath);

    expect(find.byKey(const ValueKey('preview-info-collapsed')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-info-expanded')), findsNothing);
    // 尺寸/格式/模型/提示词都不该在首屏出现。
    expect(find.text('一张咖啡杯的产品图'), findsNothing);
    expect(find.text('PNG'), findsNothing);
    expect(find.text('gpt-image-2'), findsNothing);
  });

  testWidgets('点左下角信息按钮后展开，再点收起', (tester) async {
    await _pumpPreview(tester, imagePath);

    await tester.tap(find.byKey(const ValueKey('preview-info-collapsed')));
    await _settleSwitcher(tester);

    expect(find.byKey(const ValueKey('preview-info-expanded')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-info-collapsed')), findsNothing);
    expect(find.text('一张咖啡杯的产品图'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('gpt-image-2'), findsOneWidget);

    await tester.tap(find.byTooltip('收起'));
    await _settleSwitcher(tester);

    expect(find.byKey(const ValueKey('preview-info-collapsed')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-info-expanded')), findsNothing);
  });

  testWidgets('收起状态不写进设置，重新打开预览页仍是收起', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();

    await _pumpPreview(tester, imagePath, preferences: preferences);
    await tester.tap(find.byKey(const ValueKey('preview-info-collapsed')));
    await _settleSwitcher(tester);
    expect(find.byKey(const ValueKey('preview-info-expanded')), findsOneWidget);

    // 展开一次之后，设置里不该多出任何「信息面板已展开」的记忆项。
    final stored = preferences.getString('settings_model_v1');
    if (stored != null) {
      expect(stored.contains('previewInfoCollapsed'), isFalse);
    }

    // 重新进预览页（新的 widget 树），仍应默认收起。
    await tester.pumpWidget(const SizedBox.shrink());
    await _settleSwitcher(tester);
    await _pumpPreview(tester, imagePath, preferences: preferences);

    expect(find.byKey(const ValueKey('preview-info-collapsed')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-info-expanded')), findsNothing);
  });
}

/// AnimatedSwitcher 在动画结束的下一帧才移除旧子树，
/// 所以推进完时长后要再走一帧，否则会同时看到收起/展开两份。
Future<void> _settleSwitcher(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<void> _pumpPreview(
  WidgetTester tester,
  String imagePath, {
  SharedPreferences? preferences,
}) async {
  SharedPreferences? prefs = preferences;
  if (prefs == null) {
    SharedPreferences.setMockInitialValues(const {});
    prefs = await SharedPreferences.getInstance();
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSettingsModelProvider.overrideWithValue(_settings),
      ],
      child: MaterialApp(
        home: ImagePreviewPage(record: _record(imagePath)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

ImageRecord _record(String imagePath) => ImageRecord(
  id: 'preview-record',
  prompt: '一张咖啡杯的产品图',
  apiProfileId: 'api',
  sourceImagePath: null,
  sourceImagePaths: const [],
  resultImagePath: imagePath,
  resultImageUrl: null,
  resultB64: null,
  width: 1341,
  height: 1173,
  quality: 'auto',
  outputFormat: 'png',
  model: 'gpt-image-2',
  status: ImageRecordStatus.done,
  errorMessage: null,
  rawApiResponseValue: null,
  createdAt: DateTime(2026, 10, 21, 17),
  durationMs: 54700,
  usedSingleImageFallback: false,
  isFavorite: false,
);

final _settings = SettingsModel(
  profiles: [
    ApiProfile(
      id: 'api',
      name: 'API',
      baseUrl: 'https://api.openai.com',
      apiKey: 'test-key',
      model: 'gpt-image-2',
    ),
  ],
  activeProfileId: 'api',
);
