import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';

import '../api/balance_query_api.dart';
import '../models/settings_model.dart';
import '../services/request_log_service.dart';
import 'app_providers.dart';
import 'settings_provider.dart';

final balanceQueryApiProvider = Provider<BalanceQueryApi>((ref) {
  // 请求日志服务在测试环境里没有覆盖（app_providers 里默认抛 UnimplementedError），
  // 余额查询不依赖它能否记录，取不到就降级成不记日志继续跑。
  RequestLogService? requestLogService;
  try {
    requestLogService = ref.watch(requestLogServiceProvider);
  } on ProviderException {
    requestLogService = null;
  }
  return BalanceQueryApi(requestLogService: requestLogService);
});

/// 各中转站的余额缓存，按 profile id 存。
class BalanceState {
  const BalanceState({
    this.results = const <String, BalanceQueryResult>{},
    this.errors = const <String, String>{},
    this.loading = const <String>{},
  });

  final Map<String, BalanceQueryResult> results;
  final Map<String, String> errors;
  final Set<String> loading;

  BalanceQueryResult? resultFor(String profileId) => results[profileId];

  String? errorFor(String profileId) => errors[profileId];

  bool isLoading(String profileId) => loading.contains(profileId);

  BalanceState copyWith({
    Map<String, BalanceQueryResult>? results,
    Map<String, String>? errors,
    Set<String>? loading,
  }) {
    return BalanceState(
      results: results ?? this.results,
      errors: errors ?? this.errors,
      loading: loading ?? this.loading,
    );
  }
}

final balanceProvider = StateNotifierProvider<BalanceController, BalanceState>(
  (ref) => BalanceController(ref),
);

class BalanceController extends StateNotifier<BalanceState> {
  BalanceController(this._ref) : super(const BalanceState());

  final Ref _ref;

  /// 查询一次余额并缓存。[force] 只影响「正在查询时直接跳过」这一层，
  /// 真正的节流交给调用方（主页标签有自己的刷新节奏）。
  Future<BalanceQueryResult?> refresh(
    ApiProfile profile, {
    bool force = false,
  }) async {
    final config = profile.balanceQuery;
    if (!config.enabled) {
      clear(profile.id);
      return null;
    }
    if (state.loading.contains(profile.id) && !force) {
      return state.results[profile.id];
    }
    if (profile.apiKey.trim().isEmpty && config.accessToken.trim().isEmpty) {
      state = state.copyWith(
        errors: {...state.errors, profile.id: '这个配置还没有填 API Key'},
      );
      return null;
    }

    state = state.copyWith(errors: _without(state.errors, profile.id));
    state = state.copyWith(loading: {...state.loading, profile.id});
    final api = _ref.read(balanceQueryApiProvider);
    try {
      final result = await api.query(profile: profile, config: config);
      if (!mounted) {
        return result;
      }
      state = state.copyWith(
        results: {...state.results, profile.id: result},
        errors: _without(state.errors, profile.id),
        loading: _withoutAll(state.loading, profile.id),
      );
      return result;
    } on BalanceQueryException catch (error) {
      if (!mounted) {
        return null;
      }
      state = state.copyWith(
        errors: {...state.errors, profile.id: error.message},
        loading: _withoutAll(state.loading, profile.id),
      );
      return null;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      state = state.copyWith(
        errors: {...state.errors, profile.id: '余额查询失败：$error'},
        loading: _withoutAll(state.loading, profile.id),
      );
      return null;
    }
  }

  /// 当前选中的中转站，切换配置后主页标签就靠它跟着换。
  Future<BalanceQueryResult?> refreshActive() {
    final profile = _ref.read(settingsProvider).activeProfile;
    return refresh(profile);
  }

  Future<void> refreshAll() async {
    for (final profile in _ref.read(settingsProvider).profiles) {
      await refresh(profile);
    }
  }

  void clear(String profileId) {
    state = state.copyWith(
      results: _without(state.results, profileId),
      errors: _without(state.errors, profileId),
      loading: _withoutAll(state.loading, profileId),
    );
  }

  Map<String, T> _without<T>(Map<String, T> source, String key) {
    if (!source.containsKey(key)) {
      return source;
    }
    return {
      for (final entry in source.entries)
        if (entry.key != key) entry.key: entry.value,
    };
  }

  Set<String> _withoutAll(Set<String> source, String value) {
    if (!source.contains(value)) {
      return source;
    }
    return {
      for (final item in source)
        if (item != value) item,
    };
  }
}
