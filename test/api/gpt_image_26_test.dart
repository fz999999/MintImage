import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/image_edit_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

import '../fixtures/generated_images.dart';

void main() {
  late HttpServer server;
  late List<Map<String, dynamic>> bodies;

  setUp(() async {
    bodies = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.uri.path, '/v1/images/generations');
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      bodies.add(body);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': [
            {
              'b64_json': body['output_format'] == 'gif'
                  ? animatedGifBase64
                  : base64Encode(utf8.encode(generatedSvg)),
            },
          ],
        }),
      );
      await request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  ApiProfile profile({
    ImageGenerationApiMode mode = ImageGenerationApiMode.images,
  }) => ApiProfile(
    id: 'test',
    name: 'test',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'fixture-key',
    model: 'gpt-image-2.6-flare',
    useStreaming: true,
    apiMode: mode,
  );

  for (final format in [ImageOutputFormat.gif, ImageOutputFormat.svg]) {
    test(
      '${format.label} sends supported fields and disables streaming',
      () async {
        final result = await const ImageGenerationApi().generate(
          _request.copyWith(
            outputFormat: format,
            frameCount: 12,
            frameDurationMs: 150,
            complexity: ImageComplexity.medium,
          ),
          profile(),
          responseFormat: 'url',
          timeoutSeconds: 10,
        );
        expect(result.single.b64Json, isNotEmpty);
        final body = bodies.single;
        expect(body['model'], 'gpt-image-2.6-flare');
        expect(body['output_format'], format.apiValue);
        expect(body['complexity'], 'medium');
        expect(body['quality'], 'xhigh');
        expect(body['n'], 1);
        expect(body, isNot(contains('stream')));
        expect(body, isNot(contains('partial_images')));
        expect(body, isNot(contains('response_format')));
        expect(body, isNot(contains('size')));
        if (format == ImageOutputFormat.gif) {
          expect(body['frame_count'], 12);
          expect(body['frame_duration_ms'], 150);
        } else {
          expect(body, isNot(contains('frame_count')));
          expect(body, isNot(contains('frame_duration_ms')));
        }
      },
    );

    test(
      '${format.label} rejects Responses API and image edits before network',
      () async {
        final request = _request.copyWith(outputFormat: format);
        await expectLater(
          const ImageGenerationApi().generate(
            request,
            profile(mode: ImageGenerationApiMode.responses),
            timeoutSeconds: 10,
          ),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          const ImageEditApi().edit(
            request.copyWith(imagePaths: ['missing.png']),
            profile(),
            timeoutSeconds: 10,
          ),
          throwsA(isA<ApiException>()),
        );
        expect(bodies, isEmpty);
      },
    );
  }

  test('GIF rejects invalid frame counts, durations and dimensions', () async {
    for (final request in [
      _request.copyWith(outputFormat: ImageOutputFormat.gif, frameCount: 1),
      _request.copyWith(outputFormat: ImageOutputFormat.gif, frameCount: 65),
      _request.copyWith(
        outputFormat: ImageOutputFormat.gif,
        frameDurationMs: 19,
      ),
      _request.copyWith(
        outputFormat: ImageOutputFormat.gif,
        frameDurationMs: 2001,
      ),
      _request.copyWith(
        outputFormat: ImageOutputFormat.gif,
        sizePreset: SizePreset.custom,
        customWidth: 255,
      ),
    ]) {
      await expectLater(
        const ImageGenerationApi().generate(
          request,
          profile(),
          timeoutSeconds: 10,
        ),
        throwsA(isA<ApiException>()),
      );
    }
    expect(bodies, isEmpty);
  });
}

const _request = GenerationRequest(
  prompt: 'A looping vector animation',
  imagePaths: [],
  sizePreset: SizePreset.auto,
  customWidth: 0,
  customHeight: 0,
  quality: ImageQuality.xhigh,
  count: 1,
  apiProfileId: 'test',
);
