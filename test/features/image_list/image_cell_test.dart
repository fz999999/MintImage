import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/core/providers/generation_provider.dart';
import 'package:mint_image/features/image_list/image_cell.dart';
import 'package:mint_image/features/image_list/image_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows error details when tapping failed status pill', (
    tester,
  ) async {
    await _pumpImageCell(
      tester,
      _record.copyWith(errorMessage: '接口返回 429：额度不足'),
    );

    await tester.tap(find.text('失败'));
    await tester.pumpAndSettle();

    expect(find.text('失败原因'), findsOneWidget);
    expect(find.text('接口返回 429：额度不足'), findsOneWidget);
  });

  testWidgets('shows regenerate action for completed records', (tester) async {
    var regenerated = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onRegenerate: () {
        regenerated = true;
      },
    );

    await tester.longPress(find.byType(ImageCell));
    await tester.pumpAndSettle();

    expect(find.text('再生成一张'), findsOneWidget);
    await tester.tap(find.text('再生成一张'));
    await tester.pumpAndSettle();

    expect(regenerated, isTrue);
  });

  testWidgets('shows append attachment action when record has a local image', (
    tester,
  ) async {
    var appended = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: [File('pubspec.yaml').absolute.path],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onAppendCurrentImageToAttachments: () {
        appended = true;
      },
    );

    await tester.longPress(find.byType(ImageCell));
    await tester.pumpAndSettle();

    expect(find.text('将此图添加到附件1'), findsOneWidget);
    await tester.tap(find.text('将此图添加到附件1'));
    await tester.pumpAndSettle();

    expect(appended, isTrue);
  });

  testWidgets('opens preview through preview navigation callback', (
    tester,
  ) async {
    var navigatedThroughCallback = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onPreviewNavigation: (navigate) async {
        navigatedThroughCallback = true;
        await navigate();
      },
    );

    final cellTopLeft = tester.getTopLeft(find.byType(ImageCell));
    await tester.tapAt(cellTopLeft + const Offset(120, 90));
    await tester.pumpAndSettle();

    expect(navigatedThroughCallback, isTrue);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
  });
  testWidgets('shows the streamed preview while an image is still loading', (
    tester,
  ) async {
    // 1x1 透明 PNG，只要能解码成一张图即可。
    final preview = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
      'hQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    await _pumpImageCell(
      tester,
      _record.copyWith(status: ImageRecordStatus.loading),
      partialImages: {'record-error': preview},
    );
    await tester.pump();

    expect(find.text('正在生成'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('keeps the spinner when no preview has arrived yet', (
    tester,
  ) async {
    await _pumpImageCell(
      tester,
      _record.copyWith(status: ImageRecordStatus.loading),
    );

    expect(find.text('正在生成'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('hover lifts the card by 1px', (tester) async {
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        errorMessage: null,
        clearErrorMessage: true,
      ),
    );

    // hover 上移 1px 作用在卡片内部的 Transform 上，用内容来量位移。
    final promptText = find.text('一张城市夜景');
    final beforeHover = tester.getTopLeft(promptText);
    await _hoverOverCell(tester);

    // hover 时整张卡轻微上移 1px。
    final afterHover = tester.getTopLeft(promptText);
    expect(afterHover.dy, closeTo(beforeHover.dy - 1, 0.5));
  });

  testWidgets('card actions stay hidden until the pointer dwells, then sit in '
      'the footer', (tester) async {
    var navigatedThroughCallback = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onPreviewNavigation: (navigate) async {
        navigatedThroughCallback = true;
        await navigate();
      },
    );

    await _hoverOverCell(tester, settle: false);

    // 刚进入卡片时不出现动作钮，此时点「预览」不应命中，避免误触。
    expect(_actionOpacity(tester, '预览'), 0);
    await tester.tap(find.byTooltip('预览'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(navigatedThroughCallback, isFalse);

    // 停留满 240ms 之后三个动作才淡入。
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(_actionOpacity(tester, '预览'), 1);
    expect(_actionOpacity(tester, '保存到本地'), 1);
    expect(_actionOpacity(tester, '复制'), 1);

    // 动作钮在文字区（图片高 180），不再压住图片中央。
    final cardRect = tester.getRect(find.byType(ImageCell));
    final previewRect = tester.getRect(find.byTooltip('预览'));
    expect(previewRect.top, greaterThan(cardRect.top + 180));

    await tester.tap(find.byTooltip('预览'));
    await tester.pumpAndSettle();

    expect(navigatedThroughCallback, isTrue);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
  });

  testWidgets('card actions hide again when the pointer leaves', (
    tester,
  ) async {
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        errorMessage: null,
        clearErrorMessage: true,
      ),
    );

    await _hoverOverCell(tester);
    expect(_actionOpacity(tester, '预览'), 1);

    final mouse = _activeMouse;
    await mouse!.moveTo(Offset.zero);
    await tester.pump();
    expect(_actionOpacity(tester, '预览'), 0);
  });
}

/// 让鼠标指针从卡片外部移进卡片中心，触发 MouseRegion.onEnter。
/// [settle] 为 false 时只推进一帧，用于观察延迟出现前的状态。
Future<void> _hoverOverCell(WidgetTester tester, {bool settle = true}) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  _activeMouse = mouse;
  await tester.pump();
  await mouse.moveTo(tester.getCenter(find.byType(ImageCell)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

TestGesture? _activeMouse;

class _SeededGenerationController extends GenerationController {
  // 基类构造参数是私有的 `_ref`，无法用 super 参数转发。
  // ignore: use_super_parameters
  _SeededGenerationController(Ref ref, GenerationState initial) : super(ref) {
    state = initial;
  }
}

Future<void> _pumpImageCell(
  WidgetTester tester,
  ImageRecord record, {
  VoidCallback? onRegenerate,
  VoidCallback? onAppendCurrentImageToAttachments,
  Future<void> Function(Future<void> Function() navigate)? onPreviewNavigation,
  Map<String, Uint8List> partialImages = const {},
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSettingsModelProvider.overrideWithValue(_settings),
        generationProvider.overrideWith(
          (ref) => _SeededGenerationController(
            ref,
            GenerationState(partialImages: partialImages),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 300,
              child: ImageCell(
                record: record,
                imageHeight: 180,
                onReusePrompt: () {},
                onReuseEdit: () {},
                onRegenerate: onRegenerate ?? () {},
                onRetry: () {},
                onCancel: () {},
                onDelete: () {},
                onToggleFavorite: () {},
                onPreviewNavigation:
                    onPreviewNavigation ?? (navigate) => navigate(),
                selectionMode: false,
                selected: false,
                onSelectionToggle: () {},
                currentAttachmentCount: 0,
                onAppendCurrentImageToAttachments:
                    onAppendCurrentImageToAttachments ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 取动作钮外层 AnimatedOpacity 的目标透明度（0=没出现，1=已出现）。
double _actionOpacity(WidgetTester tester, String tooltip) {
  final opacity = tester.widget<AnimatedOpacity>(
    find
        .ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(AnimatedOpacity),
        )
        .first,
  );
  return opacity.opacity;
}

final _settings = SettingsModel(
  profiles: [_apiProfile],
  activeProfileId: 'api',
);

final _apiProfile = ApiProfile(
  id: 'api',
  name: 'API',
  baseUrl: 'https://api.openai.com',
  apiKey: 'test-key',
  model: 'gpt-image-2',
);

final _record = ImageRecord(
  id: 'record-error',
  prompt: '一张城市夜景',
  apiProfileId: 'api',
  sourceImagePath: null,
  sourceImagePaths: const [],
  resultImagePath: null,
  resultImageUrl: null,
  resultB64: null,
  width: 1024,
  height: 1024,
  quality: 'medium',
  outputFormat: 'png',
  model: 'gpt-image-2',
  status: ImageRecordStatus.error,
  errorMessage: null,
  rawApiResponseValue: null,
  createdAt: DateTime(2026, 5, 30, 12),
  durationMs: 1200,
  usedSingleImageFallback: false,
  isFavorite: false,
);
