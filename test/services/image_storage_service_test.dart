import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/encoded_image_format.dart';
import 'package:mint_image/core/models/generation_result.dart';
import 'package:mint_image/core/services/image_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fixtures/generated_images.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mint-formats-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  for (final format in ['gif', 'svg']) {
    final bytes = format == 'gif'
        ? base64Decode(animatedGifBase64)
        : utf8.encode(generatedSvg);
    test(
      'preserves $format bytes and detects format in Base64 and data URLs',
      () async {
        for (final dataUrl in [false, true]) {
          final stored = await const ImageStorageService().storeResult(
            'test-$dataUrl',
            GenerationResult(
              b64Json:
                  '${dataUrl ? 'data:image/$format;base64,' : ''}${base64Encode(bytes)}',
            ),
          );
          expect(stored.localPath, endsWith('.$format'));
          expect(stored.outputFormat, format);
          expect(await File(stored.localPath!).readAsBytes(), bytes);
        }
      },
    );
    test(
      'detects $format from extensionless URL with generic content type',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.headers.contentType = ContentType.binary;
          request.response.add(bytes);
          await request.response.close();
        });
        final stored = await const ImageStorageService().storeResult(
          'download',
          GenerationResult(
            imageUrl:
                'http://${server.address.host}:${server.port}/download?file=.png',
          ),
        );
        expect(stored.localPath, endsWith('.$format'));
        expect(await File(stored.localPath!).readAsBytes(), bytes);
      },
    );
  }

  test(
    'SVG detection rejects HTML errors, comments containing svg and invalid XML',
    () {
      for (final source in [
        '',
        '<html><svg/></html>',
        '<!-- <svg/> --><error/>',
        '<svg><broken></svg>',
      ]) {
        expect(encodedImageExtension(utf8.encode(source)), isNull);
      }
      expect(encodedImageExtension(utf8.encode(generatedSvg)), 'svg');
    },
  );
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}
