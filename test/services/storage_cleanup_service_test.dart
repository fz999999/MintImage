import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/database/app_database.dart';
import 'package:mint_image/core/database/image_record_dao.dart';
import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/services/storage_cleanup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory documents;
  late Directory temporary;
  late AppDatabase database;
  late ImageRecordDao dao;
  final now = DateTime(2026, 11, 5, 12);
  final old = now.subtract(const Duration(days: 1));

  File write(Directory base, String path, {DateTime? modified, int size = 4}) {
    final file = File(p.normalize(p.join(base.path, path)))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(size, 1));
    file.setLastModifiedSync(modified ?? old);
    return file;
  }

  StorageCleanupService service() => StorageCleanupService(
    imageRecordDao: dao,
    documentsDirectory: () async => documents,
    temporaryDirectory: () async => temporary,
    now: () => now,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('storage-cleanup-');
    documents = Directory(p.join(root.path, 'documents'))..createSync();
    temporary = Directory(p.join(root.path, 'temp'))..createSync();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ImageRecordDao(database);
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  test('only unreferenced, settled app files are planned', () async {
    final keptResult = write(documents, 'generated_images/kept.png');
    final keptSource = write(documents, 'restored_source_attachments/r1/0.png');
    final keptMarkup = write(documents, 'markup_attachments/kept.png');
    final draftMarkup = write(documents, 'markup_attachments/draft.png');
    final orphanResult = write(documents, 'generated_images/orphan.png');
    final orphanSource = write(
      documents,
      'restored_source_attachments/gone/0.png',
      size: 10,
    );
    final orphanMarkup = write(documents, 'markup_attachments/orphan.png');
    final freshResult = write(
      documents,
      'generated_images/fresh.png',
      modified: now.subtract(const Duration(minutes: 2)),
    );
    final unrelated = write(documents, 'user_notes/readme.txt');
    final clipboard = write(temporary, 'mint_image_clipboard_r1.png');
    final download = write(temporary, 'mint_image_latest.mintbackup');
    final foreignTemp = write(temporary, 'other_app_cache.bin');
    final backup = write(temporary, 'mint_image_backups/snapshot.mintbackup');

    await dao.upsert(
      ImageRecord(
        id: 'r1',
        prompt: 'leaf',
        apiProfileId: 'profile',
        sourceImagePath: null,
        // Mixed separators and case must still match on Windows.
        sourceImagePaths: [
          Platform.isWindows
              ? keptSource.path.replaceAll(r'\', '/').toUpperCase()
              : keptSource.path,
        ],
        resultImagePath: keptResult.path,
        resultImageUrl: null,
        resultB64: null,
        width: 1024,
        height: 1024,
        quality: 'low',
        outputFormat: 'png',
        markupPath: keptMarkup.path,
        model: 'gpt-image-2',
        status: ImageRecordStatus.done,
        errorMessage: null,
        rawApiResponseValue: null,
        createdAt: now,
        durationMs: 1,
        usedSingleImageFallback: false,
        isFavorite: false,
      ),
    );

    final plan = await service().scan(keep: {draftMarkup.path});
    List<String> paths(StorageCleanupCategory category) =>
        plan.files[category]!.map((file) => file.path).toList()..sort();

    expect(paths(StorageCleanupCategory.markup), [orphanMarkup.path]);
    expect(
      paths(StorageCleanupCategory.images),
      [orphanResult.path, orphanSource.path]..sort(),
    );
    expect(
      paths(StorageCleanupCategory.temporary),
      [clipboard.path, download.path]..sort(),
    );
    expect(paths(StorageCleanupCategory.backups), [backup.path]);
    expect(plan.bytes(StorageCleanupCategory.images), 14);

    final result = await service().clean(plan, {
      StorageCleanupCategory.markup,
      StorageCleanupCategory.images,
      StorageCleanupCategory.temporary,
    });
    expect(result.deletedFiles, 5);
    expect(result.freedBytes, 26);
    for (final file in [orphanResult, orphanSource, orphanMarkup, clipboard]) {
      expect(file.existsSync(), isFalse, reason: file.path);
    }
    for (final file in [
      keptResult,
      keptSource,
      keptMarkup,
      draftMarkup,
      freshResult,
      unrelated,
      foreignTemp,
      backup,
    ]) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
  });

  test('missing directories yield an empty plan', () async {
    final plan = await service().scan();
    expect(plan.isEmpty, isTrue);
  });
}
