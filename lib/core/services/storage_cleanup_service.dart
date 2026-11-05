import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/image_record_dao.dart';
import '../models/image_record.dart';

enum StorageCleanupCategory {
  markup('未引用的标注图', '已不被任何记录或当前草稿使用的标注 PNG', true),
  images('未引用的图片', '删除历史记录后遗留的生成结果与恢复的参考图', true),
  temporary('临时文件', '复制到剪贴板、WebDAV 下载产生的临时文件', true),
  backups('备份文件', '导出与恢复前自动生成的安全快照', false);

  const StorageCleanupCategory(this.label, this.description, this.byDefault);

  final String label;
  final String description;
  final bool byDefault;
}

class StorageCleanupPlan {
  const StorageCleanupPlan(this.files);

  final Map<StorageCleanupCategory, List<File>> files;

  int count(StorageCleanupCategory category) => files[category]?.length ?? 0;

  int bytes(StorageCleanupCategory category) => [
    for (final file in files[category] ?? const <File>[]) _lengthOrZero(file),
  ].fold(0, (sum, value) => sum + value);

  bool get isEmpty => files.values.every((list) => list.isEmpty);
}

class StorageCleanupResult {
  const StorageCleanupResult({
    required this.deletedFiles,
    required this.freedBytes,
    required this.failedFiles,
  });

  final int deletedFiles;
  final int freedBytes;
  final int failedFiles;
}

/// Removes only files the app wrote itself and that no record references.
class StorageCleanupService {
  StorageCleanupService({
    required ImageRecordDao imageRecordDao,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? now,
  }) : _imageRecordDao = imageRecordDao,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  /// Files this fresh may belong to a generation whose record is not yet saved.
  static const gracePeriod = Duration(minutes: 10);

  final ImageRecordDao _imageRecordDao;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _now;

  Future<StorageCleanupPlan> scan({Set<String> keep = const {}}) async {
    final records = await _imageRecordDao.loadAll();
    final referenced = {
      for (final path in keep) _key(path),
      for (final record in records) ..._recordPaths(record).map(_key),
    };
    final documents = await _documentsDirectory();
    final temporary = await _temporaryDirectory();
    final cutoff = _now().subtract(gracePeriod);

    Future<List<File>> unreferenced(List<String> directories) async {
      final result = <File>[];
      for (final directory in directories) {
        for (final file in await _listFiles(
          Directory(p.join(documents.path, directory)),
        )) {
          if (!referenced.contains(_key(file.path)) &&
              _modifiedBefore(file, cutoff)) {
            result.add(file);
          }
        }
      }
      return result;
    }

    final temporaryFiles = [
      for (final entity in await _list(temporary))
        if (entity is File &&
            (p.basename(entity.path).startsWith('mint_image_clipboard_') ||
                p.basename(entity.path) == 'mint_image_latest.mintbackup') &&
            _modifiedBefore(entity, cutoff))
          entity,
    ];
    final backups = [
      for (final file in await _listFiles(
        Directory(p.join(temporary.path, 'mint_image_backups')),
      ))
        if (_modifiedBefore(file, cutoff)) file,
    ];

    return StorageCleanupPlan({
      StorageCleanupCategory.markup: await unreferenced(['markup_attachments']),
      StorageCleanupCategory.images: await unreferenced([
        'generated_images',
        'restored_source_attachments',
      ]),
      StorageCleanupCategory.temporary: temporaryFiles,
      StorageCleanupCategory.backups: backups,
    });
  }

  Future<StorageCleanupResult> clean(
    StorageCleanupPlan plan,
    Set<StorageCleanupCategory> categories,
  ) async {
    var deleted = 0;
    var freed = 0;
    var failed = 0;
    for (final category in categories) {
      for (final file in plan.files[category] ?? const <File>[]) {
        final length = _lengthOrZero(file);
        try {
          await file.delete();
          deleted++;
          freed += length;
        } on FileSystemException {
          if (await file.exists()) failed++;
        }
      }
    }
    return StorageCleanupResult(
      deletedFiles: deleted,
      freedBytes: freed,
      failedFiles: failed,
    );
  }

  Iterable<String> _recordPaths(ImageRecord record) => [
    ?record.resultImagePath,
    ?record.sourceImagePath,
    ...record.sourceImagePaths,
    ?record.markupPath,
  ].where((path) => path.isNotEmpty);

  /// Windows paths are case-insensitive and may mix separators.
  String _key(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  bool _modifiedBefore(File file, DateTime cutoff) {
    try {
      return file.lastModifiedSync().isBefore(cutoff);
    } on FileSystemException {
      return false;
    }
  }

  Future<List<FileSystemEntity>> _list(Directory directory) async {
    if (!await directory.exists()) return const [];
    return directory.list(followLinks: false).toList();
  }

  Future<List<File>> _listFiles(Directory directory) async {
    if (!await directory.exists()) return const [];
    return directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
  }
}

int _lengthOrZero(File file) {
  try {
    return file.lengthSync();
  } on FileSystemException {
    return 0;
  }
}
