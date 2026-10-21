/// 中转站余额查询方式。
///
/// 每种方式对应中转站面板的一套公开接口，实测结果：
/// - [usage]：AIHub（`GET /v1/usage`）直接返回 `{"balance": 10.68}`；
/// - [account]：one-api / new-api 的 `GET /api/user/self`，需要「系统访问令牌」；
/// - [token]：one-api / new-api 的 `GET /api/usage/token`，读这个 Key 自己的额度；
/// - [billing]：OpenAI 兼容账单 `GET /v1/dashboard/billing/subscription` + `/usage`；
/// - [custom]：用户自己填地址和字段路径。
enum BalanceQueryMode {
  auto('auto'),
  account('account'),
  token('token'),
  billing('billing'),
  usage('usage'),
  custom('custom');

  const BalanceQueryMode(this.storageValue);

  final String storageValue;

  String get label {
    return switch (this) {
      BalanceQueryMode.auto => '自动识别',
      BalanceQueryMode.account => '账户余额（需访问令牌）',
      BalanceQueryMode.token => 'Key 的剩余额度',
      BalanceQueryMode.billing => 'OpenAI 兼容账单接口',
      BalanceQueryMode.usage => 'AIHub 用量接口',
      BalanceQueryMode.custom => '自定义接口',
    };
  }

  String get description {
    return switch (this) {
      BalanceQueryMode.auto =>
        '依次尝试 AIHub 用量接口、账户余额（填了访问令牌才试）、Key 的剩余额度、'
            'OpenAI 兼容账单，取第一个能读到数字的结果。',
      BalanceQueryMode.account =>
        '调用 /api/user/self 读账户额度，需要中转站面板「个人设置 → 系统访问令牌」里生成的令牌。',
      BalanceQueryMode.token =>
        '调用 /api/usage/token 读这个 Key 自己的剩余额度；Key 不限额度时会显示「不限」。',
      BalanceQueryMode.billing =>
        '调用 /v1/dashboard/billing/subscription 与 /usage，用总额度减掉已用量。',
      BalanceQueryMode.usage => '调用 /v1/usage 直接读余额，AIHub 这类网关支持。',
      BalanceQueryMode.custom =>
        '自己填查询地址和字段路径，适合上面几种预设都对不上的中转站。',
    };
  }

  static BalanceQueryMode fromStorageValue(Object? rawValue) {
    final value = rawValue is String ? rawValue : '';
    return BalanceQueryMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => BalanceQueryMode.auto,
    );
  }
}

/// 单个中转站配置里的「余额查询」设置。
class BalanceQueryConfig {
  const BalanceQueryConfig({
    this.enabled = true,
    this.mode = BalanceQueryMode.auto,
    this.accessToken = '',
    this.customUrl = '',
    this.customPath = '',
    this.customDivisor = 1,
    this.customPrefix = r'$',
  });

  factory BalanceQueryConfig.fromJson(Object? raw) {
    if (raw is! Map) {
      return const BalanceQueryConfig();
    }
    final json = Map<String, dynamic>.from(raw);
    final divisor = switch (json['customDivisor']) {
      num value => value.toDouble(),
      String value => double.tryParse(value.trim()),
      _ => null,
    };
    return BalanceQueryConfig(
      enabled: json['enabled'] as bool? ?? true,
      mode: BalanceQueryMode.fromStorageValue(json['mode']),
      accessToken: json['accessToken'] as String? ?? '',
      customUrl: json['customUrl'] as String? ?? '',
      customPath: json['customPath'] as String? ?? '',
      customDivisor: divisor == null || divisor <= 0 ? 1 : divisor,
      customPrefix: json['customPrefix'] as String? ?? r'$',
    );
  }

  /// 是否在主页右下角显示余额。
  final bool enabled;

  /// 查询方式；[BalanceQueryMode.auto] 会按顺序试几种预设。
  final BalanceQueryMode mode;

  /// 中转站面板生成的「系统访问令牌」，只有账户余额查询用得到。
  final String accessToken;

  /// 自定义查询地址，支持 `{base}` 占位符。
  final String customUrl;

  /// 自定义字段路径，如 `data.quota`；留空时自动找常见的余额字段。
  final String customPath;

  /// 数值换算：显示值 = 接口数值 / divisor。
  final double customDivisor;

  /// 自定义显示的货币符号。
  final String customPrefix;

  BalanceQueryConfig copyWith({
    bool? enabled,
    BalanceQueryMode? mode,
    String? accessToken,
    String? customUrl,
    String? customPath,
    double? customDivisor,
    String? customPrefix,
  }) {
    return BalanceQueryConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      accessToken: accessToken ?? this.accessToken,
      customUrl: customUrl ?? this.customUrl,
      customPath: customPath ?? this.customPath,
      customDivisor: customDivisor ?? this.customDivisor,
      customPrefix: customPrefix ?? this.customPrefix,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'mode': mode.storageValue,
      'accessToken': accessToken,
      'customUrl': customUrl,
      'customPath': customPath,
      'customDivisor': customDivisor,
      'customPrefix': customPrefix,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is BalanceQueryConfig &&
        other.enabled == enabled &&
        other.mode == mode &&
        other.accessToken == accessToken &&
        other.customUrl == customUrl &&
        other.customPath == customPath &&
        other.customDivisor == customDivisor &&
        other.customPrefix == customPrefix;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    mode,
    accessToken,
    customUrl,
    customPath,
    customDivisor,
    customPrefix,
  );
}
