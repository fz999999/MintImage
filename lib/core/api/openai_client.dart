import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/settings_model.dart';
import '../services/request_log_service.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenAiClient {
  OpenAiClient(
    ApiProfile profile, {
    required int timeoutSeconds,
    RequestLogService? requestLogService,
  }) : _requestLogService = requestLogService,
       _dio = Dio(
         BaseOptions(
           baseUrl: profile.normalizedBaseUrl,
           connectTimeout: Duration(seconds: timeoutSeconds),
           sendTimeout: Duration(seconds: timeoutSeconds),
           receiveTimeout: Duration(seconds: timeoutSeconds),
           headers: {
             'Authorization': 'Bearer ${profile.apiKey.trim()}',
             'Accept': 'application/json',
           },
         ),
       );

  final Dio _dio;
  final RequestLogService? _requestLogService;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final title = 'POST $path';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '请求体:\n${_prettyJson(body)}',
      ),
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(response.data)}',
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        cancelToken: cancelToken,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(extractErrorMessage(error));
    }
  }

  /// 流式请求，支持 Responses API 和 Images API 两种格式。
  ///
  /// [isImagesApi] 为 true 时解析 Image API 的 partial/completed 事件，
  /// 返回格式与 Images API 非流式响应一致 `{data: [{b64_json: ...}]}`。
  /// 为 false 时（Responses API）解析 `response.completed` / `response.output_item.done`，
  /// 返回格式 `{output: [...]}` 与 `parseResponsesImageResults` 兼容。
  ///
  /// [partialImages] 是向服务器索要的过程图数量（Images API 的 `partial_images`，
  /// 只有 0~3 有效；0 表示只要最终图）。收到过程图时会回调 [onPartialImage]，
  /// 让界面在等待最终图时就能显示进度。
  Future<Map<String, dynamic>> postJsonStreaming(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
    bool isImagesApi = false,
    int partialImages = 0,
    void Function(String b64Json)? onPartialImage,
  }) async {
    final streamBody = Map<String, dynamic>.from(body)..['stream'] = true;
    if (isImagesApi) {
      streamBody['partial_images'] = partialImages;
    }

    final stopwatch = Stopwatch()..start();
    final title = 'POST $path (stream)';

    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '请求体:\n${_prettyJson(streamBody)}',
      ),
    );

    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: streamBody,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );

      final result = await _readStreamResponse(
        response,
        isImagesApi: isImagesApi,
        onPartialImage: onPartialImage,
      );
      stopwatch.stop();

      if (isImagesApi) {
        final data = result['data'];
        final receivedImage = data is List && data.isNotEmpty;
        unawaited(
          _requestLogService?.logResponse(
            title,
            '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
            '状态码: ${response.statusCode ?? 'unknown'}\n'
            '流式响应，Images API，收到最终图片: $receivedImage',
          ),
        );
      } else {
        final output = result['output'];
        final outputCount = output is List ? output.length : 0;
        unawaited(
          _requestLogService?.logResponse(
            title,
            '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
            '状态码: ${response.statusCode ?? 'unknown'}\n'
            '流式响应，Responses API，收到 $outputCount 个图片结果',
          ),
        );
      }

      return result;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  Future<Map<String, dynamic>> postMultipartStreaming(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
    int partialImages = 0,
    void Function(String b64Json)? onPartialImage,
  }) async {
    formData.fields.addAll([
      const MapEntry('stream', 'true'),
      MapEntry('partial_images', '$partialImages'),
    ]);

    final stopwatch = Stopwatch()..start();
    final title = 'POST $path (stream)';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '表单字段:\n${_prettyJson(_fieldsMap(formData))}\n'
        '上传文件:\n${_fileSummary(formData)}',
      ),
    );

    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: formData,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final result = await _readStreamResponse(
        response,
        isImagesApi: true,
        onPartialImage: onPartialImage,
      );
      stopwatch.stop();
      final data = result['data'];
      final receivedImage = data is List && data.isNotEmpty;
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '流式响应，Images API，收到最终图片: $receivedImage',
        ),
      );
      return result;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final title = 'POST $path';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '表单字段:\n${_prettyJson(_fieldsMap(formData))}\n'
        '上传文件:\n${_fileSummary(formData)}',
      ),
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: formData,
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(response.data)}',
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  /// 读取流式响应。
  ///
  /// 绝大多数中转站会按 SSE 推送；但也有实现忽略 `stream` 参数、直接返回一整包
  /// JSON。这时按普通 JSON 解析，避免白等一场之后报“没有图片数据”。
  Future<Map<String, dynamic>> _readStreamResponse(
    Response<ResponseBody> response, {
    required bool isImagesApi,
    void Function(String b64Json)? onPartialImage,
  }) async {
    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';

    if (!contentType.contains('event-stream')) {
      final body = response.data;
      String? text;
      if (body != null) {
        final buffer = <int>[];
        await for (final chunk in body.stream) {
          buffer.addAll(chunk);
        }
        text = utf8.decode(buffer, allowMalformed: true);
      }

      final decoded = text == null ? null : _tryDecodeJsonObject(text);
      if (decoded != null) {
        return decoded;
      }

      final preview = (text ?? '').trim();
      throw ApiException(
        preview.isEmpty
            ? '接口返回了空响应。'
            : '接口返回了无法解析的内容：${_truncate(preview, 300)}',
      );
    }

    return _readStreamingResult(
      response.data,
      isImagesApi: isImagesApi,
      onPartialImage: onPartialImage,
    );
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _readStreamingResult(
    ResponseBody? responseBody, {
    required bool isImagesApi,
    void Function(String b64Json)? onPartialImage,
  }) async {
    if (responseBody == null) {
      return isImagesApi ? {'data': []} : {'output': []};
    }

    String? lastImagesB64;
    String? lastPartialB64;
    final outputItems = <Map<String, dynamic>>[];
    Map<String, dynamic>? completedResponse;
    String? currentEventType;

    await for (final rawLine
        in responseBody.stream
            .map<List<int>>((chunk) => chunk)
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        currentEventType = null;
        continue;
      }

      if (line.startsWith('event:')) {
        currentEventType = line.substring('event:'.length).trim();
        continue;
      }

      if (!line.startsWith('data:')) {
        continue;
      }

      final dataStr = line.substring('data:'.length).trim();
      if (dataStr.isEmpty || dataStr == '[DONE]') {
        continue;
      }

      try {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        final eventType = currentEventType ?? data['type'] as String?;

        if (isImagesApi) {
          if (_isImageStreamResultEvent(eventType)) {
            final b64 = data['b64_json'] as String?;
            if (b64 != null && b64.isNotEmpty) {
              final isPartial = eventType?.endsWith('.partial_image') ?? false;
              if (isPartial) {
                lastPartialB64 = b64;
                onPartialImage?.call(b64);
              } else {
                lastImagesB64 = b64;
              }
            }
          }
        } else if (eventType == 'response.completed') {
          final resp = data['response'];
          if (resp is Map) {
            completedResponse = Map<String, dynamic>.from(resp);
          }
        } else if (eventType == 'response.output_item.done') {
          final item = data['item'];
          if (item is Map) {
            outputItems.add(Map<String, dynamic>.from(item));
          }
        } else if (eventType ==
            'response.image_generation_call.partial_image') {
          final b64 = data['b64_json'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            onPartialImage?.call(b64);
            outputItems.add({
              'type': 'image_generation_call',
              'result': {'b64_json': b64},
            });
          }
        }
      } catch (_) {}
    }

    if (isImagesApi) {
      // 有些中转站只推过程图、不推 completed 事件；这时用最后一张过程图兜底，
      // 否则用户等了几十秒却拿到“没有可展示的图片数据”。
      final imageB64 = lastImagesB64 ?? lastPartialB64;
      return {
        'data': [
          if (imageB64 != null) {'b64_json': imageB64},
        ],
      };
    }

    return completedResponse ?? {'output': outputItems};
  }

  bool _isImageStreamResultEvent(String? eventType) {
    return eventType == 'image_generation.completed' ||
        eventType == 'image_generation.partial_image' ||
        eventType == 'image_edit.completed' ||
        eventType == 'image_edit.partial_image';
  }

  static String extractErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? apiMessage;

    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      final nestedError = map['error'];

      if (nestedError is Map && nestedError['message'] is String) {
        apiMessage = nestedError['message'] as String;
      }

      apiMessage ??= switch (map['message']) {
        String value => value,
        _ => null,
      };
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      apiMessage = responseData.trim();
    }

    if (apiMessage != null && apiMessage.isNotEmpty) {
      return _withStatusCode(apiMessage, statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请检查超时设置或稍后重试。';
      case DioExceptionType.connectionError:
        return _withStatusCode('网络连接失败，请检查网络或 Base URL。', statusCode);
      case DioExceptionType.badCertificate:
        return _withStatusCode('证书校验失败，请检查 HTTPS 配置。', statusCode);
      case DioExceptionType.badResponse:
        return _withStatusCode('请求失败，请检查接口返回。', statusCode);
      case DioExceptionType.cancel:
        return '请求已取消。';
      default:
        // 覆盖 DioExceptionType.unknown，以及 dio 后续版本新增的类型
        // （例如 5.10.0 新增的 transformTimeout），避免 switch 穷尽性失配。
        return _withStatusCode(error.message ?? '请求失败，请稍后重试。', statusCode);
    }
  }

  static String _withStatusCode(String message, int? statusCode) {
    if (statusCode == null) {
      return message;
    }

    return 'HTTP $statusCode：$message';
  }

  Map<String, dynamic> _fieldsMap(FormData formData) {
    return {for (final field in formData.fields) field.key: field.value};
  }

  String _fileSummary(FormData formData) {
    final files = formData.files
        .map((item) => '${item.key}: ${item.value.filename ?? 'unknown'}')
        .toList();
    return files.isEmpty ? '(无)' : files.join('\n');
  }

  String _summarizeData(Object? data) {
    if (data == null) {
      return '(空)';
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final payload = map['data'];
      if (payload is List) {
        map['data'] = {'count': payload.length};
      }
      return _prettyJson(map);
    }

    return _truncate(data.toString());
  }

  String _prettyJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return _truncate(value.toString());
    }
  }

  String _truncate(String text, [int maxLength = 5000]) {
    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }
}
