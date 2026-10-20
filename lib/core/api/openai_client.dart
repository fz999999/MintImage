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

      String? stats;
      final result = await _readStreamResponse(
        response,
        isImagesApi: isImagesApi,
        onPartialImage: onPartialImage,
        onStats: (value) => stats = value,
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
            '流式响应，Images API，收到最终图片: $receivedImage\n'
            '流式统计: ${stats ?? '未知'}',
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
            '流式响应，Responses API，收到 $outputCount 个图片结果\n'
            '流式统计: ${stats ?? '未知'}',
          ),
        );
      }

      return result;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = await _errorMessageFor(error);
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
      String? stats;
      final result = await _readStreamResponse(
        response,
        isImagesApi: true,
        onPartialImage: onPartialImage,
        onStats: (value) => stats = value,
      );
      stopwatch.stop();
      final data = result['data'];
      final receivedImage = data is List && data.isNotEmpty;
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '流式响应，Images API，收到最终图片: $receivedImage\n'
          '流式统计: ${stats ?? '未知'}',
        ),
      );
      return result;
    } on DioException catch (error) {
      stopwatch.stop();
      final message = await _errorMessageFor(error);
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
    void Function(String stats)? onStats,
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
      onStats: onStats,
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
    void Function(String stats)? onStats,
  }) async {
    if (responseBody == null) {
      return isImagesApi ? {'data': []} : {'output': []};
    }

    String? lastImagesB64;
    String? lastPartialB64;
    String? streamError;
    final outputItems = <Map<String, dynamic>>[];
    Map<String, dynamic>? completedResponse;
    String? currentEventType;
    final eventNames = <String>{};
    var totalBytes = 0;
    var parseFailures = 0;

    await for (final rawLine
        in responseBody.stream
            .map<List<int>>((chunk) {
              totalBytes += chunk.length;
              return chunk;
            })
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        currentEventType = null;
        continue;
      }

      if (line.startsWith('event:')) {
        currentEventType = line.substring('event:'.length).trim();
        if (currentEventType.isNotEmpty) {
          eventNames.add(currentEventType);
        }
        continue;
      }

      if (!line.startsWith('data:')) {
        continue;
      }

      final dataStr = line.substring('data:'.length).trim();
      if (dataStr.isEmpty || dataStr == '[DONE]') {
        continue;
      }

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(dataStr);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // 半截行（连接被掐断）或非 JSON 的 data 段，跳过继续读。
        parseFailures++;
      }

      if (data == null) {
        continue;
      }

      final eventType = currentEventType ?? data['type'] as String?;

      // 上游把失败也塞在 200 的流里（审核拒绝、参数不支持、通道报错等），
      // 不捞出来用户就只能看到“没有图片数据”。
      final errorMessage = _extractStreamError(data);
      if (errorMessage != null) {
        streamError ??= errorMessage;
        continue;
      }

      if (isImagesApi) {
        // 不按事件名硬匹配：中转站的命名五花八门（也常只给 type、不给 event），
        // 只要 JSON 里带图片就认。否则 200 却“没图”，用户白等一分钟。
        final b64 = _extractImageB64(data);
        if (b64 != null) {
          final isPartial = eventType?.endsWith('.partial_image') ?? false;
          if (isPartial) {
            lastPartialB64 = b64;
            onPartialImage?.call(b64);
          } else {
            lastImagesB64 = b64;
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
        final b64 = _extractImageB64(data);
        if (b64 != null) {
          onPartialImage?.call(b64);
          outputItems.add({
            'type': 'image_generation_call',
            'result': {'b64_json': b64},
          });
        }
      }
    }

    if (isImagesApi) {
      // 有些中转站只推过程图、不推 completed 事件；这时用最后一张过程图兜底，
      // 否则用户等了几十秒却拿到“没有可展示的图片数据”。
      final imageB64 = lastImagesB64 ?? lastPartialB64;
      onStats?.call(
        '字节=$totalBytes 事件=${eventNames.join(',')} '
        '解析失败=$parseFailures '
        '完成图=${lastImagesB64 != null} 过程图=${lastPartialB64 != null}'
        '${streamError == null ? '' : ' 错误=$streamError'}',
      );
      if (imageB64 == null) {
        throw ApiException(
          _withUpstreamHint(
            streamError ??
                '流式响应已经结束，但没有收到图片数据。'
                    '常见原因是提示词被审核拒绝，或该模型不支持当前参数（尺寸/画质/透明背景）。',
          ),
        );
      }
      return {
        'data': [
          {'b64_json': imageB64},
        ],
      };
    }

    onStats?.call('字节=$totalBytes 事件=${eventNames.join(',')}');
    return completedResponse ?? {'output': outputItems};
  }

  /// 从任意流式 JSON 片段里挖出 base64 图片，兼容几种常见的嵌套写法。
  String? _extractImageB64(Map<String, dynamic> data) {
    final direct = data['b64_json'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }

    final nested = data['result'];
    if (nested is Map) {
      final inner = nested['b64_json'] ?? nested['base64'] ?? nested['image'];
      if (inner is String && inner.isNotEmpty) {
        return inner;
      }
    }

    final list = data['data'];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final value = item['b64_json'] ?? item['base64'];
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
    }

    return null;
  }

  /// 从流式片段里识别上游错误，返回可直接展示的中文消息。
  String? _extractStreamError(Map<String, dynamic> data) {
    final error = data['error'];

    if (error is Map) {
      final message = error['message'] ?? error['detail'] ?? error['code'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    final type = data['type'];
    if (type == 'error') {
      final message = data['message'] ?? data['detail'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      return '上游返回了错误事件。';
    }

    // 没有图片、只有 message 的片段，多半也是错误提示。
    if (_extractImageB64(data) == null) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return null;
  }

  /// 上游把失败塞进 200 的流里时，原始消息往往只有一句英文
  /// （例如 `upstream request failed`），补一句能落地的建议。
  static String _withUpstreamHint(String message) {
    final lower = message.toLowerCase();
    final looksUpstream = lower.contains('upstream') ||
        lower.contains('failed') ||
        lower.contains('error');
    if (!looksUpstream || message.contains('（')) {
      return message;
    }
    return '$message（上游生成失败，常见原因是提示词被审核拦截或该参数不支持，换个描述或关掉透明背景再试）';
  }

  /// 流式请求失败时，错误体是 [ResponseBody]，得先把原始字节读出来才能拿到
  /// 上游给的 message（否则只能显示“请求失败，请检查接口返回。”）。
  Future<String> _errorMessageFor(DioException error) async {
    final data = error.response?.data;

    if (data is ResponseBody) {
      try {
        final buffer = <int>[];
        await for (final chunk in data.stream) {
          buffer.addAll(chunk);
          if (buffer.length > 8192) {
            break;
          }
        }

        final text = utf8.decode(buffer, allowMalformed: true).trim();
        final decoded = _tryDecodeJsonObject(text);
        String? apiMessage;

        if (decoded != null) {
          final nested = decoded['error'];
          if (nested is Map && nested['message'] is String) {
            apiMessage = (nested['message'] as String).trim();
          }
          apiMessage ??= switch (decoded['message']) {
            String value => value.trim(),
            _ => null,
          };
        }

        final detail = (apiMessage != null && apiMessage.isNotEmpty)
            ? apiMessage
            : (text.isEmpty ? null : _truncate(text, 300));

        if (detail != null && detail.isNotEmpty) {
          return _withStatusCode(detail, error.response?.statusCode);
        }
      } catch (_) {
        // 读不到就用通用文案。
      }
    }

    return extractErrorMessage(error);
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
