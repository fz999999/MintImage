import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/balance_provider.dart';
import '../../core/providers/settings_provider.dart';
import 'balance_label.dart';

/// 主页右下角的渠道余额。
///
/// 跟着「当前选中的中转站」走：切到哪个配置就查哪个配置的余额，
/// 具体查哪个接口、要填什么，由该配置里的「余额查询」设置决定。
class ChannelBalanceLabel extends ConsumerStatefulWidget {
  const ChannelBalanceLabel({super.key});

  @override
  ConsumerState<ChannelBalanceLabel> createState() =>
      _ChannelBalanceLabelState();
}

class _ChannelBalanceLabelState extends ConsumerState<ChannelBalanceLabel> {
  /// 定时刷新间隔。
  static const Duration _refreshInterval = Duration(minutes: 3);

  /// 超过这个时间就算旧数据，界面重建时顺手刷一次。
  static const Duration _staleAfter = Duration(minutes: 1);

  Timer? _timer;

  /// 上一次触发查询时的「配置指纹」，变了就说明用户切了中转站或改了设置。
  String? _signature;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh(force: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh({bool force = false}) {
    if (!mounted) {
      return;
    }
    final profile = ref.read(settingsProvider).activeProfile;
    unawaited(ref.read(balanceProvider.notifier).refresh(profile, force: force));
  }

  /// build 里不能直接改状态，推到下一帧再查。
  void _scheduleRefresh({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _refresh(force: force);
    });
  }

  String _signatureOf(ApiProfile profile) {
    return jsonEncode({
      'id': profile.id,
      'baseUrl': profile.baseUrl,
      'apiKeyLength': profile.apiKey.length,
      'apiKeyTail': profile.apiKey.length > 4
          ? profile.apiKey.substring(profile.apiKey.length - 4)
          : '',
      'balance': profile.balanceQuery.toJson(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(settingsProvider).activeProfile;
    if (!profile.balanceQuery.enabled) {
      return const SizedBox.shrink();
    }

    final snapshot = ref.watch(balanceProvider);
    final signature = _signatureOf(profile);
    if (_signature != signature) {
      _signature = signature;
      _scheduleRefresh(force: true);
    } else {
      final result = snapshot.resultFor(profile.id);
      final failed = snapshot.errorFor(profile.id) != null;
      final stale =
          result == null ||
          DateTime.now().difference(result.fetchedAt) > _staleAfter;
      if (stale && !failed && !snapshot.isLoading(profile.id)) {
        _scheduleRefresh();
      }
    }

    final result = snapshot.resultFor(profile.id);
    final error = snapshot.errorFor(profile.id);
    return BalanceLabel(
      value: result?.text,
      loading: result == null && snapshot.isLoading(profile.id),
      failed: error != null && result == null,
      tooltip: error ?? result?.tooltip,
      onTap: () => _refresh(force: true),
    );
  }
}
