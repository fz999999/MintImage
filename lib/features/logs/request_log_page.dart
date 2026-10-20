import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/request_log_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/empty_state.dart';

class RequestLogPage extends ConsumerStatefulWidget {
  const RequestLogPage({super.key, this.pollFileChanges = false});

  final bool pollFileChanges;

  @override
  ConsumerState<RequestLogPage> createState() => _RequestLogPageState();
}

class _RequestLogPageState extends ConsumerState<RequestLogPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.pollFileChanges) {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(ref.read(requestLogServiceProvider).reload());
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final logService = ref.watch(requestLogServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('请求日志'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => logService.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.canvas(b), AppColors.canvasTint(b)],
          ),
        ),
        child: AnimatedBuilder(
          animation: logService,
          builder: (context, _) {
            final entries = logService.entries.reversed.toList(growable: false);
            if (entries.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm,
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.xl,
                ),
                children: const [
                  SizedBox(height: 48),
                  EmptyState(
                    title: '暂无请求日志',
                    description: '发起一次生成或改图请求后，这里会显示详细的请求与响应记录。',
                  ),
                ],
              );
            }

            return ListView.separated(
              // 底部留 24 的空白，避免最后一条贴住窗口下沿。
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.lg,
              ),
              itemCount: entries.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _LogOverviewCard(
                    count: entries.length,
                    filePath: logService.filePath,
                  );
                }

                final entry = entries[index - 1];
                return _LogEntryCard(entry: entry);
              },
            );
          },
        ),
      ),
    );
  }
}

/// 概览卡：只留「总条数 + 日志文件路径 + 复制路径」三样。
///
/// 原 Stitch 稿里的 GPU VRAM / 活动状态 / Port 7860 都是臆造数据，已删（决策 28）。
class _LogOverviewCard extends StatelessWidget {
  const _LogOverviewCard({required this.count, required this.filePath});

  final int count;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Container(
      decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '共 $count 条',
                  style: TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(b),
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制路径',
                onPressed: () => _copyPath(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppSpace.xl,
                  minHeight: AppSpace.xl,
                ),
                iconSize: AppIconSize.sm,
                color: AppColors.textSecondary(b),
                icon: const Icon(Icons.content_copy, size: AppIconSize.sm),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          SelectableText(
            filePath,
            style: TextStyle(
              fontSize: AppFontSize.micro,
              height: 1.4,
              color: AppColors.textSecondary(b),
            ),
          ),
        ],
      ),
    );
  }

  /// 复制日志文件路径，并给出一次性反馈。
  Future<void> _copyPath(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: filePath));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制日志路径')),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({required this.entry});

  final RequestLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Container(
      decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.textSecondary(b),
          collapsedIconColor: AppColors.textSecondary(b),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              _LogLevelChip(level: entry.level),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxs),
            child: Text(
              _formatTimestamp(entry.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(b),
              ),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                entry.details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: AppColors.textPrimary(b),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '${timestamp.year}-$month-$day $hour:$minute:$second';
  }
}

class _LogLevelChip extends StatelessWidget {
  const _LogLevelChip({required this.level});

  final RequestLogLevel level;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    late final Color backgroundColor;
    late final Color foregroundColor;
    late final String label;

    switch (level) {
      case RequestLogLevel.info:
        backgroundColor = AppColors.neutralSurface(b);
        foregroundColor = AppColors.neutralText(b);
        label = '信息';
      case RequestLogLevel.request:
        backgroundColor = AppColors.infoSurface(b);
        foregroundColor = AppColors.infoText(b);
        label = '请求';
      case RequestLogLevel.response:
        backgroundColor = AppColors.successSurface(b);
        foregroundColor = AppColors.successText(b);
        label = '响应';
      case RequestLogLevel.error:
        backgroundColor = AppColors.dangerSurface(b);
        foregroundColor = AppColors.dangerText(b);
        label = '错误';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.label,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}
