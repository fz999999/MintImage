import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/generation_result.dart';
import '../models/encoded_image_format.dart';

class StoredImageResult {
  const StoredImageResult({
    required this.localPath,
    required this.imageUrl,
    this.outputFormat,
  });

  final String? localPath;
  final String? imageUrl;
  final String? outputFormat;
}

class ImageStorageService {
  const ImageStorageService();

  Future<StoredImageResult> storeResult(
    String recordId,
    GenerationResult result, {
    String fileExtension = 'png',
  }) async {
    final outputDirectory = await _ensureOutputDirectory();

    if (result.b64Json != null && result.b64Json!.isNotEmpty) {
      final raw = result.b64Json!.trim();
      final bytes = raw.startsWith('data:')
          ? UriData.parse(raw).contentAsBytes()
          : base64Decode(raw);
      final extension = encodedImageExtension(bytes) ?? fileExtension;
      final file = File(p.join(outputDirectory.path, '$recordId.$extension'));
      await file.writeAsBytes(bytes, flush: true);

      return StoredImageResult(
        localPath: file.path,
        imageUrl: result.imageUrl,
        outputFormat: extension,
      );
    }

    if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
      final localPath = await _downloadFromUrl(
        outputDirectory: outputDirectory,
        recordId: recordId,
        imageUrl: result.imageUrl!,
        fileExtension: fileExtension,
      );

      return StoredImageResult(
        localPath: localPath,
        imageUrl: localPath == null ? result.imageUrl : null,
        outputFormat: localPath == null
            ? null
            : p.extension(localPath).substring(1),
      );
    }

    return StoredImageResult(localPath: null, imageUrl: result.imageUrl);
  }

  Future<Directory> _ensureOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory(
      p.join(directory.path, 'generated_images'),
    );
    await outputDirectory.create(recursive: true);
    return outputDirectory;
  }

  Future<String?> _downloadFromUrl({
    required Directory outputDirectory,
    required String recordId,
    required String imageUrl,
    required String fileExtension,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      final extension =
          encodedImageExtension(bytes) ??
          _resolveExtension(
            imageUrl,
            response.headers.contentType,
            fileExtension,
          );
      final file = File(p.join(outputDirectory.path, '$recordId.$extension'));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  String _resolveExtension(
    String imageUrl,
    ContentType? contentType,
    String fallback,
  ) {
    final uri = Uri.tryParse(imageUrl);
    final path = uri?.path ?? imageUrl;
    final parsedExtension = p.extension(path).replaceFirst('.', '').trim();
    if (parsedExtension.isNotEmpty && parsedExtension.length <= 5) {
      return parsedExtension;
    }

    return switch (contentType?.mimeType.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/svg+xml' => 'svg',
      _ => fallback,
    };
  }
}
