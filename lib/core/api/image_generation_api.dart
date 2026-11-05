import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'image_task_api.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';

class ImageGenerationApi {
  const ImageGenerationApi({this.requestLogService});

  final ApiRequestLogger? requestLogService;

  Future<List<GenerationResult>> generate(
    GenerationRequest request,
    ApiProfile profile, {
    String? responseFormat,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final validation = request.validate(
      usesResponsesApi: profile.apiMode == ImageGenerationApiMode.responses,
    );
    if (validation != null) throw ApiException(validation);
    final client = OpenAiClient(
      profile,
      timeoutSeconds: timeoutSeconds,
      requestLogService: requestLogService,
    );

    try {
      return await _generate(
        client,
        request,
        profile,
        responseFormat: responseFormat,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
    } finally {
      client.close();
    }
  }

  Future<List<GenerationResult>> _generate(
    OpenAiClient client,
    GenerationRequest request,
    ApiProfile profile, {
    String? responseFormat,
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    if (profile.apiMode == ImageGenerationApiMode.responses) {
      final body = buildResponsesImageBody(
        request: request,
        profile: profile,
        input: request.prompt,
        action: 'generate',
      );
      final response = profile.useStreaming
          ? await client.postJsonStreaming(
              '/v1/responses',
              body,
              cancelToken: cancelToken,
            )
          : await client.postJson(
              '/v1/responses',
              body,
              cancelToken: cancelToken,
            );
      return parseResponsesImageResults(response);
    }

    final body = <String, dynamic>{
      'model': profile.model,
      'prompt': request.prompt,
      'n': 1,
      'quality': request.quality.apiValue,
      'output_format': request.outputFormat.apiValue,
      if (request.complexity != null)
        'complexity': request.complexity!.apiValue,
      if (request.outputFormat == ImageOutputFormat.gif) ...{
        'frame_count': request.frameCount,
        'frame_duration_ms': request.frameDurationMs,
      },
    };
    final useAsync = profile.apiMode == ImageGenerationApiMode.imagesAsync;
    if (useAsync) {
      body['async'] = true;
    }
    if (request.apiSize != null) {
      body['size'] = request.apiSize;
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
      // GPT Image models omit this legacy field; task APIs return URLs.
      if (!_isGptImage2Family(profile.model) && !useAsync) {
        body['response_format'] = responseFormat;
      }
    }

    final response = await requestImageResult(
      client: client,
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
      submit: () =>
          profile.useStreaming &&
              !useAsync &&
              !request.outputFormat.requiresImagesGeneration
          ? client.postJsonStreaming(
              '/v1/images/generations',
              body,
              cancelToken: cancelToken,
              isImagesApi: true,
            )
          : client.postJson(
              '/v1/images/generations',
              body,
              cancelToken: cancelToken,
            ),
    );

    return _parseResults(response);
  }

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase();
    return RegExp(r'^gpt-image-2(?:\.\d+)?(?:-|$)').hasMatch(value);
  }

  List<GenerationResult> _parseResults(Map<String, dynamic> response) {
    final payload = response['data'];
    if (payload is! List) {
      throw const ApiException('接口响应缺少图片数据。');
    }

    return payload.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final rawResponseValue =
          map['b64_json'] as String? ?? map['url'] as String?;
      return GenerationResult(
        b64Json: map['b64_json'] as String?,
        imageUrl: map['url'] as String?,
        rawResponseValue: rawResponseValue,
      );
    }).toList();
  }
}
