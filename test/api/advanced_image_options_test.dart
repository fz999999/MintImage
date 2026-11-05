import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:mint_image/cli/cli_options.dart';
import 'package:mint_image/cli/cli_error.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/image_edit_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/services/markup_validation.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late File reference;
  late File overlay;
  late List<({String path, String type, List<int> bytes})> received;
  setUp(() async {
    received = [];
    directory = await Directory.systemTemp.createTemp('image-advanced-');
    reference = File('${directory.path}/reference.png');
    overlay = File('${directory.path}/markup.png');
    await reference.writeAsBytes(
      image.encodePng(image.Image(width: 32, height: 24, numChannels: 3)),
    );
    final markup = image.Image(width: 32, height: 24, numChannels: 4);
    markup.setPixelRgba(8, 8, 255, 0, 0, 255);
    await overlay.writeAsBytes(image.encodePng(markup));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = await request.fold<List<int>>(
        [],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      received.add((
        path: request.uri.path,
        type: request.headers.contentType.toString(),
        bytes: bytes,
      ));
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': [
            {'b64_json': 'fixture'},
          ],
        }),
      );
      await request.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  ApiProfile profile([
    ImageGenerationApiMode mode = ImageGenerationApiMode.images,
  ]) => ApiProfile(
    id: 'test',
    name: 'test',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'fixture',
    model: 'gpt-image-2.6-flare',
    apiMode: mode,
    safetyIdentifier: ' anonymous-id ',
  );

  test(
    'SVG nested model and reasoning reach HTTP, while defaults stay omitted',
    () async {
      const svg = SvgOptions(
        model: ' svg-author ',
        reasoningEffort: SvgReasoningEffort.max,
      );
      final request = _request.copyWith(
        outputFormat: ImageOutputFormat.svg,
        svgOptions: svg,
      );
      await const ImageGenerationApi().generate(
        request,
        profile(),
        timeoutSeconds: 10,
      );
      var body = jsonDecode(utf8.decode(received.last.bytes)) as Map;
      expect(body['svg'], {
        'model': 'svg-author',
        'reasoning': {'effort': 'max'},
      });
      expect(body['safety_identifier'], 'anonymous-id');
      await const ImageGenerationApi().generate(
        request.copyWith(clearSvgOptions: true),
        profile().copyWith(safetyIdentifier: ''),
        timeoutSeconds: 10,
      );
      body = jsonDecode(utf8.decode(received.last.bytes)) as Map;
      expect(body.containsKey('svg'), isFalse);
      expect(body.containsKey('safety_identifier'), isFalse);
      await const ImageGenerationApi().generate(
        request.copyWith(outputFormat: ImageOutputFormat.png),
        profile(),
        timeoutSeconds: 10,
      );
      body = jsonDecode(utf8.decode(received.last.bytes)) as Map;
      expect(body.containsKey('svg'), isFalse);
    },
  );

  test(
    'markup is a separate PNG multipart part and retains original bytes',
    () async {
      await const ImageEditApi().edit(
        _request.copyWith(
          imagePaths: [reference.path],
          markupPath: overlay.path,
        ),
        profile(),
        timeoutSeconds: 10,
      );
      final request = received.single;
      expect(request.path, '/v1/images/edits');
      expect(request.type, startsWith('multipart/form-data'));
      final body = latin1.decode(request.bytes);
      expect(body, contains('name="markup"; filename="markup.png"'));
      expect(body, contains('content-type: image/png'));
      expect(body, contains(latin1.decode(await overlay.readAsBytes())));
      expect(RegExp(r'name="image\[\]"').allMatches(body), hasLength(1));
      expect(body, contains('name="safety_identifier"'));
      expect(body, contains('anonymous-id'));
    },
  );

  test(
    'async edit sends markup as JSON image_url separately from image array',
    () async {
      await const ImageEditApi().edit(
        _request.copyWith(
          imagePaths: [reference.path],
          markupPath: overlay.path,
        ),
        profile(ImageGenerationApiMode.imagesAsync),
        timeoutSeconds: 10,
      );
      final body = jsonDecode(utf8.decode(received.single.bytes)) as Map;
      expect(body['image'], hasLength(1));
      expect(body['markup'], {
        'image_url':
            'data:image/png;base64,${base64Encode(await overlay.readAsBytes())}',
      });
      expect(body['safety_identifier'], 'anonymous-id');
    },
  );

  test(
    'invalid markup and unsupported combinations fail before HTTP',
    () async {
      final request = _request.copyWith(
        imagePaths: [reference.path],
        markupPath: overlay.path,
      );
      expect(
        await validateMarkupAttachment(reference.path, overlay.path),
        isNull,
      );
      await overlay.writeAsBytes(
        image.encodePng(image.Image(width: 32, height: 24, numChannels: 3)),
      );
      expect(
        await validateMarkupAttachment(reference.path, overlay.path),
        contains('透明'),
      );
      await expectLater(
        const ImageEditApi().edit(request, profile(), timeoutSeconds: 10),
        throwsA(isA<ApiException>()),
      );
      await overlay.writeAsBytes(
        image.encodePng(image.Image(width: 16, height: 24, numChannels: 4)),
      );
      expect(
        await validateMarkupAttachment(reference.path, overlay.path),
        contains('尺寸'),
      );
      expect(request.validate(usesResponsesApi: true), contains('Images API'));
      expect(
        request.copyWith(imagePaths: []).validate(usesResponsesApi: false),
        contains('参考图'),
      );
      expect(
        request
            .copyWith(outputFormat: ImageOutputFormat.svg)
            .validate(usesResponsesApi: false),
        contains('文生图'),
      );
      await expectLater(
        const ImageGenerationApi().generate(
          _request,
          profile().copyWith(safetyIdentifier: 'x' * 129),
          timeoutSeconds: 10,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(received, isEmpty);
    },
  );

  test(
    'options survive requests, history and preferences, and clear explicitly',
    () {
      const svg = SvgOptions(
        model: 'author',
        reasoningEffort: SvgReasoningEffort.high,
      );
      final request = GenerationRequest.fromJson(
        _request.copyWith(svgOptions: svg, markupPath: overlay.path).toJson(),
      );
      expect(request.svgOptions!.toJson(), svg.toJson());
      expect(request.markupPath, overlay.path);
      final record = ImageRecord.pending(
        id: 'id',
        request: request,
        model: 'model',
        createdAt: DateTime.now(),
      ).copyWith(prompt: 'new');
      expect(record.svgOptions!.toJson(), svg.toJson());
      expect(record.markupPath, overlay.path);
      final settings = SettingsModel(
        profiles: [profile()],
        activeProfileId: 'test',
        lastSvgOptions: svg,
      );
      final restored = SettingsModel.decode(settings.encode());
      expect(restored.lastSvgOptions!.toJson(), svg.toJson());
      expect(restored.activeProfile.resolvedSafetyIdentifier, 'anonymous-id');
      expect(
        restored.copyWith(clearLastSvgOptions: true).lastSvgOptions,
        isNull,
      );
      expect(
        request
            .copyWith(clearSvgOptions: true, clearMarkupPath: true)
            .markupPath,
        isNull,
      );
    },
  );

  test(
    'CLI accepts advanced options and rejects unrelated SVG arguments',
    () async {
      final parser = createCliParser();
      final options = await CliOptions.fromArguments(
        parser.parse([
          '--prompt',
          'fixture',
          '--format',
          'svg',
          '--svg-model',
          'author',
          '--svg-reasoning-effort',
          'xhigh',
        ]),
        {'MINT_IMAGE_API_KEY': 'fixture'},
        const Stream.empty(),
        savedProfile: profile(),
      );
      expect(
        options.request.svgOptions!.reasoningEffort,
        SvgReasoningEffort.xhigh,
      );
      expect(options.profile.resolvedSafetyIdentifier, 'anonymous-id');
      await expectLater(
        CliOptions.fromArguments(
          parser.parse(['--prompt', 'fixture', '--svg-model', 'author']),
          {'MINT_IMAGE_API_KEY': 'fixture'},
          const Stream.empty(),
        ),
        throwsA(isA<CliException>()),
      );
    },
  );
}

const _request = GenerationRequest(
  prompt: 'fixture',
  imagePaths: [],
  sizePreset: SizePreset.auto,
  customWidth: 0,
  customHeight: 0,
  quality: ImageQuality.auto,
  count: 1,
  apiProfileId: 'test',
);
