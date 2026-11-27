import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/core/providers/balance_provider.dart';
import 'package:mint_image/core/providers/settings_provider.dart';
import 'package:mint_image/core/services/file_drop_service.dart';
import 'package:mint_image/features/input/bottom_input_bar.dart';

import '../../shared/stub_balance_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validPngBytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  Directory createLocalTestTempDir(String prefix) {
    final baseDir = Directory(
      p.join(Directory.current.path, '.dart_tool', 'test_tmp'),
    )..createSync(recursive: true);
    final dir = baseDir.createTempSync(prefix);
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    return dir;
  }

  Future<GlobalKey<BottomInputBarState>> pumpInputBar(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final key = GlobalKey<BottomInputBarState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialSettingsModelProvider.overrideWithValue(_testSettings),
          balanceQueryApiProvider.overrideWithValue(const StubBalanceApi()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: BottomInputBar(
                key: key,
                onSubmit: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return key;
  }

  test('FileDropService parses dropped paths from method channel', () async {
    final received = <List<String>>[];
    final sub = FileDropService.instance.onFilesDropped.listen(received.add);
    addTearDown(sub.cancel);

    await FileDropService.instance.handleMethodCallForTest(
      const MethodCall('onFilesDropped', {
        'paths': [r'C:\images\a.png', '', r'C:\images\b.jpg'],
      }),
    );

    expect(received, [
      [r'C:\images\a.png', r'C:\images\b.jpg'],
    ]);
  });

  testWidgets('appends valid dropped images and ignores unsupported files', (
    tester,
  ) async {
    final tempDir = createLocalTestTempDir('mint_drop_test_');
    final pngFile = File(p.join(tempDir.path, 'one.png'))
      ..writeAsBytesSync(validPngBytes);
    final jpgFile = File(p.join(tempDir.path, 'two.jpg'))
      ..writeAsBytesSync(validPngBytes);
    final txtFile = File(p.join(tempDir.path, 'note.txt'))
      ..writeAsStringSync('not an image');

    final key = await pumpInputBar(tester);

    await tester.runAsync(() async {
      await key.currentState!.appendDroppedFiles([txtFile.path]);
    });
    await tester.pump();
    expect(key.currentState!.attachmentCount, 0);
    expect(find.text('仅支持拖入 PNG、JPG、JPEG、WEBP 图片。'), findsOneWidget);

    ScaffoldMessenger.of(
      tester.element(find.byType(BottomInputBar)),
    ).clearSnackBars();
    await tester.pump();

    await tester.runAsync(() async {
      await key.currentState!.appendDroppedFiles([
        pngFile.path,
        txtFile.path,
        jpgFile.path,
      ]);
    });
    await tester.pump();

    expect(key.currentState!.attachmentCount, 2);
    expect(find.text('已忽略 1 个不支持的文件。'), findsOneWidget);
  });

  testWidgets('caps dropped images at 8 attachments', (tester) async {
    final tempDir = createLocalTestTempDir('mint_drop_limit_');
    final paths = <String>[];
    for (var i = 0; i < 10; i++) {
      final file = File(p.join(tempDir.path, 'img_$i.png'))
        ..writeAsBytesSync(validPngBytes);
      paths.add(file.path);
    }

    final key = await pumpInputBar(tester);
    await tester.runAsync(() async {
      await key.currentState!.appendDroppedFiles(paths);
    });
    await tester.pump();

    expect(key.currentState!.attachmentCount, 8);
    expect(find.text('最多添加 8 张参考图'), findsOneWidget);
  });
}

final _testSettings = SettingsModel(
  profiles: [
    ApiProfile(
      id: 'api',
      name: '默认',
      baseUrl: 'https://api.openai.com',
      apiKey: 'test-key',
      models: const ['gpt-image-2'],
    ),
  ],
  activeProfileId: 'api',
);
