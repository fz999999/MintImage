import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PickedAttachment {
  const PickedAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;

  static Future<PickedAttachment?> fromExistingPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    return PickedAttachment(
      path: file.path,
      name: p.basename(file.path),
      sizeBytes: await file.length(),
    );
  }
}

class AttachmentPickerService {
  AttachmentPickerService() : _imagePicker = ImagePicker();

  final ImagePicker _imagePicker;

  /// Markup in the unsent draft; cache cleanup must keep it.
  String? draftMarkupPath;

  Future<PickedAttachment?> pickMarkup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
    );
    final path = result?.files.single.path;
    return path == null ? null : PickedAttachment.fromExistingPath(path);
  }

  Future<String> storeMarkup(String path) async {
    return storeMarkupBytes(await File(path).readAsBytes());
  }

  Future<String> storeMarkupBytes(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final target = File(
      p.join(directory.path, 'markup_attachments', '${const Uuid().v4()}.png'),
    );
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<List<PickedAttachment>> pickImages() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final files = await _imagePicker.pickMultiImage();
      return Future.wait(
        files.map((file) async {
          return PickedAttachment(
            path: file.path,
            name: p.basename(file.path),
            sizeBytes: await file.length(),
          );
        }),
      );
    }

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );

    if (result == null) {
      return const [];
    }

    return result.files
        .where((file) => file.path != null)
        .map(
          (file) => PickedAttachment(
            path: file.path!,
            name: file.name,
            sizeBytes: file.size,
          ),
        )
        .toList();
  }
}
