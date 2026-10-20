import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../services/app_paths.dart';

part 'app_database.g.dart';

const _databaseFileName = 'mint_image.sqlite';
const _legacyDatabaseFileName = 'gpt_image_flutter.sqlite';

class ImageRecordsTable extends Table {
  TextColumn get id => text()();

  TextColumn get prompt => text()();

  TextColumn get apiProfileId => text().withDefault(const Constant(''))();

  TextColumn get sourceImagePath => text().nullable()();

  TextColumn get sourceImagePaths => text().nullable()();

  TextColumn get resultImagePath => text().nullable()();

  TextColumn get resultImageUrl => text().nullable()();

  TextColumn get resultB64 => text().nullable()();

  IntColumn get width => integer()();

  IntColumn get height => integer()();

  TextColumn get quality => text()();

  TextColumn get outputFormat => text().withDefault(const Constant('png'))();

  TextColumn get model => text()();

  TextColumn get status => text()();

  TextColumn get errorMessage => text().nullable()();

  TextColumn get rawApiResponseValue => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get durationMs => integer().nullable()();

  BoolColumn get usedSingleImageFallback =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FavoriteFoldersTable extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FavoriteFolderItemsTable extends Table {
  TextColumn get folderId => text().references(
    FavoriteFoldersTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get recordId =>
      text().references(ImageRecordsTable, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {folderId, recordId};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 统一走 AppPaths：Windows 便携模式下是 exe 同级的 data 目录，
    // 避免低完整性级别进程被拒绝写入 %APPDATA%。
    final directory = await AppPaths.dataRoot();
    final file = File(p.join(directory.path, _databaseFileName));
    await _copyLegacyDatabaseIfNeeded(directory, file);
    return NativeDatabase.createInBackground(file);
  });
}

Future<void> _copyLegacyDatabaseIfNeeded(Directory directory, File file) async {
  if (await file.exists()) {
    return;
  }

  final legacyFile = File(p.join(directory.path, _legacyDatabaseFileName));
  if (await legacyFile.exists()) {
    await _copyDatabaseFiles(legacyFile, file);
    return;
  }

  // 便携化升级：新版数据库在 exe 同级 data 目录，旧版在 `%APPDATA%`。
  // 新位置为空时把旧库整体搬过来，避免用户升级后历史记录消失。
  final legacyRoot = AppPaths.legacyDataRoot();
  if (legacyRoot == null) {
    return;
  }

  final legacyPortable = File(p.join(legacyRoot.path, _databaseFileName));
  if (await legacyPortable.exists()) {
    await _copyDatabaseFiles(legacyPortable, file);
  }
}

/// 复制数据库主文件与 WAL 副文件。
Future<void> _copyDatabaseFiles(File source, File target) async {
  await source.copy(target.path);
  for (final suffix in ['-wal', '-shm']) {
    final sidecar = File('${source.path}$suffix');
    if (await sidecar.exists()) {
      await sidecar.copy('${target.path}$suffix');
    }
  }
}

@DriftDatabase(
  tables: [ImageRecordsTable, FavoriteFoldersTable, FavoriteFolderItemsTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await _addColumnIfMissing(
          migrator,
          imageRecordsTable,
          imageRecordsTable.apiProfileId,
        );
        await _addColumnIfMissing(
          migrator,
          imageRecordsTable,
          imageRecordsTable.usedSingleImageFallback,
        );
      }
      if (from < 3) {
        await _addColumnIfMissing(
          migrator,
          imageRecordsTable,
          imageRecordsTable.rawApiResponseValue,
        );
      }
      if (from < 4) {
        await _addColumnIfMissing(
          migrator,
          imageRecordsTable,
          imageRecordsTable.sourceImagePaths,
        );
      }
      if (from < 5) {
        await _addColumnIfMissing(
          migrator,
          imageRecordsTable,
          imageRecordsTable.isFavorite,
        );
      }
      if (from < 6) {
        await _createTableIfMissing(migrator, favoriteFoldersTable);
        await _createTableIfMissing(migrator, favoriteFolderItemsTable);
      }
      if (from < 7) {
        await _addColumnIfMissing(
          migrator,
          imageRecordsTable,
          imageRecordsTable.outputFormat,
        );
        await _backfillOutputFormat();
      }
    },
  );

  Future<void> _backfillOutputFormat() async {
    await customStatement('''
      UPDATE image_records_table
      SET output_format = CASE
        WHEN lower(coalesce(result_image_path, '') || ' ' || coalesce(result_image_url, '')) LIKE '%.webp%'
          THEN 'webp'
        WHEN lower(coalesce(result_image_path, '') || ' ' || coalesce(result_image_url, '')) LIKE '%.jpg%'
          OR lower(coalesce(result_image_path, '') || ' ' || coalesce(result_image_url, '')) LIKE '%.jpeg%'
          THEN 'jpeg'
        ELSE 'png'
      END
      WHERE output_format IS NULL
        OR output_format = ''
        OR output_format = 'png'
    ''');
  }

  Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    if (await _columnExists(table.actualTableName, column.name)) {
      return;
    }
    await migrator.addColumn(table, column);
  }

  Future<void> _createTableIfMissing(
    Migrator migrator,
    TableInfo<Table, Object?> table,
  ) async {
    if (await _tableExists(table.actualTableName)) {
      return;
    }
    await migrator.createTable(table);
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final escapedTableName = tableName.replaceAll("'", "''");
    final columns = await customSelect(
      "PRAGMA table_info('$escapedTableName')",
    ).get();
    return columns.any((row) => row.data['name'] == columnName);
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      variables: [const Variable<String>('table'), Variable<String>(tableName)],
    ).get();
    return rows.isNotEmpty;
  }
}
