import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/balance_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';
import 'api_configuration_row.dart';

class ImageApiSection extends ConsumerStatefulWidget {
  const ImageApiSection({
    super.key,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onAdd;
  final ValueChanged<ApiProfile> onEdit;
  final ValueChanged<ApiProfile> onDelete;

  @override
  ConsumerState<ImageApiSection> createState() => _ImageApiSectionState();
}

class _ImageApiSectionState extends ConsumerState<ImageApiSection> {
  bool _onlyActive = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final b = Theme.of(context).brightness;
    final activeCount = settings.profiles
        .where((profile) => profile.id == settings.activeProfileId)
        .length;
    final profiles = settings.profiles
        .where(
          (profile) => !_onlyActive || profile.id == settings.activeProfileId,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft(b),
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: AppColors.border(b)),
                  ),
                  child: Icon(
                    Icons.auto_awesome_motion_rounded,
                    size: AppIconSize.sm,
                    color: AppColors.primaryStrong(b),
                  ),
                ),
                Text(
                  '生图 API',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${settings.profiles.length} 个配置',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final controls = Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted(b),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Wrap(
                    children: [
                      _filter('全部 (${settings.profiles.length})', false),
                      _filter('当前使用 ($activeCount)', true),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_rounded, size: AppIconSize.sm),
                  label: const Text('添加服务商'),
                ),
              ],
            );
            if (constraints.maxWidth <
                760 * MediaQuery.textScalerOf(context).scale(1)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: AppSpace.sm),
                  controls,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpace.md),
                controls,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Column(
          children: [
            if (profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: Text('暂无符合条件的服务商'),
              ),
            for (var index = 0; index < profiles.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpace.sm),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface(b),
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                    color: profiles[index].id == settings.activeProfileId
                        ? AppColors.primary(b)
                        : AppColors.border(b),
                  ),
                ),
                child: _ProviderRow(
                  key: ValueKey(profiles[index].id),
                  profile: profiles[index],
                  isActive: profiles[index].id == settings.activeProfileId,
                  canDelete: settings.profiles.length > 1,
                  onEnable: () => ref
                      .read(settingsProvider.notifier)
                      .setActiveProfile(profiles[index].id),
                  onEdit: () => widget.onEdit(profiles[index]),
                  onDelete: () => widget.onDelete(profiles[index]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _filter(String label, bool onlyActive) {
    final b = Theme.of(context).brightness;
    return TextButton(
      onPressed: () => setState(() => _onlyActive = onlyActive),
      style: TextButton.styleFrom(
        backgroundColor: _onlyActive == onlyActive
            ? AppColors.surface(b)
            : null,
        foregroundColor: _onlyActive == onlyActive
            ? AppColors.textPrimary(b)
            : AppColors.textSecondary(b),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      child: Text(label),
    );
  }
}

class _ProviderRow extends ConsumerStatefulWidget {
  const _ProviderRow({
    super.key,
    required this.profile,
    required this.isActive,
    required this.canDelete,
    required this.onEnable,
    required this.onEdit,
    required this.onDelete,
  });

  final ApiProfile profile;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onEnable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  ConsumerState<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends ConsumerState<_ProviderRow> {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.plain,
      followRedirects: false,
      validateStatus: (_) => true,
    ),
  );
  CancelToken? _request;
  bool _testing = false;
  String? _result;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBalance());
  }

  /// 没填 API Key、或用户关掉了余额查询，列表里就不显示这一项。
  bool get _canQueryBalance =>
      widget.profile.balanceQuery.enabled &&
      widget.profile.apiKey.trim().isNotEmpty;

  /// 列表里顺手把这个中转站的余额也查一次。
  void _refreshBalance({bool force = false}) {
    if (!mounted || !_canQueryBalance) {
      return;
    }
    unawaited(
      ref.read(balanceProvider.notifier).refresh(widget.profile, force: force),
    );
  }

  @override
  void didUpdateWidget(covariant _ProviderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.normalizedBaseUrl !=
            widget.profile.normalizedBaseUrl ||
        oldWidget.profile.apiKey != widget.profile.apiKey) {
      _request?.cancel();
      _request = null;
      _testing = false;
      _result = null;
      _failed = false;
    }
    if (oldWidget.profile.apiKey != widget.profile.apiKey ||
        oldWidget.profile.balanceQuery != widget.profile.balanceQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshBalance(force: true);
      });
    }
  }

  @override
  void dispose() {
    _request?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    final request = CancelToken();
    _request = request;
    setState(() {
      _testing = true;
      _result = null;
      _failed = false;
    });
    final stopwatch = Stopwatch()..start();
    String result;
    var failed = true;
    try {
      final response = await _dio
          .get<String>(
            '${widget.profile.normalizedBaseUrl}/v1/models',
            options: Options(
              headers: {'Authorization': 'Bearer ${widget.profile.apiKey}'},
            ),
            cancelToken: request,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              request.cancel('timeout');
              throw TimeoutException('timeout');
            },
          );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        result = '${stopwatch.elapsedMilliseconds} ms';
        failed = false;
      } else if (status == 401 || status == 403) {
        result = '认证失败 ($status)';
      } else {
        result = '测试失败 (HTTP $status)';
      }
    } on TimeoutException {
      result = '测试失败：超时 (10 秒)';
    } on DioException catch (error) {
      result = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => '测试失败：超时 (10 秒)',
        DioExceptionType.connectionError => '测试失败：无法连接',
        DioExceptionType.badCertificate => '测试失败：证书无效',
        _ => '测试失败：请求异常',
      };
    } catch (_) {
      result = '测试失败：地址或请求无效';
    }
    stopwatch.stop();
    if (!mounted || _request != request) return;
    setState(() {
      _testing = false;
      _result = result;
      _failed = failed;
      _request = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(balanceProvider);
    final result = snapshot.resultFor(widget.profile.id);
    final error = snapshot.errorFor(widget.profile.id);
    return ApiConfigurationRow(
      name: widget.profile.name,
      protocol: widget.profile.apiMode.shortLabel,
      url: widget.profile.normalizedBaseUrl,
      models: widget.profile.models,
      currentModel: widget.profile.model,
      isActive: widget.isActive,
      canDelete: widget.canDelete,
      onEnable: widget.onEnable,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
      onTest: _testConnection,
      testing: _testing,
      latency: _result,
      testFailed: _failed,
      balance: _canQueryBalance
          ? (result?.text ?? (error != null ? '获取失败' : null))
          : null,
    );
  }
}
