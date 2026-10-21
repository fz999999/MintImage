import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/core/providers/generation_provider.dart';
import 'package:mint_image/features/image_list/image_cell.dart';
import 'package:mint_image/features/image_list/image_preview_page.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Windows批选隐藏更多，右键和ShiftF10均不能打开单图菜单', (tester) async {
    var selections = 0;
    var previews = 0;
    var regenerated = 0;
    await _pumpCell(tester, selectionMode: true,
      onSelectionToggle: () => selections++,
      onPreview: () => previews++,
      onRegenerate: () => regenerated++,
    );
    expect(find.byTooltip('更多操作'), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);

    final imagePoint = tester.getTopLeft(find.byType(ImageCell)) + const Offset(120, 90);
    await tester.tapAt(imagePoint, buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('复用提示词'), findsNothing);
    expect(find.text('删除这条记录'), findsNothing);

    // Focus the card through its public Focus widget so the shortcut really
    // reaches the card even though batch selection removes the menu button.
    final cardFocus = find.descendant(of: find.byType(ImageCell), matching: find.byType(Focus)).first;
    tester.widget<Focus>(cardFocus).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('复用提示词'), findsNothing);
    expect(find.text('删除这条记录'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(selections, 0);
    expect(previews, 0);
    expect(regenerated, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows批选点击可预览的图片只切换选择，不导航或执行单图动作', (tester) async {
    var selections = 0;
    var previews = 0;
    var regenerated = 0;
    await _pumpCell(tester, selectionMode: true,
      onSelectionToggle: () => selections++,
      onPreview: () => previews++,
      onRegenerate: () => regenerated++,
    );
    final imagePoint = tester.getTopLeft(find.byType(ImageCell)) + const Offset(120, 90);
    await tester.tapAt(imagePoint);
    await tester.pumpAndSettle();
    expect(selections, 1);
    expect(previews, 0);
    expect(regenerated, 0);
    expect(find.byType(ImagePreviewPage), findsNothing);
    expect(find.text('复用提示词'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows普通图卡右键显示再生成，点击只回调一次并关闭菜单', (tester) async {
    var regenerated = 0;
    var previews = 0;
    var selections = 0;
    await _pumpCell(tester, selectionMode: false,
      record: _record.copyWith(status: ImageRecordStatus.done),
      onSelectionToggle: () => selections++,
      onPreview: () => previews++,
      onRegenerate: () => regenerated++,
    );
    expect(find.byTooltip('更多操作'), findsOneWidget);
    final imagePoint = tester.getTopLeft(find.byType(ImageCell)) + const Offset(120, 90);
    await tester.tapAt(imagePoint, buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('再生成一张'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(regenerated, 0);
    await tester.tap(find.text('再生成一张'));
    await tester.pumpAndSettle();
    expect(regenerated, 1);
    expect(previews, 0);
    expect(selections, 0);
    expect(find.text('再生成一张'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

Future<void> _pumpCell(WidgetTester tester, {
  required bool selectionMode,
  required VoidCallback onSelectionToggle,
  required VoidCallback onPreview,
  required VoidCallback onRegenerate,
  ImageRecord? record,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    initialSettingsModelProvider.overrideWithValue(SettingsModel(
      profiles: [ApiProfile(id: 'api', name: '测试API',
        baseUrl: 'https://example.invalid', apiKey: 'test-key', model: 'gpt-image-2')],
      activeProfileId: 'api',
    )),
    generationProvider.overrideWith((ref) => _IdleGenerationController(ref)),
  ], child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(
    width: 240, height: 300,
    child: ImageCell(
      record: record ?? _record,
      imageHeight: 180,
      onReusePrompt: () {},
      onReuseEdit: () {},
      onRegenerate: onRegenerate,
      onRetry: () {},
      onCancel: () {},
      onDelete: () {},
      onToggleFavorite: () {},
      onPreviewNavigation: (_) async { onPreview(); },
      selectionMode: selectionMode,
      selected: false,
      onSelectionToggle: onSelectionToggle,
      currentAttachmentCount: 0,
      onAppendCurrentImageToAttachments: () {},
    ),
  ))))));
  await tester.pumpAndSettle();
}

class _IdleGenerationController extends GenerationController {
  // The superclass parameter is private, so it cannot be a super parameter.
  // ignore: use_super_parameters
  _IdleGenerationController(Ref ref) : super(ref) {
    state = const GenerationState();
  }
}

final _record = ImageRecord(
  id: 'desktop-actions-record', prompt: '测试图卡', apiProfileId: 'api',
  sourceImagePath: null,
  // Enables the real preview action without decoding a file or using HTTP.
  sourceImagePaths: const ['missing-desktop-actions-test-image.png'],
  resultImagePath: null, resultImageUrl: null, resultB64: null,
  width: 1024, height: 1024, quality: 'medium', outputFormat: 'png',
  model: 'gpt-image-2', status: ImageRecordStatus.error,
  errorMessage: null, rawApiResponseValue: null,
  createdAt: DateTime(2026, 5, 30, 12), durationMs: 1200,
  usedSingleImageFallback: false, isFavorite: false,
);
