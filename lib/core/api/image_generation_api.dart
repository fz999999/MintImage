import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'api_request_logger.dart';
import 'image_task_api.dart';
import 'openai_client.dart';
import 'openrouter_image_api.dart';
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
    void Function(String b64Json)? onPartialImage,
  }) async {
    final validation = request.validate(
      usesResponsesApi: profile.apiMode == ImageGenerationApiMode.responses,
    );
    if (validation != null) throw ApiException(validation);
    if (profile.resolvedSafetyIdentifier != null &&
        profile.resolvedSafetyIdentifier!.length > 128) {
      throw const ApiException('安全标识最多 128 个字符。');
    }
    if (request.markupPath != null) {
      throw const ApiException('标注引导需要通过图生图接口提交。');
    }

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
        onPartialImage: onPartialImage,
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
    void Function(String b64Json)? onPartialImage,
  }) async {
    // 想要过程图就必须走流式：非流式要等最终图才返回。
    final wantsStreaming = profile.useStreaming || onPartialImage != null;

    if (profile.apiMode == ImageGenerationApiMode.responses) {
      final body = buildResponsesImageBody(
        request: request,
        profile: profile,
        action: 'generate',
      );
      final response = wantsStreaming
          ? await client.postJsonStreaming(
              '/v1/responses',
              body,
              cancelToken: cancelToken,
              onPartialImage: onPartialImage,
            )
          : await client.postJson(
              '/v1/responses',
              body,
              cancelToken: cancelToken,
            );
      return parseResponsesImageResults(response);
    }
    if (profile.isOpenRouterImages) {
      return requestOpenRouterImages(
        client,
        request,
        profile,
        cancelToken: cancelToken,
      );
    }

    final body = <String, dynamic>{
      'model': profile.model,
      'prompt': request.prompt,
      'n': 1,
      'quality': request.quality.apiValue,
      'output_format': request.outputFormat.apiValue,
      if (profile.resolvedSafetyIdentifier != null)
        'safety_identifier': profile.resolvedSafetyIdentifier,
      if (request.outputFormat == ImageOutputFormat.svg &&
          request.svgOptions != null)
        'svg': request.svgOptions!.toJson(),
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
    // 透明背景：只有 PNG / WEBP 才有效，apiBackground 已把 JPEG/GIF/SVG 过滤掉。
    if (request.apiBackground != null) {
      body['background'] = request.apiBackground;
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
      // GPT Image 2+ 省略旧版 response_format；异步任务接口返回 URL。
      if (!_isGptImage2Family(profile.model) && !useAsync) {
        body['response_format'] = responseFormat;
      }
    }

    final response = await requestImageResult(
      client: client,
      timeoutSeconds: timeoutSeconds,
      cancelToken: cancelToken,
      submit: () => _submitImages(
        client,
        profile,
        body,
        useStreaming:
            wantsStreaming &&
            !useAsync &&
            !request.outputFormat.requiresImagesGeneration,
        onPartialImage: onPartialImage,
        cancelToken: cancelToken,
      ),
    );

    return parseImagesApiResults(response);
  }

  Future<Map<String, dynamic>> _submitImages(
    OpenAiClient client,
    ApiProfile profile,
    Map<String, dynamic> body, {
    required bool useStreaming,
    required void Function(String b64Json)? onPartialImage,
    CancelToken? cancelToken,
  }) async {
    if (!useStreaming) {
      return client.postJson(
        profile.generationPath,
        body,
        cancelToken: cancelToken,
      );
    }

    try {
      return await client.postJsonStreaming(
        profile.generationPath,
        body,
        cancelToken: cancelToken,
        isImagesApi: true,
        partialImages: onPartialImage == null ? 0 : 1,
        onPartialImage: onPartialImage,
      );
    } on ApiException catch (error) {
      if (error is MissingImageDataException ||
          !_looksLikeStreamUnsupported(error.message)) {
        rethrow;
      }

      return client.postJson(
        profile.generationPath,
        body,
        cancelToken: cancelToken,
      );
    }
  }

  bool _looksLikeStreamUnsupported(String message) {
    final value = message.toLowerCase();
    if (RegExp(r'\bstream(ing)?\b').hasMatch(value) ||
        value.contains('partial_image') ||
        value.contains('unsupported parameter') ||
        value.contains('unknown parameter') ||
        value.contains('unrecognized')) {
      return true;
    }

    final status = _statusCodeOf(message);
    return status == 400 || status == 415 || status == 422;
  }

  int? _statusCodeOf(String message) {
    final match = RegExp(r'^HTTP (\d{3})').firstMatch(message.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase().split('/').last;
    return RegExp(r'^gpt-image-2(?:\.\d+)?(?:-|$)').hasMatch(value);
  }
}
