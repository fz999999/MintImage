import 'dart:async';

import 'package:dio/dio.dart';

import '../models/balance_query.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';

/// 余额查询失败。[message] 直接展示给用户，所以要写成人话。
class BalanceQueryException implements Exception {
  const BalanceQueryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 一次成功的余额查询结果。
class BalanceQueryResult {
  BalanceQueryResult({
    required this.text,
    required this.mode,
    required this.source,
    this.detail,
    this.amount,
    this.unlimited = false,
  }) : fetchedAt = DateTime.now();

  /// 已经格式化好的展示文本，例如 `$10.68`、`不限`。
  final String text;

  final BalanceQueryMode mode;

  /// 数据来源，例如 `/v1/usage`。
  final String source;

  /// 补充说明，例如 `今日消耗 $0.28`。
  final String? detail;

  /// 解析出来的原始金额（美元），自定义接口下可能为 null。
  final double? amount;

  /// 中转站说这个 Key 不限额度（拿不到具体数字）。
  final bool unlimited;

  final DateTime fetchedAt;

  String get tooltip {
    final lines = <String>['来源：$source'];
    if (detail != null && detail!.isNotEmpty) {
      lines.add(detail!);
    }
    lines.add('查询时间：${_formatTime(fetchedAt)}');
    return lines.join('\n');
  }

  static String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }
}

/// 中转站余额查询。
///
/// 各家面板的公开接口不一样，[BalanceQueryMode] 对应几套预设：
/// - AIHub：`GET /v1/usage` → `{"balance": 10.68, "daily_usage": [...]}`
/// - one-api / new-api：`GET /api/usage/token` → `data.total_available`（额度，500000 = 1 美元）
/// - one-api / new-api 账户：`GET /api/user/self` → `data.quota`（需系统访问令牌）
/// - OpenAI 兼容账单：`GET /v1/dashboard/billing/subscription` + `/usage`
class BalanceQueryApi {
  const BalanceQueryApi({this.requestLogService});

  final RequestLogService? requestLogService;

  /// one-api / new-api 的额度单位：500000 额度 = 1 美元。
  static const double quotaPerUsd = 500000;

  /// one-api 用 1e8 表示「不限额度」，这里留一个数量级的安全边界。
  static const double unlimitedUsdSentinel = 1e7;

  /// Cloudflare 会拦掉默认的 Dart UA（错误码 1010），统一伪装成浏览器。
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// 已经有兜底结果时，后续补充查询的超时（秒）。
  static const int _followUpTimeoutSeconds = 5;

  Future<BalanceQueryResult> query({
    required ApiProfile profile,
    required BalanceQueryConfig config,
    int timeoutSeconds = 15,
  }) async {
    final apiKey = profile.apiKey.trim();
    final accessToken = config.accessToken.trim();
    if (apiKey.isEmpty && accessToken.isEmpty) {
      throw const BalanceQueryException('还没有填写 API Key。');
    }

    final attempts = <Future<BalanceQueryResult> Function(int timeoutSeconds)>[];
    switch (config.mode) {
      case BalanceQueryMode.auto:
        attempts.add((timeout) => _queryUsage(profile, apiKey, timeout));
        if (accessToken.isNotEmpty) {
          attempts.add((timeout) => _queryAccount(profile, accessToken, timeout));
        }
        attempts.add((timeout) => _queryToken(profile, apiKey, timeout));
        attempts.add((timeout) => _queryBilling(profile, apiKey, timeout));
      case BalanceQueryMode.usage:
        attempts.add((timeout) => _queryUsage(profile, apiKey, timeout));
      case BalanceQueryMode.account:
        attempts.add(
          (timeout) => _queryAccount(
            profile,
            accessToken.isEmpty ? apiKey : accessToken,
            timeout,
          ),
        );
      case BalanceQueryMode.token:
        attempts.add((timeout) => _queryToken(profile, apiKey, timeout));
      case BalanceQueryMode.billing:
        attempts.add((timeout) => _queryBilling(profile, apiKey, timeout));
      case BalanceQueryMode.custom:
        attempts.add((timeout) => _queryCustom(profile, config, apiKey, timeout));
    }

    final errors = <String>[];
    BalanceQueryResult? fallback;
    for (final attempt in attempts) {
      // 已经拿到「不限额度」这种兜底结果时，后面的接口只当锦上添花，
      // 别让用户干等 15 秒。
      final timeout = fallback == null ? timeoutSeconds : _followUpTimeoutSeconds;
      try {
        final result = await attempt(timeout);
        if (result.unlimited) {
          // 「不限额度」先留着，但继续找能读到真实余额的接口。
          fallback ??= result;
          continue;
        }
        return result;
      } on BalanceQueryException catch (error) {
        errors.add(error.message);
      } catch (error) {
        errors.add('$error');
      }
    }

    if (fallback != null) {
      return fallback;
    }
    if (errors.isEmpty) {
      throw const BalanceQueryException('没有可用的余额查询方式。');
    }
    throw BalanceQueryException(errors.length == 1 ? errors.first : errors.join('；'));
  }

  // ---------------------------------------------------------------- AIHub

  Future<BalanceQueryResult> _queryUsage(
    ApiProfile profile,
    String apiKey,
    int timeoutSeconds,
  ) async {
    final url = '${_baseUrl(profile)}/v1/usage';
    final response = await _get(
      url: url,
      headers: _bearer(apiKey),
      timeoutSeconds: timeoutSeconds,
      label: 'AIHub 用量',
    );
    if (response.status == 401 || response.status == 403) {
      throw const BalanceQueryException('用量接口拒绝了这个 Key（401/403）。');
    }
    final body = _asMap(response.data);
    if (body == null) {
      throw BalanceQueryException('用量接口返回的不是 JSON（HTTP ${response.status}）。');
    }
    final balance =
        _asDouble(body['balance']) ?? _asDouble(_dig(body, 'data.balance'));
    if (balance == null) {
      throw BalanceQueryException(
        response.status >= 400
            ? '用量接口返回 HTTP ${response.status}。'
            : '用量接口里没有 balance 字段。',
      );
    }
    final todayCost = _sumTodayCost(body['daily_usage']);
    return BalanceQueryResult(
      text: _formatUsd(balance),
      mode: BalanceQueryMode.usage,
      source: '/v1/usage',
      detail: todayCost != null && todayCost > 0
          ? '今日消耗 ${_formatUsd(todayCost)}'
          : null,
      amount: balance,
    );
  }

  // ------------------------------------------------- one-api 账户余额

  Future<BalanceQueryResult> _queryAccount(
    ApiProfile profile,
    String token,
    int timeoutSeconds,
  ) async {
    final url = '${_baseUrl(profile)}/api/user/self';
    final response = await _get(
      url: url,
      headers: _bearer(token),
      timeoutSeconds: timeoutSeconds,
      label: '账户余额',
    );
    if (response.status == 401 || response.status == 403) {
      throw const BalanceQueryException(
        '账户接口需要访问令牌：请在中转站面板「个人设置 → 系统访问令牌」生成后填入。',
      );
    }
    final data = _asMap(_asMap(response.data)?['data']);
    if (data == null) {
      throw BalanceQueryException('账户接口没有返回数据（HTTP ${response.status}）。');
    }
    final quota = _asDouble(data['quota']);
    if (quota == null) {
      throw const BalanceQueryException('账户接口里没有 quota 字段。');
    }
    final used = _asDouble(data['used_quota']);
    final amount = quota / quotaPerUsd;
    return BalanceQueryResult(
      text: _formatUsd(amount),
      mode: BalanceQueryMode.account,
      source: '/api/user/self',
      detail: used == null
          ? null
          : '已使用 ${_formatUsd(used / quotaPerUsd)}',
      amount: amount,
    );
  }

  // -------------------------------------------- one-api 令牌剩余额度

  Future<BalanceQueryResult> _queryToken(
    ApiProfile profile,
    String apiKey,
    int timeoutSeconds,
  ) async {
    final url = '${_baseUrl(profile)}/api/usage/token';
    final response = await _get(
      url: url,
      headers: _bearer(apiKey),
      timeoutSeconds: timeoutSeconds,
      label: '令牌额度',
    );
    if (response.status == 401 || response.status == 403) {
      throw const BalanceQueryException('令牌额度接口拒绝了这个 Key（401/403）。');
    }
    final data = _asMap(_asMap(response.data)?['data']);
    if (data == null) {
      throw BalanceQueryException('令牌额度接口没有返回 data（HTTP ${response.status}）。');
    }
    final usedQuota = _asDouble(data['total_used']);
    final usedText = usedQuota == null
        ? null
        : '已用 ${_formatUsd(usedQuota / quotaPerUsd)}';
    if (data['unlimited_quota'] == true) {
      return BalanceQueryResult(
        text: '不限',
        mode: BalanceQueryMode.token,
        source: '/api/usage/token',
        detail: [
          '这个 Key 不限额度，实际从账户余额扣费',
          '想要具体数字，在「余额查询」里填上访问令牌',
          ?usedText,
        ].join('，'),
        unlimited: true,
      );
    }
    final available = _asDouble(data['total_available']);
    if (available == null) {
      throw const BalanceQueryException('令牌额度接口里没有 total_available 字段。');
    }
    final amount = available / quotaPerUsd;
    return BalanceQueryResult(
      text: _formatUsd(amount),
      mode: BalanceQueryMode.token,
      source: '/api/usage/token',
      detail: [
        '这个 Key 的剩余额度',
        ?usedText,
      ].join('，'),
      amount: amount,
    );
  }

  // -------------------------------------------- OpenAI 兼容账单

  Future<BalanceQueryResult> _queryBilling(
    ApiProfile profile,
    String apiKey,
    int timeoutSeconds,
  ) async {
    final base = _baseUrl(profile);
    final subscription = await _get(
      url: '$base/v1/dashboard/billing/subscription',
      headers: _bearer(apiKey),
      timeoutSeconds: timeoutSeconds,
      label: '订阅额度',
    );
    if (subscription.status == 401 || subscription.status == 403) {
      throw const BalanceQueryException('账单接口拒绝了这个 Key（401/403）。');
    }
    final subBody = _asMap(subscription.data);
    if (subBody == null) {
      throw BalanceQueryException(
        '账单接口返回的不是 JSON（HTTP ${subscription.status}）。',
      );
    }
    final hardLimit =
        _asDouble(subBody['hard_limit_usd']) ??
        _asDouble(subBody['soft_limit_usd']) ??
        _asDouble(subBody['system_hard_limit_usd']);
    if (hardLimit == null) {
      throw const BalanceQueryException('账单接口里没有 hard_limit_usd 字段。');
    }

    final usage = await _get(
      url: '$base/v1/dashboard/billing/usage',
      headers: _bearer(apiKey),
      timeoutSeconds: timeoutSeconds,
      label: '已用额度',
    );
    final usedCents = _asDouble(_asMap(usage.data)?['total_usage']) ?? 0;
    final usedUsd = usedCents / 100;

    if (hardLimit >= unlimitedUsdSentinel) {
      return BalanceQueryResult(
        text: '不限',
        mode: BalanceQueryMode.billing,
        source: '/v1/dashboard/billing',
        detail: 'Provider 声称额度不限，已用 ${_formatUsd(usedUsd)}',
        unlimited: true,
      );
    }

    final remaining = hardLimit - usedUsd;
    return BalanceQueryResult(
      text: _formatUsd(remaining),
      mode: BalanceQueryMode.billing,
      source: '/v1/dashboard/billing',
      detail:
          '总额度 ${_formatUsd(hardLimit)}，已用 ${_formatUsd(usedUsd)}',
      amount: remaining,
    );
  }

  // ----------------------------------------------------- 自定义接口

  Future<BalanceQueryResult> _queryCustom(
    ApiProfile profile,
    BalanceQueryConfig config,
    String apiKey,
    int timeoutSeconds,
  ) async {
    final rawUrl = config.customUrl.trim();
    if (rawUrl.isEmpty) {
      throw const BalanceQueryException('请填写自定义查询地址。');
    }
    final url = rawUrl.replaceAll('{base}', _baseUrl(profile));
    final token = config.accessToken.trim().isEmpty
        ? apiKey
        : config.accessToken.trim();
    final response = await _get(
      url: url,
      headers: _bearer(token),
      timeoutSeconds: timeoutSeconds,
      label: '自定义余额接口',
    );
    final body = response.data;
    if (body == null) {
      throw BalanceQueryException('自定义接口没有返回内容（HTTP ${response.status}）。');
    }
    final path = config.customPath.trim();
    final rawValue = path.isEmpty
        ? _findBalanceValue(body)
        : _dig(body, path);
    final value = _asDouble(rawValue);
    if (value == null) {
      throw BalanceQueryException(
        '在响应里找不到${path.isEmpty ? '金额' : '字段 $path'}，'
        '返回内容：${_summarize(body)}',
      );
    }
    final divisor = config.customDivisor <= 0 ? 1.0 : config.customDivisor;
    final amount = value / divisor;
    return BalanceQueryResult(
      text: '${config.customPrefix}${amount.toStringAsFixed(2)}',
      mode: BalanceQueryMode.custom,
      source: url,
      detail: '接口原值 $value'
          '${divisor == 1 ? '' : '，按 ÷${_trimNumber(divisor)} 换算'}',
      amount: amount,
    );
  }

  // ------------------------------------------------------------ 工具

  Future<_HttpResult> _get({
    required String url,
    required Map<String, String> headers,
    required int timeoutSeconds,
    required String label,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: timeoutSeconds),
        receiveTimeout: Duration(seconds: timeoutSeconds),
        sendTimeout: Duration(seconds: timeoutSeconds),
        responseType: ResponseType.json,
        // 4xx/5xx 也要拿到响应体，才能给出准确的提示。
        validateStatus: (_) => true,
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
          ...headers,
        },
      ),
    );
    final title = 'GET $url';
    final stopwatch = Stopwatch()..start();
    unawaited(
      requestLogService?.logRequest(
        title,
        '用途: $label\n'
        '请求地址: $url\n'
        '超时: $timeoutSeconds 秒',
      ),
    );
    try {
      final response = await dio.get<Object?>(url);
      stopwatch.stop();
      unawaited(
        requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarize(response.data)}',
        ),
      );
      return _HttpResult(status: response.statusCode ?? 0, data: response.data);
    } on DioException catch (error) {
      stopwatch.stop();
      final message = _describeDioError(error);
      unawaited(
        requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarize(error.response?.data)}',
        ),
      );
      throw BalanceQueryException(message);
    } finally {
      dio.close(force: true);
    }
  }

  /// 允许用户把 `/v1` 也写进 Base URL。
  String _baseUrl(ApiProfile profile) {
    var base = profile.normalizedBaseUrl;
    final lower = base.toLowerCase();
    if (lower.endsWith('/v1')) {
      base = base.substring(0, base.length - 3);
    } else if (lower.endsWith('/v1/')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }

  Map<String, String> _bearer(String token) {
    return {
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _describeDioError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '连接中转站超时。',
      DioExceptionType.connectionError => '连不上中转站，检查 Base URL 或网络。',
      DioExceptionType.badCertificate => '中转站证书校验失败。',
      DioExceptionType.cancel => '查询已取消。',
      _ => '请求失败（${error.type.name}）：${error.message ?? '未知错误'}',
    };
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  /// 按 `data.quota`、`data.0.balance` 这种路径取值。
  Object? _dig(Object? json, String path) {
    Object? current = json;
    for (final segment in path.split('.')) {
      final key = segment.trim();
      if (key.isEmpty) {
        continue;
      }
      if (current is Map) {
        current = current[key];
      } else if (current is List) {
        final index = int.tryParse(key);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  /// 没填字段路径时，从常见的余额字段里找一个数字。
  Object? _findBalanceValue(Object? json) {
    const candidates = [
      'balance',
      'remaining',
      'quota',
      'credits',
      'available',
      'total_available',
      'data.balance',
      'data.remaining',
      'data.quota',
      'data.total_available',
      'data.total_remaining',
      'data.credits',
      'result.balance',
    ];
    for (final candidate in candidates) {
      final value = _asDouble(_dig(json, candidate));
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  double? _sumTodayCost(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    double total = 0;
    var matched = false;
    for (final item in raw) {
      final map = _asMap(item);
      if (map == null) {
        continue;
      }
      final date = map['date'];
      if (date is! String || !date.startsWith(today)) {
        continue;
      }
      final cost =
          _asDouble(map['actual_cost']) ?? _asDouble(map['cost']);
      if (cost == null) {
        continue;
      }
      total += cost;
      matched = true;
    }
    return matched ? total : null;
  }

  String _formatUsd(double value) {
    final digits = value.abs().toStringAsFixed(2);
    return value < 0 ? '-\$$digits' : '\$$digits';
  }

  String _trimNumber(double value) {
    final fixed = value.toStringAsFixed(4);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// 日志和报错里只放摘要，避免把整段 HTML 塞进请求日志。
  String _summarize(Object? data) {
    if (data == null) {
      return '(空)';
    }
    final text = data is String ? data : data.toString();
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 400) {
      return singleLine;
    }
    return '${singleLine.substring(0, 400)}…（共 ${singleLine.length} 字符）';
  }
}

class _HttpResult {
  const _HttpResult({required this.status, required this.data});

  final int status;
  final Object? data;
}
