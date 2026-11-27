import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/prompt_optimization_api.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  group('PromptOptimizationApi', () {
    test(
      'uses OpenAI Chat Completions format and parses message text',
      () async {
        final server = await _startServer((request) async {
          expect(request.method, 'POST');
          expect(request.uri.path, '/v1/chat/completions');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer test-key',
          );
          final body = await _readJson(request);
          expect(body['model'], 'gpt-test');
          expect(body['messages'], isA<List>());

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'optimized chat prompt'},
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final result = await const PromptOptimizationApi().optimize(
          prompt: 'cat',
          direction: PromptOptimizationDirection.strengthen,
          profile: _profileFor(
            server,
            protocol: PromptOptimizationProtocol.openAiChatCompletions,
          ),
          timeoutSeconds: 30,
        );

        expect(result, 'optimized chat prompt');
      },
    );

    test('uses OpenAI Responses format and parses output_text', () async {
      final server = await _startServer((request) async {
        expect(request.uri.path, '/v1/responses');
        final body = await _readJson(request);
        expect(body['model'], 'gpt-test');
        expect(body['input'], isA<List>());
        expect(body['stream'], isTrue);

        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'response prompt'})}\n\n'
          'data: [DONE]\n\n',
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final result = await const PromptOptimizationApi().optimize(
        prompt: 'cat',
        direction: PromptOptimizationDirection.poetic,
        profile: _profileFor(
          server,
          protocol: PromptOptimizationProtocol.openAiResponses,
        ),
        timeoutSeconds: 30,
      );

      expect(result, 'response prompt');
    });

    test('uses Claude Messages format and parses content text', () async {
      final server = await _startServer((request) async {
        expect(request.uri.path, '/v1/messages');
        expect(request.headers.value('x-api-key'), 'test-key');
        final body = await _readJson(request);
        expect(body['model'], 'gpt-test');
        expect(body['stream'], isTrue);
        expect(body['messages'], isA<List>());
        final messages = body['messages'] as List;
        final firstMessage = messages.first as Map<String, dynamic>;
        expect(firstMessage['content'], isA<List>());

        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': 'claude prompt'},
          })}\n\n'
          'data: [DONE]\n\n',
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final result = await const PromptOptimizationApi().optimize(
        prompt: 'cat',
        direction: PromptOptimizationDirection.edgeExplore,
        profile: _profileFor(
          server,
          protocol: PromptOptimizationProtocol.claudeMessages,
        ),
        timeoutSeconds: 30,
      );

      expect(result, 'claude prompt');
    });

    test(
      'uses Gemini generateContent format and parses candidate text',
      () async {
        final server = await _startServer((request) async {
          expect(request.uri.path, '/v1beta/models/gpt-test:generateContent');
          expect(request.headers.value('x-goog-api-key'), 'test-key');
          final body = await _readJson(request);
          expect(body['contents'], isA<List>());

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'gemini prompt'},
                    ],
                  },
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final result = await const PromptOptimizationApi().optimize(
          prompt: 'cat',
          direction: PromptOptimizationDirection.strengthenToEnglish,
          profile: _profileFor(
            server,
            protocol: PromptOptimizationProtocol.geminiGenerateContent,
          ),
          timeoutSeconds: 30,
        );

        expect(result, 'gemini prompt');
      },
    );

    test(
      'ignores reasoning deltas in OpenAI Responses SSE stream',
      () async {
        final server = await _startServer((request) async {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({'type': 'response.reasoning_summary_text.delta', 'delta': '思考摘要 '})}\n\n'
            'data: ${jsonEncode({'type': 'response.reasoning_text.delta', 'delta': '我们需要回答中文...'})}\n\n'
            'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': '最终提示词正文'})}\n\n'
            'data: [DONE]\n\n',
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final result = await const PromptOptimizationApi().optimize(
          prompt: '小女孩跳舞',
          direction: PromptOptimizationDirection.strengthen,
          profile: _profileFor(
            server,
            protocol: PromptOptimizationProtocol.openAiResponses,
          ),
          timeoutSeconds: 30,
        );

        expect(result, '最终提示词正文');
      },
    );

    test(
      'ignores reasoning output items in OpenAI Responses completed payload',
      () async {
        final server = await _startServer((request) async {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'type': 'response.completed',
              'response': {
                'output': [
                  {
                    'type': 'reasoning',
                    'content': [
                      {'type': 'reasoning_text', 'text': '内部推理过程'},
                    ],
                  },
                  {
                    'type': 'message',
                    'content': [
                      {'type': 'output_text', 'text': '纯净优化提示词'},
                    ],
                  },
                ],
              },
            })}\n\n'
            'data: [DONE]\n\n',
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final result = await const PromptOptimizationApi().optimize(
          prompt: '小女孩跳舞',
          direction: PromptOptimizationDirection.strengthen,
          profile: _profileFor(
            server,
            protocol: PromptOptimizationProtocol.openAiResponses,
          ),
          timeoutSeconds: 30,
        );

        expect(result, '纯净优化提示词');
      },
    );

    test('ignores thought parts in Gemini response', () async {
      final server = await _startServer((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'thought': true, 'text': 'Let me think carefully...'},
                    {'text': '真正输出的提示词'},
                  ],
                },
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final result = await const PromptOptimizationApi().optimize(
        prompt: '小女孩跳舞',
        direction: PromptOptimizationDirection.strengthen,
        profile: _profileFor(
          server,
          protocol: PromptOptimizationProtocol.geminiGenerateContent,
        ),
        timeoutSeconds: 30,
      );

      expect(result, '真正输出的提示词');
    });

    test(
      'ignores Claude thinking deltas and strips <think> tags from Chat',
      () async {
        final claudeServer = await _startServer((request) async {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'type': 'content_block_delta',
              'delta': {'type': 'thinking_delta', 'thinking': '内部思考'},
            })}\n\n'
            'data: ${jsonEncode({
              'type': 'content_block_delta',
              'delta': {'type': 'text_delta', 'text': 'Claude 净正文'},
            })}\n\n'
            'data: [DONE]\n\n',
          );
          await request.response.close();
        });
        addTearDown(claudeServer.close);

        final claudeResult = await const PromptOptimizationApi().optimize(
          prompt: '小女孩跳舞',
          direction: PromptOptimizationDirection.strengthen,
          profile: _profileFor(
            claudeServer,
            protocol: PromptOptimizationProtocol.claudeMessages,
          ),
          timeoutSeconds: 30,
        );
        expect(claudeResult, 'Claude 净正文');

        final chatServer = await _startServer((request) async {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '<think>我们需要回答中文，不要输出解释</think>\n一位小女孩在舞蹈教室起舞',
                  },
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(chatServer.close);

        final chatResult = await const PromptOptimizationApi().optimize(
          prompt: '小女孩跳舞',
          direction: PromptOptimizationDirection.strengthen,
          profile: _profileFor(
            chatServer,
            protocol: PromptOptimizationProtocol.openAiChatCompletions,
          ),
          timeoutSeconds: 30,
        );
        expect(chatResult, '一位小女孩在舞蹈教室起舞');
      },
    );
  });
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      await handler(request);
    }),
  );
  return server;
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

PromptOptimizationProfile _profileFor(
  HttpServer server, {
  required PromptOptimizationProtocol protocol,
}) {
  return PromptOptimizationProfile(
    id: 'optimizer',
    name: 'Optimizer',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'test-key',
    model: 'gpt-test',
    protocol: protocol,
  );
}
