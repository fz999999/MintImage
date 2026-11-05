import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/image_edit_api.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/model_list_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const _request = GenerationRequest(
  prompt: 'A mint green leaf',
  imagePaths: [],
  sizePreset: SizePreset.posterLandscape,
  customWidth: 0,
  customHeight: 0,
  quality: ImageQuality.low,
  outputFormat: ImageOutputFormat.png,
  complexity: ImageComplexity.high,
  count: 1,
  apiProfileId: 'openrouter',
);

ApiProfile _profile({bool stream = false}) => ApiProfile(
  id: 'openrouter',
  name: 'OpenRouter',
  baseUrl: 'http://openrouter.ai/api/v1/images',
  apiKey: 'fixture-key',
  model: 'openai/gpt-image-2.6-flare',
  useStreaming: stream,
  safetyIdentifier: 'anon-42',
);

void main() {
  late HttpServer server;
  late List<({String method, String path, String? type, String body})> calls;
  late String Function() reply;

  setUp(() async {
    calls = [];
    reply = () => jsonEncode({
      'created': 0,
      'data': [
        {'b64_json': _pngBase64},
      ],
    });
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      calls.add((
        method: request.method,
        path: request.uri.path,
        type: request.headers.contentType?.mimeType,
        body: await utf8.decoder.bind(request).join(),
      ));
      expect(request.headers.value('authorization'), 'Bearer fixture-key');
      final body = reply();
      request.response.headers.contentType = body.startsWith('data:')
          ? ContentType('text', 'event-stream')
          : ContentType.json;
      request.response.write(body);
      await request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  Future<T> run<T>(Future<T> Function() body) =>
      HttpOverrides.runWithHttpOverrides(body, _LocalProxy(server.port));

  test('generation maps options onto the unified Image API', () async {
    final result = await run(
      () => const ImageGenerationApi().generate(
        _request,
        _profile(),
        responseFormat: 'b64_json',
        timeoutSeconds: 10,
      ),
    );
    expect(result.single.b64Json, _pngBase64);
    final call = calls.single;
    expect(
      (call.method, call.path, call.type),
      ('POST', '/api/v1/images', 'application/json'),
    );
    final body = jsonDecode(call.body) as Map<String, dynamic>;
    expect(body, {
      'model': 'openai/gpt-image-2.6-flare',
      'prompt': 'A mint green leaf',
      'n': 1,
      'quality': 'low',
      'output_format': 'png',
      'size': '1536x1024',
      'user': 'anon-42',
      'provider': {
        'options': {
          'openai': {'complexity': 'high'},
        },
      },
    });
  });

  test('edits post JSON input_references to the same endpoint', () async {
    final directory = Directory.systemTemp.createTempSync('openrouter-edit-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final reference = File('${directory.path}/reference.png')
      ..writeAsBytesSync(base64Decode(_pngBase64));
    await run(
      () => const ImageEditApi().edit(
        _request.copyWith(imagePaths: [reference.path]),
        _profile(),
        timeoutSeconds: 10,
      ),
    );
    final call = calls.single;
    expect((call.path, call.type), ('/api/v1/images', 'application/json'));
    final body = jsonDecode(call.body) as Map<String, dynamic>;
    expect(body['input_references'], [
      {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,$_pngBase64'},
      },
    ]);
    expect(body.containsKey('image'), isFalse);
    expect(body.containsKey('async'), isFalse);
  });

  test('streaming reads the completed SSE event', () async {
    reply = () =>
        'data: ${jsonEncode({'type': 'image_generation.partial_image', 'partial_image_index': 0, 'b64_json': 'cGFydGlhbA=='})}\n\n'
        'data: ${jsonEncode({'type': 'image_generation.completed', 'created': 0, 'b64_json': _pngBase64})}\n\n'
        'data: [DONE]\n\n';
    final result = await run(
      () => const ImageGenerationApi().generate(
        _request,
        _profile(stream: true),
        timeoutSeconds: 10,
      ),
    );
    expect(result.single.b64Json, _pngBase64);
    expect(jsonDecode(calls.single.body)['stream'], isTrue);
  });

  test('streaming surfaces error events', () async {
    reply = () =>
        'data: ${jsonEncode({
          'type': 'error',
          'error': {'message': 'provider exploded'},
        })}\n\n';
    await expectLater(
      run(
        () => const ImageGenerationApi().generate(
          _request,
          _profile(stream: true),
          timeoutSeconds: 10,
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('provider exploded'),
        ),
      ),
    );
  });

  test('options OpenRouter would silently drop fail before HTTP', () async {
    final directory = Directory.systemTemp.createTempSync('openrouter-bad-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final reference = File('${directory.path}/reference.png')
      ..writeAsBytesSync(base64Decode(_pngBase64));
    for (final (request, edit, message) in [
      (_request.copyWith(outputFormat: ImageOutputFormat.gif), false, 'GIF'),
      (
        _request.copyWith(
          outputFormat: ImageOutputFormat.svg,
          svgOptions: const SvgOptions(model: 'x'),
        ),
        false,
        'SVG',
      ),
      (
        _request.copyWith(
          imagePaths: [reference.path],
          markupPath: '${directory.path}/markup.png',
        ),
        true,
        'markup',
      ),
    ]) {
      await expectLater(
        run(
          () => edit
              ? const ImageEditApi().edit(
                  request,
                  _profile(),
                  timeoutSeconds: 10,
                )
              : const ImageGenerationApi().generate(
                  request,
                  _profile(),
                  timeoutSeconds: 10,
                ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    }
    expect(calls, isEmpty);
  });

  test('model list uses the image model catalog', () async {
    reply = () => jsonEncode({
      'data': [
        {'id': 'openai/gpt-image-2.6-flare'},
        {'id': 'black-forest-labs/flux.2-klein-4b'},
      ],
    });
    final models = await run(
      () => const ModelListApi().fetchImageGenerationModels(
        profile: _profile(),
        timeoutSeconds: 10,
      ),
    );
    expect(calls.single.path, '/api/v1/images/models');
    expect(models, contains('openai/gpt-image-2.6-flare'));
  });

  test('OpenRouter base URLs normalize to one endpoint', () {
    for (final baseUrl in [
      'https://openrouter.ai',
      'https://openrouter.ai/api',
      'https://openrouter.ai/api/v1/',
      'https://openrouter.ai/api/v1/images',
    ]) {
      final profile = _profile().copyWith(baseUrl: baseUrl);
      expect(profile.generationEndpoint, 'https://openrouter.ai/api/v1/images');
      expect(profile.editEndpoint, 'https://openrouter.ai/api/v1/images');
    }
    expect(
      _profile()
          .copyWith(
            baseUrl: 'https://openrouter.ai/api/v1',
            apiMode: ImageGenerationApiMode.responses,
          )
          .isOpenRouterImages,
      isFalse,
    );
  });
}

class _LocalProxy extends HttpOverrides {
  _LocalProxy(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..findProxy = (_) => 'PROXY 127.0.0.1:$port';
}
