import 'package:dio/dio.dart';

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';
import 'openai_client.dart';
import 'responses_image_api.dart';

class ImageGenerationApi {
  const ImageGenerationApi({this.requestLogService});

  final RequestLogService? requestLogService;

  Future<List<GenerationResult>> generate(
    GenerationRequest request,
    ApiProfile profile, {
    String? responseFormat,
    required int timeoutSeconds,
    CancelToken? cancelToken,
    void Function(String b64Json)? onPartialImage,
  }) async {
    final client = OpenAiClient(
      profile,
      timeoutSeconds: timeoutSeconds,
      requestLogService: requestLogService,
    );

    // 想要过程图就必须走流式：非流式要等最终图才返回。
    final wantsStreaming = profile.useStreaming || onPartialImage != null;

    if (profile.apiMode == ImageGenerationApiMode.responses) {
      final body = buildResponsesImageBody(
        request: request,
        profile: profile,
        input: request.prompt,
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

    final body = <String, dynamic>{
      'model': profile.model,
      'prompt': request.prompt,
      'n': 1,
      'quality': request.quality.apiValue,
      'output_format': request.outputFormat.apiValue,
    };
    if (request.apiSize != null) {
      body['size'] = request.apiSize;
    }
    // 透明背景：只有 PNG / WEBP 才有效，apiBackground 已把 JPEG 过滤掉。
    if (request.apiBackground != null) {
      body['background'] = request.apiBackground;
    }
    if (responseFormat != null && responseFormat.trim().isNotEmpty) {
      // GPT Image 2/2.5 and RightAPI reject the legacy response_format field.
      if (!_isGptImage2Family(profile.model) && !_isRightApiDraw(profile)) {
        body['response_format'] = responseFormat;
      }
    }

    if (_isRightApiDraw(profile)) {
      if (_isGptImage25Family(profile.model)) {
        // RightAPI currently interprets `size` as an aspect-ratio token for
        // the 2.5 channels. Those channels require the separate imageSize
        // selector instead (1K/2K/4K).
        body.remove('size');
        body['imageSize'] = _rightApiImageSize(request);
      }
      body['async'] = true;
      return _submitAndPollRightApi(
        client,
        body,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
    }

    final response = await _requestImages(
      client,
      body,
      useStreaming: wantsStreaming,
      onPartialImage: onPartialImage,
      cancelToken: cancelToken,
    );

    return _parseResults(response);
  }

  Future<Map<String, dynamic>> _requestImages(
    OpenAiClient client,
    Map<String, dynamic> body, {
    required bool useStreaming,
    required void Function(String b64Json)? onPartialImage,
    CancelToken? cancelToken,
  }) async {
    if (!useStreaming) {
      return client.postJson(
        '/v1/images/generations',
        body,
        cancelToken: cancelToken,
      );
    }

    try {
      return await client.postJsonStreaming(
        '/v1/images/generations',
        body,
        cancelToken: cancelToken,
        isImagesApi: true,
        // 过程图：让界面在等最终图时先看到画面。1 张足够，要太多反而拖慢。
        partialImages: onPartialImage == null ? 0 : 1,
        onPartialImage: onPartialImage,
      );
    } on ApiException catch (error) {
      // 少数中转站不认 stream / partial_images，会在出图之前直接 400。
      // 这种错误发生在生成之前，回退成普通请求不会重复计费。
      if (!_looksLikeStreamUnsupported(error.message)) {
        rethrow;
      }

      return client.postJson(
        '/v1/images/generations',
        body,
        cancelToken: cancelToken,
      );
    }
  }

  bool _looksLikeStreamUnsupported(String message) {
    final value = message.toLowerCase();
    // 注意别用 contains('stream')：'upstream request failed' 里也含 stream，
    // 会把上游的真实失败误判成“不支持流式”，白白再发一次请求（可能重复计费）。
    if (RegExp(r'\bstream(ing)?\b').hasMatch(value) ||
        value.contains('partial_image') ||
        value.contains('unsupported parameter') ||
        value.contains('unknown parameter') ||
        value.contains('unrecognized')) {
      return true;
    }

    // 中转站拒绝 stream 时不一定提“stream”这个词，常见就是 400 / 415 / 422。
    // 这些状态说明请求在生成之前就被拒了，回退成普通请求不会重复计费。
    final status = _statusCodeOf(message);
    return status == 400 || status == 415 || status == 422;
  }

  int? _statusCodeOf(String message) {
    final match = RegExp(r'^HTTP (\d{3})').firstMatch(message.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  bool _isRightApiDraw(ApiProfile profile) {
    final uri = Uri.tryParse(profile.normalizedBaseUrl);
    return uri != null &&
        uri.host.toLowerCase() == 'www.rightapi.ai' &&
        uri.path.toLowerCase().endsWith('/draw');
  }

  bool _isGptImage2Family(String model) {
    final value = model.trim().toLowerCase();
    return value == 'gpt-image-2' || value.startsWith('gpt-image-2.5-');
  }

  bool _isGptImage25Family(String model) {
    return model.trim().toLowerCase().startsWith('gpt-image-2.5-');
  }

  String _rightApiImageSize(GenerationRequest request) {
    final longestEdge = request.resolvedWidth > request.resolvedHeight
        ? request.resolvedWidth
        : request.resolvedHeight;
    if (longestEdge <= 1024) {
      return '1K';
    }
    if (longestEdge <= 2048) {
      return '2K';
    }
    return '4K';
  }

  Future<List<GenerationResult>> _submitAndPollRightApi(
    OpenAiClient client,
    Map<String, dynamic> body, {
    required int timeoutSeconds,
    CancelToken? cancelToken,
  }) async {
    final submitted = await client.postJson(
      '/v1/images/generations',
      body,
      cancelToken: cancelToken,
    );
    final taskId = submitted['task_id'];
    if (taskId is! String || taskId.trim().isEmpty) {
      // Some deployments return a synchronous Images response despite async=true.
      if (submitted['data'] is List) {
        return _parseResults(submitted);
      }
      throw const ApiException('RightAPI 异步提交未返回 task_id。');
    }

    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final task = await client.getJson(
        _rightApiTaskPath(taskId),
        cancelToken: cancelToken,
      );
      // RightAPI returns the final Images payload without a status field.
      if (task['data'] is List) {
        return _parseResults(task);
      }
      final status = task['status']?.toString().toLowerCase();
      if (status == 'completed') {
        return _parseResults(task);
      }
      if (status == 'failed' || status == 'cancelled') {
        throw ApiException(_rightApiTaskError(task));
      }
    }
    throw const ApiException('RightAPI 异步任务轮询超时。');
  }

  String _rightApiTaskPath(String taskId) {
    // OpenAiClient's base URL is /draw; task lookup is site-level, so use an
    // absolute URL understood by Dio.
    return 'https://www.rightapi.ai/v1/tasks/${Uri.encodeComponent(taskId)}';
  }

  String _rightApiTaskError(Map<String, dynamic> task) {
    final error = task['error'];
    if (error is Map && error['message'] is String) {
      return 'RightAPI 任务失败：${error['message']}';
    }
    return 'RightAPI 任务失败。';
  }

  List<GenerationResult> _parseResults(Map<String, dynamic> response) {
    final payload = response['data'];
    if (payload is! List) {
      throw const ApiException('接口响应缺少图片数据。');
    }
    if (payload.isEmpty) {
      throw const ApiException(
        '接口返回成功，但响应里没有图片数据。'
        '常见原因是提示词被审核拒绝，或该模型不支持当前参数。',
      );
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
