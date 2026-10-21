import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme.dart';

/// Shared presentation for image and prompt-optimization API configurations.
/// Model details expand in place so they never cover another configuration.
class ApiConfigurationRow extends StatefulWidget {
  const ApiConfigurationRow({
    super.key,
    required this.name,
    required this.protocol,
    required this.url,
    required this.models,
    required this.isActive,
    required this.onEnable,
    required this.onEdit,
    required this.onDelete,
    this.canDelete = true,
    this.currentModel,
    this.onTest,
    this.testing = false,
    this.latency,
    this.testFailed = false,
    this.balance,
    this.statusLabel,
  });

  final String name;
  final String protocol;
  final String url;
  final List<String> models;
  final bool isActive;
  final VoidCallback onEnable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canDelete;
  final String? currentModel;
  final VoidCallback? onTest;
  final bool testing;
  final String? latency;
  final bool testFailed;
  final String? balance;
  final String? statusLabel;

  @override
  State<ApiConfigurationRow> createState() => _ApiConfigurationRowState();
}

class _ApiConfigurationRowState extends State<ApiConfigurationRow> {
  bool _expanded = false;
  String get _model =>
      widget.currentModel ?? widget.models.firstOrNull ?? '未配置';

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth /
                  MediaQuery.textScalerOf(context).scale(1) >=
              680;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _identity(context)),
                    const SizedBox(width: AppSpace.md),
                    _actions(context),
                  ],
                )
              else
                _identity(context),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  Flexible(
                    child: Tooltip(
                      message: widget.url,
                      child: Text(
                        widget.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(b),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制 API 地址',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: AppIconSize.sm),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: widget.url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API 地址已复制')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft(b),
                  borderRadius: AppRadius.smAll,
                ),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: _models(context)),
                          if (widget.onTest != null ||
                              widget.balance != null) ...[
                            const SizedBox(width: AppSpace.lg),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * .38,
                              ),
                              child: _metrics(context),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _models(context),
                          if (widget.onTest != null ||
                              widget.balance != null) ...[
                            const SizedBox(height: AppSpace.xs),
                            _metrics(context),
                          ],
                        ],
                      ),
              ),
              if (!wide) ...[
                const SizedBox(height: AppSpace.sm),
                _actions(context),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final b = Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpace.xs,
        runSpacing: AppSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xs,
              vertical: AppSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primarySoft(b)
                  : AppColors.surfaceMuted(b),
              borderRadius: AppRadius.xsAll,
            ),
            child: Text(
              widget.statusLabel ?? (widget.isActive ? '当前使用' : '备用'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: widget.isActive
                    ? AppColors.primaryStrong(b)
                    : AppColors.textSecondary(b),
              ),
            ),
          ),
          Text(
            widget.protocol,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary(b)),
          ),
        ],
      ),
    );
  }

  Widget _models(BuildContext context) {
    final b = Theme.of(context).brightness;
    final visibleModels = _expanded ? widget.models : widget.models.take(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '模型 · ${widget.models.length} 个',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary(b)),
        ),
        const SizedBox(height: AppSpace.xs),
        if (widget.models.isEmpty)
          const Text('未配置')
        else
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              for (final model in visibleModels)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: AppSpace.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: model == _model
                        ? AppColors.primarySoft(b)
                        : AppColors.surface(b),
                    borderRadius: AppRadius.xsAll,
                    border: Border.all(
                      color: model == _model
                          ? AppColors.primary(b)
                          : AppColors.border(b),
                    ),
                  ),
                  child: Text(
                    model == _model ? '$model · 当前模型' : model,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: model == _model
                          ? AppColors.primaryStrong(b)
                          : AppColors.textPrimary(b),
                    ),
                  ),
                ),
            ],
          ),
        if (widget.models.length > 4)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: _expanded
                ? const Icon(Icons.expand_less_rounded, size: AppIconSize.sm)
                : const Icon(Icons.expand_more_rounded, size: AppIconSize.sm),
            label: Text(
              _expanded ? '收起更多模型' : '更多模型 (${widget.models.length - 4})',
            ),
          ),
      ],
    );
  }

  Widget _metrics(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.xxs,
      children: [
        if (widget.onTest != null)
          Tooltip(
            message: '通过 GET /v1/models 检查连接，超时 10 秒；不发起生图请求。',
            child: Text(
              widget.testing
                  ? '连接测试中…'
                  : widget.latency == null
                  ? '连接 · 未测试'
                  : widget.testFailed
                  ? widget.latency!
                  : '连接正常 · ${widget.latency}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: widget.testFailed
                    ? AppColors.dangerText(b)
                    : widget.latency != null
                    ? AppColors.successText(b)
                    : AppColors.textTertiary(b),
              ),
            ),
          ),
        if (widget.balance != null)
          Text(
            '账户余额 · ${widget.balance}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _actions(BuildContext context) => Wrap(
    spacing: AppSpace.xs,
    runSpacing: AppSpace.xs,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (!widget.isActive)
        FilledButton(onPressed: widget.onEnable, child: const Text('设为当前')),
      if (widget.onTest != null)
        OutlinedButton.icon(
          onPressed: widget.testing ? null : widget.onTest,
          icon: const Icon(Icons.bolt_rounded, size: AppIconSize.sm),
          label: Text(widget.testing ? '测试中' : '测试连接'),
        ),
      OutlinedButton(onPressed: widget.onEdit, child: const Text('编辑')),
      PopupMenuButton<String>(
        tooltip: '更多操作',
        icon: const Icon(Icons.more_horiz_rounded, size: AppIconSize.md),
        onSelected: (_) => widget.onDelete(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'delete',
            enabled: widget.canDelete,
            child: Text(
              widget.canDelete ? '删除配置' : '至少保留 1 个配置',
              style: TextStyle(
                color: widget.canDelete
                    ? AppColors.dangerText(Theme.of(context).brightness)
                    : null,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
