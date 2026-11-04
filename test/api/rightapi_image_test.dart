import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/image_edit_api.dart';
import 'package:mint_image/core/api/image_generation_api.dart';
import 'package:mint_image/core/api/openai_client.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  for (final baseUrl in [
    'http://api.site',
    'http://future-provider.example/gateway/v1/',
  ]) {
    for (final apiMode in [
      ImageGenerationApiMode.images,
      ImageGenerationApiMode.imagesAsync,
    ]) {
      for (final useStreaming in [false, true]) {
        test('polls $baseUrl using $apiMode (stream=$useStreaming)', () async {
          var submissions = 0;
          var polls = 0;
          final prefix = baseUrl.contains('gateway') ? '/gateway' : '';
          await _withRightApiServer(
            (request) async {
              expect(
                request.headers.value(HttpHeaders.authorizationHeader),
                'Bearer test-key',
              );
              if (request.method == 'POST') {
                submissions++;
                expect(request.uri.path, '$prefix/v1/images/generations');
                final body =
                    jsonDecode(await utf8.decoder.bind(request).join()) as Map;
                final useAsync = apiMode == ImageGenerationApiMode.imagesAsync;
                expect(body['async'], useAsync ? isTrue : isNull);
                expect(
                  body['stream'],
                  useStreaming && !useAsync ? isTrue : isNull,
                );
                request.response.headers.contentType = ContentType.text;
                request.response.write(
                  const JsonEncoder.withIndent('  ').convert({
                    'task_id': 'task any-domain',
                    'status': 'processing',
                  }),
                );
                await request.response.close();
              } else {
                polls++;
                expect(
                  Uri.decodeComponent(request.uri.path),
                  '$prefix/v1/tasks/task any-domain',
                );
                await _respond(request, {
                  'data': [
                    {'url': 'https://example.com/protocol.webp'},
                  ],
                });
              }
            },
            () async {
              final results = await const ImageGenerationApi().generate(
                _request(),
                _profile(
                  baseUrl: baseUrl,
                  apiMode: apiMode,
                  useStreaming: useStreaming,
                ),
                timeoutSeconds: 10,
              );
              expect(
                results.single.imageUrl,
                'https://example.com/protocol.webp',
              );
            },
          );
          expect(submissions, 1);
          expect(polls, 1);
        });
      }
    }
  }

  for (final useStreaming in [false, true]) {
    test(
      'multipart edits follow returned tasks (stream=$useStreaming)',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'async-image-edit-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final image = await File(
          '${directory.path}/image.png',
        ).writeAsBytes([1, 2, 3]);
        await _withRightApiServer(
          (request) async {
            if (request.method == 'POST') {
              expect(request.uri.path, '/v1/images/edits');
              expect(
                request.headers.contentType?.mimeType,
                'multipart/form-data',
              );
              final body = await utf8.decoder.bind(request).join();
              expect(body, contains('name="image[]"'));
              expect(body, contains('filename="image.png"'));
              await _respond(request, {
                'task_id': 'task_edit',
                'status': 'queued',
              });
            } else {
              expect(request.uri.path, '/v1/tasks/task_edit');
              await _respond(request, {
                'data': [
                  {'url': 'https://example.com/multipart.webp'},
                ],
              });
            }
          },
          () async {
            final results = await const ImageEditApi().edit(
              _request(imagePaths: [image.path]),
              _profile(baseUrl: 'http://api.site', useStreaming: useStreaming),
              timeoutSeconds: 10,
            );
            expect(
              results.single.imageUrl,
              'https://example.com/multipart.webp',
            );
          },
        );
      },
    );
  }

  test('polling HTTP errors retain the full response body', () async {
    final body = {
      'detail': '查询次数过多',
      'request_id': 'req_polling_limit',
      'retry_after': 60,
    };
    await _withRightApiServer(
      (request) async {
        await request.drain<void>();
        if (request.method == 'POST') {
          await _respond(request, {
            'task_id': 'task_limited',
            'status': 'processing',
          });
        } else {
          request.response.statusCode = 429;
          await _respond(request, body);
        }
      },
      () async {
        await expectLater(
          const ImageGenerationApi().generate(
            _request(),
            _profile(baseUrl: 'http://api.site'),
            timeoutSeconds: 10,
          ),
          throwsA(
            isA<ApiException>()
                .having((error) => error.statusCode, 'statusCode', 429)
                .having(
                  (error) => error.message,
                  'message',
                  endsWith(const JsonEncoder.withIndent('  ').convert(body)),
                ),
          ),
        );
      },
    );
  });

  test('an invalid task response retains the provider details', () async {
    final body = {
      'task_id': ' ',
      'detail': 'invalid task',
      'request_id': 'req_invalid',
    };
    await _withRightApiServer(
      (request) async {
        await request.drain<void>();
        await _respond(request, body);
      },
      () async {
        await expectLater(
          const ImageGenerationApi().generate(
            _request(),
            _profile(baseUrl: 'http://api.site'),
            timeoutSeconds: 10,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              endsWith(const JsonEncoder.withIndent('  ').convert(body)),
            ),
          ),
        );
      },
    );
  });

  test(
    'RightAPI generation preserves pixel size and polls for the image',
    () async {
      var polls = 0;
      await _withRightApiServer(
        (request) async {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer test-key',
          );
          if (request.method == 'POST') {
            expect(request.uri.path, '/v1/images/generations');
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            expect(body['async'], isTrue);
            expect(body['size'], '1536x1024');
            expect(body['quality'], 'medium');
            expect(body['output_format'], 'webp');
            expect(body.containsKey('imageSize'), isFalse);
            expect(body.containsKey('response_format'), isFalse);
            expect(body.containsKey('stream'), isFalse);
            await _respond(request, {
              'task_id': 'task_test',
              'status': 'processing',
            });
          } else {
            expect(request.uri.path, '/v1/tasks/task_test');
            polls++;
            await _respond(
              request,
              polls == 1
                  ? {
                      'task_id': 'task_test',
                      'status': 'in_progress',
                      'progress': 45,
                    }
                  : {
                      'data': [
                        {'url': 'https://example.com/generated.webp'},
                      ],
                    },
            );
          }
        },
        () async {
          final results = await const ImageGenerationApi().generate(
            _request(),
            _profile(useStreaming: true),
            responseFormat: 'url',
            timeoutSeconds: 30,
          );
          expect(results.single.imageUrl, 'https://example.com/generated.webp');
          expect(polls, 2);
        },
      );
    },
  );

  for (final baseUrl in [
    'http://www.rightapi.ai/draw/v1/',
    'http://api.site',
    'http://future-provider.example',
  ]) {
    test('async edits retain image options on $baseUrl', () async {
      final directory = await Directory.systemTemp.createTemp('rightapi-edit-');
      addTearDown(() => directory.delete(recursive: true));
      final first = await File(
        '${directory.path}/first.png',
      ).writeAsBytes([1, 2, 3]);
      final second = await File(
        '${directory.path}/second.png',
      ).writeAsBytes([4, 5, 6]);
      await _withRightApiServer(
        (request) async {
          if (request.method == 'POST') {
            expect(request.uri.path, '/v1/images/edits');
            expect(request.headers.contentType?.mimeType, 'application/json');
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            expect(body['async'], isTrue);
            expect(body['size'], '1536x1024');
            expect(body['quality'], 'medium');
            expect(body['output_format'], 'webp');
            expect(body['image'], [
              'data:image/png;base64,${base64Encode([1, 2, 3])}',
              'data:image/png;base64,${base64Encode([4, 5, 6])}',
            ]);
            expect(body.containsKey('imageSize'), isFalse);
            expect(body.containsKey('stream'), isFalse);
            expect(body.containsKey('response_format'), isFalse);
            await _respond(request, {
              'task_id': 'task_edit',
              'status': 'processing',
            });
          } else {
            expect(request.uri.path, '/v1/tasks/task_edit');
            await _respond(request, {
              'data': [
                {'url': 'https://example.com/edited.webp'},
              ],
            });
          }
        },
        () async {
          final results = await const ImageEditApi().edit(
            _request(imagePaths: [first.path, second.path]),
            _profile(
              baseUrl: baseUrl,
              useStreaming: true,
              apiMode: baseUrl.contains('/draw')
                  ? ImageGenerationApiMode.images
                  : ImageGenerationApiMode.imagesAsync,
            ),
            responseFormat: 'url',
            timeoutSeconds: 30,
          );
          expect(results.single.imageUrl, 'https://example.com/edited.webp');
        },
      );
    });
  }

  for (final status in ['failed', 'expired', 'canceled', 'cancelled']) {
    test('RightAPI stops on $status during submission', () async {
      await _withRightApiServer(
        (request) async {
          expect(request.method, 'POST');
          await request.drain<void>();
          await _respond(request, {
            'task_id': 'task_failed',
            'status': status,
            'error': 'upstream rejected the request',
          });
        },
        () async {
          await expectLater(
            const ImageGenerationApi().generate(
              _request(),
              _profile(),
              timeoutSeconds: 10,
            ),
            throwsA(
              isA<ApiException>().having(
                (error) => error.message,
                'message',
                contains('upstream rejected the request'),
              ),
            ),
          );
        },
      );
    });

    test('RightAPI stops on $status while polling', () async {
      await _withRightApiServer(
        (request) async {
          await request.drain<void>();
          await _respond(
            request,
            request.method == 'POST'
                ? {'task_id': 'task_failed', 'status': 'processing'}
                : {
                    'task_id': 'task_failed',
                    'status': status,
                    'error': {'message': 'generation stopped'},
                  },
          );
        },
        () async {
          await expectLater(
            const ImageGenerationApi().generate(
              _request(),
              _profile(),
              timeoutSeconds: 10,
            ),
            throwsA(
              isA<ApiException>().having(
                (error) => error.message,
                'message',
                contains('generation stopped'),
              ),
            ),
          );
        },
      );
    });
  }

  test('RightAPI also accepts an immediate Images response', () async {
    await _withRightApiServer(
      (request) async {
        expect(request.method, 'POST');
        await request.drain<void>();
        await _respond(request, {
          'data': [
            {'url': 'https://example.com/immediate.png'},
          ],
        });
      },
      () async {
        final results = await const ImageGenerationApi().generate(
          _request(),
          _profile(),
          timeoutSeconds: 10,
        );
        expect(results.single.imageUrl, 'https://example.com/immediate.png');
      },
    );
  });

  test('RightAPI enforces the overall timeout before the next poll', () async {
    var requests = 0;
    await _withRightApiServer(
      (request) async {
        requests++;
        await request.drain<void>();
        await _respond(request, {
          'task_id': 'task_slow',
          'status': 'processing',
        });
      },
      () async {
        final stopwatch = Stopwatch()..start();
        await expectLater(
          const ImageGenerationApi().generate(
            _request(),
            _profile(),
            timeoutSeconds: 1,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('超时'),
            ),
          ),
        );
        expect(requests, 1);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );
  });

  test('RightAPI cancellation interrupts the polling delay', () async {
    final cancelToken = CancelToken();
    await _withRightApiServer(
      (request) async {
        expect(request.method, 'POST');
        await request.drain<void>();
        await _respond(request, {
          'task_id': 'task_cancel',
          'status': 'processing',
        });
        Timer(const Duration(milliseconds: 100), () => cancelToken.cancel());
      },
      () async {
        final stopwatch = Stopwatch()..start();
        await expectLater(
          const ImageGenerationApi().generate(
            _request(),
            _profile(),
            timeoutSeconds: 10,
            cancelToken: cancelToken,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('取消'),
            ),
          ),
        );
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      },
    );
  });
}

Future<void> _withRightApiServer(
  Future<void> Function(HttpRequest) handler,
  Future<void> Function() action,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      try {
        await handler(request);
      } finally {
        await request.response.close();
      }
    }),
  );
  try {
    await HttpOverrides.runWithHttpOverrides(
      action,
      _RightApiProxy(server.port),
    );
  } finally {
    await server.close(force: true);
  }
}

class _RightApiProxy extends HttpOverrides {
  _RightApiProxy(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) => 'PROXY 127.0.0.1:$port';
  }
}

Future<void> _respond(HttpRequest request, Map<String, dynamic> body) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

ApiProfile _profile({
  String baseUrl = 'http://rightapi.ai',
  bool useStreaming = false,
  ImageGenerationApiMode apiMode = ImageGenerationApiMode.images,
}) {
  return ApiProfile.fromJson(
    ApiProfile(
      id: 'rightapi',
      name: 'RightAPI',
      baseUrl: baseUrl,
      apiKey: 'test-key',
      model: 'gpt-image-2.5-flare',
      useStreaming: useStreaming,
      apiMode: apiMode,
    ).toJson(),
  );
}

GenerationRequest _request({List<String> imagePaths = const []}) {
  return GenerationRequest(
    prompt: 'a blue circle on white',
    imagePaths: imagePaths,
    sizePreset: SizePreset.posterLandscape,
    customWidth: 1536,
    customHeight: 1024,
    quality: ImageQuality.medium,
    outputFormat: ImageOutputFormat.webp,
    count: 1,
    apiProfileId: 'rightapi',
  );
}
