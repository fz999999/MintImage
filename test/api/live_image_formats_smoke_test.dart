import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/api_request_logger.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/encoded_image_format.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

/// Opt in explicitly: each requested format can incur a real generation charge.
/// Credentials are read from the process environment and never persisted.
void main() {
  final enabled = Platform.environment['RUN_LIVE_IMAGE_FORMATS'] == '1';
  final apiKey = Platform.environment['TEST_API_KEY'] ?? '';
  final baseUrl = Platform.environment['TEST_BASE_URL'] ?? '';
  final model = Platform.environment['TEST_MODEL'] ?? 'gpt-image-2.6-flare';
  final timeout =
      int.tryParse(Platform.environment['TEST_TIMEOUT_SECONDS'] ?? '') ?? 600;
  final frameCount =
      int.tryParse(Platform.environment['TEST_FRAME_COUNT'] ?? '') ?? 2;
  final frameDurationMs =
      int.tryParse(Platform.environment['TEST_FRAME_DURATION_MS'] ?? '') ?? 200;
  final directory = Directory(
    Platform.environment['TEST_OUTPUT_DIR'] ??
        'build/live_image_formats/${DateTime.now().millisecondsSinceEpoch}',
  );

  for (final format in [ImageOutputFormat.gif, ImageOutputFormat.svg]) {
    test(
      'generates a real ${format.label} through the project ImageGenerationApi',
      () async {
        expect(apiKey, isNotEmpty, reason: 'Set TEST_API_KEY.');
        expect(baseUrl, isNotEmpty, reason: 'Set TEST_BASE_URL.');
        final logger = _EvidenceLogger(apiKey);
        final profile = ApiProfile(
          id: 'live-image-formats',
          name: 'Live image formats',
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: model,
        );
        final request = GenerationRequest(
          prompt: format == ImageOutputFormat.gif
              ? 'A simple mint green ball bouncing gently on a white background. '
                    'Seamless looping GIF animation. No text.'
              : 'A simple mint green leaf logo on white. Clean flat SVG vector '
                    'shapes with a few paths. No text, gradients or raster images.',
          imagePaths: const [],
          sizePreset: SizePreset.auto,
          customWidth: 0,
          customHeight: 0,
          quality: ImageQuality.low,
          outputFormat: format,
          frameCount: frameCount,
          frameDurationMs: frameDurationMs,
          count: 1,
          apiProfileId: profile.id,
        );
        final evidence = <String, Object?>{
          'tested_at': DateTime.now().toUtc().toIso8601String(),
          'implementation': 'ImageGenerationApi.generate',
          'endpoint': profile.generationEndpoint,
          'model': model,
          'requested_format': format.apiValue,
          'quality': request.quality.apiValue,
          if (format == ImageOutputFormat.gif) ...{
            'requested_frame_count': request.frameCount,
            'requested_frame_duration_ms': request.frameDurationMs,
          },
          'ok': false,
        };
        final stopwatch = Stopwatch()..start();
        try {
          final results = await ImageGenerationApi(
            requestLogService: logger,
          ).generate(request, profile, timeoutSeconds: timeout);
          expect(results, hasLength(1));
          final result = results.single;
          List<int> bytes;
          if (result.b64Json?.isNotEmpty == true) {
            final raw = result.b64Json!.trim();
            bytes = raw.startsWith('data:')
                ? UriData.parse(raw).contentAsBytes()
                : base64Decode(raw);
          } else {
            expect(result.imageUrl, isNotNull);
            final uri = Uri.parse(result.imageUrl!);
            if (uri.scheme == 'data') {
              bytes = uri.data!.contentAsBytes();
            } else {
              final client = HttpClient();
              try {
                final response = await (await client.getUrl(uri)).close();
                expect(response.statusCode, 200);
                bytes = await response.fold<List<int>>([], (all, chunk) {
                  all.addAll(chunk);
                  return all;
                });
              } finally {
                client.close(force: true);
              }
            }
          }
          final actualFormat = encodedImageExtension(bytes);
          evidence['actual_format'] = actualFormat;
          evidence['bytes'] = bytes.length;
          await directory.create(recursive: true);
          final artifact = File(
            '${directory.path}/${format.apiValue}.${actualFormat ?? 'bin'}',
          );
          await artifact.writeAsBytes(bytes, flush: true);
          evidence['artifact'] = artifact.absolute.path;
          expect(
            actualFormat,
            format.apiValue,
            reason: 'Check encoded bytes rather than trusting the extension.',
          );
          evidence['generation_ok'] = true;
          if (format == ImageOutputFormat.gif) {
            final codec = await ui.instantiateImageCodec(
              Uint8List.fromList(bytes),
            );
            try {
              evidence['frame_count'] = codec.frameCount;
              final durations = <int>[];
              for (var i = 0; i < codec.frameCount; i++) {
                final frame = await codec.getNextFrame();
                evidence['width'] = frame.image.width;
                evidence['height'] = frame.image.height;
                durations.add(frame.duration.inMilliseconds);
                frame.image.dispose();
              }
              evidence['frame_durations_ms'] = durations;
              evidence['parameters_match'] =
                  codec.frameCount == request.frameCount &&
                  durations.every((value) => value == request.frameDurationMs);
              expect(codec.frameCount, request.frameCount);
              expect(durations, everyElement(request.frameDurationMs));
            } finally {
              codec.dispose();
            }
          }
          evidence['ok'] = true;
        } on ApiException catch (error) {
          evidence['status_code'] = error.statusCode;
          evidence['error'] = logger.sanitize(error.message);
          rethrow;
        } catch (error) {
          evidence['error'] = logger.sanitize(error.toString());
          rethrow;
        } finally {
          stopwatch.stop();
          evidence['elapsed_ms'] = stopwatch.elapsedMilliseconds;
          evidence['events'] = logger.events;
          await directory.create(recursive: true);
          final report = File('${directory.path}/${format.apiValue}.json');
          await report.writeAsString(
            const JsonEncoder.withIndent('  ').convert(evidence),
            flush: true,
          );
          // Safe metadata only: no credentials or image base64 in test output.
          // ignore: avoid_print
          print(
            jsonEncode({
              'format': format.apiValue,
              'ok': evidence['ok'],
              'generation_ok': evidence['generation_ok'],
              'requested_frame_count': evidence['requested_frame_count'],
              'requested_frame_duration_ms':
                  evidence['requested_frame_duration_ms'],
              'actual_frame_count': evidence['frame_count'],
              'actual_frame_durations_ms': evidence['frame_durations_ms'],
              'parameters_match': evidence['parameters_match'],
              'endpoint': profile.generationEndpoint,
              'status_code': evidence['status_code'],
              'error': evidence['error'],
              'report': report.absolute.path,
            }),
          );
        }
      },
      skip: enabled
          ? false
          : 'Set RUN_LIVE_IMAGE_FORMATS=1, TEST_BASE_URL, TEST_API_KEY and TEST_MODEL.',
      timeout: Timeout(Duration(seconds: timeout + 60)),
    );
  }

  test(
    'runs the exact static image example through the project OpenAiClient',
    () async {
      expect(apiKey, isNotEmpty);
      expect(baseUrl, isNotEmpty);
      final logger = _EvidenceLogger(apiKey);
      final profile = ApiProfile(
        id: 'live-control',
        name: 'Live control',
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      );
      final client = OpenAiClient(
        profile,
        timeoutSeconds: timeout,
        requestLogService: logger,
      );
      final evidence = <String, Object?>{
        'tested_at': DateTime.now().toUtc().toIso8601String(),
        'implementation': 'OpenAiClient.postJson (exact example body)',
        'endpoint': profile.generationEndpoint,
        'model': model,
        'ok': false,
      };
      try {
        final response = await client.postJson(profile.generationPath, {
          'model': model,
          'prompt':
              'A serene mountain landscape at sunset with dramatic clouds',
        });
        final data = response['data'] as List;
        expect(data, isNotEmpty);
        final bytes = base64Decode((data.first as Map)['b64_json'] as String);
        final format = encodedImageExtension(bytes);
        evidence['actual_format'] = format;
        evidence['bytes'] = bytes.length;
        evidence['usage'] = response['usage'];
        await directory.create(recursive: true);
        final file = File('${directory.path}/control.${format ?? 'bin'}');
        await file.writeAsBytes(bytes, flush: true);
        evidence['artifact'] = file.absolute.path;
        expect(format, isNotNull);
        evidence['ok'] = true;
      } on ApiException catch (error) {
        evidence['status_code'] = error.statusCode;
        evidence['error'] = logger.sanitize(error.message);
        rethrow;
      } finally {
        client.close();
        evidence['events'] = logger.events;
        await directory.create(recursive: true);
        final report = File('${directory.path}/control.json');
        await report.writeAsString(
          const JsonEncoder.withIndent('  ').convert(evidence),
          flush: true,
        );
        // ignore: avoid_print
        print(
          jsonEncode({
            'control_ok': evidence['ok'],
            'status_code': evidence['status_code'],
            'error': evidence['error'],
            'report': report.absolute.path,
          }),
        );
      }
    },
    skip: Platform.environment['RUN_LIVE_IMAGE_CONTROL'] == '1'
        ? false
        : 'Set RUN_LIVE_IMAGE_CONTROL=1 to run one additional static control.',
    timeout: Timeout(Duration(seconds: timeout + 60)),
  );
}

class _EvidenceLogger implements ApiRequestLogger {
  _EvidenceLogger(this.apiKey);

  final String apiKey;
  final events = <Map<String, String>>[];

  String sanitize(String value) =>
      apiKey.isEmpty ? value : value.replaceAll(apiKey, '[REDACTED]');

  @override
  Future<void> logRequest(String title, String details) async {
    events.add({
      'type': 'request',
      'title': title,
      'details': sanitize(details),
    });
  }

  @override
  Future<void> logResponse(String title, String details) async {
    events.add({
      'type': 'response',
      'title': title,
      'details': sanitize(details),
    });
  }

  @override
  Future<void> logError(String title, String details) async {
    events.add({'type': 'error', 'title': title, 'details': sanitize(details)});
  }
}
