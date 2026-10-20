import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/generation_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/image_clipboard_service.dart';
import '../../shared/design/app_colors.dart';
import '../../shared/design/tokens.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/checkerboard_background.dart';
import 'image_preview_page.dart';

class ImageCell extends ConsumerStatefulWidget {
  const ImageCell({
    super.key,
    required this.record,
    required this.imageHeight,
    this.previewRecords = const [],
    this.previewInitialIndex,
    required this.onReusePrompt,
    required this.onReuseEdit,
    required this.onRegenerate,
    required this.onRetry,
    required this.onCancel,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onPreviewNavigation,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionToggle,
    required this.currentAttachmentCount,
    required this.onAppendCurrentImageToAttachments,
  });

  final ImageRecord record;
  final double imageHeight;
  final List<ImageRecord> previewRecords;
  final int? previewInitialIndex;
  final VoidCallback onReusePrompt;
  final VoidCallback onReuseEdit;
  final VoidCallback onRegenerate;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final Future<void> Function(Future<void> Function() navigate)
  onPreviewNavigation;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onSelectionToggle;
  final int currentAttachmentCount;
  final VoidCallback onAppendCurrentImageToAttachments;

  @override
  ConsumerState<ImageCell> createState() => _ImageCellState();
}

class _ImageCellState extends ConsumerState<ImageCell> {
  /// 悬停态：鼠标进入图卡时置 true，右上角操作条浮现、元信息淡出、
  /// 描边转主色并抬升。桌面端基础能力，现状全库缺失。
  bool _hovered = false;

  ImageRecord get record => widget.record;
  double get imageHeight => widget.imageHeight;
  List<ImageRecord> get previewRecords => widget.previewRecords;
  int? get previewInitialIndex => widget.previewInitialIndex;
  bool get selectionMode => widget.selectionMode;
  bool get selected => widget.selected;
  int get currentAttachmentCount => widget.currentAttachmentCount;
  VoidCallback get onReusePrompt => widget.onReusePrompt;
  VoidCallback get onReuseEdit => widget.onReuseEdit;
  VoidCallback get onRegenerate => widget.onRegenerate;
  VoidCallback get onRetry => widget.onRetry;
  VoidCallback get onCancel => widget.onCancel;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onToggleFavorite => widget.onToggleFavorite;
  Future<void> Function(Future<void> Function() navigate)
  get onPreviewNavigation => widget.onPreviewNavigation;
  VoidCallback get onSelectionToggle => widget.onSelectionToggle;
  VoidCallback get onAppendCurrentImageToAttachments =>
      widget.onAppendCurrentImageToAttachments;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requestStartedAt = ref.watch(
      generationProvider.select((state) => state.requestStartedAts[record.id]),
    );
    // 流式生成时服务器推来的过程图；没有就是 null（走原来的 loading 占位）。
    final partialImage = ref.watch(
      generationProvider.select((state) => state.partialImages[record.id]),
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
      color: AppThemeTokens.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: selectionMode ? onSelectionToggle : null,
        onSecondaryTap:
            selectionMode ? null : () => _showActions(context),
        onLongPress: selectionMode
            ? onSelectionToggle
            : () => _showActions(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  _hovered
                      ? AppColors.primary(Theme.of(context).brightness)
                      : AppThemeTokens.border.withValues(alpha: 0.7),
              width: _hovered ? 1 : 0.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: _hovered ? AppShadow.raised : AppShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: InkWell(
                  onTap: selectionMode
                      ? null
                      : _canPreview
                      ? () => _openPreview(context)
                      : null,
                  onLongPress: selectionMode
                      ? null
                      : () => _showActions(context),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'image-${record.id}',
                        child: _buildImage(partialImage),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: MouseRegion(
                          onEnter: (_) => _setHovered(true),
                          onExit: (_) => _setHovered(false),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedOpacity(
                                opacity: _hovered ? 0 : 1,
                                duration: AppMotion.fast,
                                child: _ActualImageSizeChip(
                                  record: record,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildStatusWidget(context),
                              AnimatedOpacity(
                                opacity: _hovered ? 1 : 0,
                                duration: AppMotion.fast,
                                child: IgnorePointer(
                                  ignoring: !_hovered,
                                  child: _QuickActions(
                                    onShowAll: () => _showActions(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 0 : 1,
                          duration: AppMotion.fast,
                          child: _MetaOverlay(
                          chips: [
                            _OverlayChip(
                              icon: Icons.aspect_ratio_rounded,
                              label: record.sizeLabel,
                            ),
                            _OverlayChip(
                              icon: Icons.auto_awesome_rounded,
                              label: record.qualityLabel,
                            ),
                            _OverlayChip(
                              icon: Icons.api_rounded,
                              label: _compactLabel(_apiProfileName(ref)),
                            ),
                            _DurationChip(
                              record: record,
                              requestStartedAt: requestStartedAt,
                              elapsedSeconds: _elapsedSeconds,
                            ),
                            if (record.usedSingleImageFallback)
                              const _OverlayChip(
                                icon: Icons.filter_1_rounded,
                                label: '单图',
                              ),
                          ],
                          ),
                        ),
                      ),
                      if (selectionMode)
                        Positioned.fill(
                          child: _SelectionOverlay(selected: selected),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppThemeTokens.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _formatTime(record.createdAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppThemeTokens.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                if (record.isFavorite) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: AppColors.favorite(Theme.of(context).brightness),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_showsInlineMenuButton) ...[
                            const SizedBox(width: 8),
                            _InlineMenuButton(
                              onPressed: () => _showActions(context),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  bool get _showsInlineMenuButton => Platform.isMacOS || Platform.isWindows;

  bool get _canPreview {
    return record.resultImagePath != null ||
        record.resultImageUrl != null ||
        record.sourceAttachmentPaths.isNotEmpty;
  }

  Widget _buildImage(Uint8List? partialImage) {
    if (record.status == ImageRecordStatus.loading ||
        record.status == ImageRecordStatus.pending) {
      return _LoadingThumb(preview: partialImage);
    }

    if (record.resultImagePath != null &&
        File(record.resultImagePath!).existsSync()) {
      return CheckerboardBackground(
        child: Image.file(
          File(record.resultImagePath!),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (record.sourceImagePath != null &&
        File(record.sourceImagePath!).existsSync()) {
      return Image.file(
        File(record.sourceImagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    if (record.resultImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: record.resultImageUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _LoadingThumb(),
        errorWidget: (context, url, error) =>
            const _FallbackThumb(icon: Icons.image_not_supported_rounded),
      );
    }

    return const _FallbackThumb(icon: Icons.broken_image_rounded);
  }

  Widget _buildStatusWidget(BuildContext context) {
    final chip = _StatusPill(status: record.status);
    if (record.status != ImageRecordStatus.error) {
      return chip;
    }

    return Tooltip(
      message: '查看失败原因',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () => _showErrorDetails(context),
        child: chip,
      ),
    );
  }

  Future<void> _openPreview(BuildContext context) async {
    final records = previewRecords.isEmpty ? [record] : previewRecords;
    final resolvedInitialIndex =
        previewInitialIndex ??
        records.indexWhere((item) => item.id == record.id);
    final navigator = Navigator.of(context);

    await onPreviewNavigation(
      () => navigator.push(
        MaterialPageRoute<void>(
          requestFocus: false,
          builder: (_) => ImagePreviewPage(
            record: record,
            records: records,
            initialIndex: resolvedInitialIndex < 0 ? 0 : resolvedInitialIndex,
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final canEdit = record.status == ImageRecordStatus.done;
    final pageContext = context;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('复用提示词'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReusePrompt();
                  },
                ),
                if (canEdit)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('再生成一张'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onRegenerate();
                    },
                  ),
                if (canEdit)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('以此改图'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onReuseEdit();
                    },
                  ),
                if (_canAppendCurrentImageToAttachments)
                  ListTile(
                    leading: const Icon(Icons.add_photo_alternate_rounded),
                    title: Text('将此图添加到附件${currentAttachmentCount + 1}'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onAppendCurrentImageToAttachments();
                    },
                  ),
                if (_showsCopyImageAction && _canCopyImage)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: const Text('复制图片到剪贴板'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _copyImageToClipboard(pageContext);
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.star_border_rounded,
                    color: record.isFavorite ? AppColors.favorite(Theme.of(context).brightness) : null,
                  ),
                  title: const Text('收藏到...'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onToggleFavorite();
                  },
                ),
                if (record.status == ImageRecordStatus.loading ||
                    record.status == ImageRecordStatus.pending)
                  ListTile(
                    leading: const Icon(Icons.close_rounded),
                    title: const Text('取消当前请求'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onCancel();
                    },
                  ),
                if (record.status == ImageRecordStatus.error ||
                    record.status == ImageRecordStatus.cancelled)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('重试本次请求'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onRetry();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded),
                  title: const Text('删除这条记录'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _showsCopyImageAction {
    return Platform.isMacOS || Platform.isWindows;
  }

  bool get _canCopyImage {
    return record.resultImagePath != null ||
        record.sourceImagePath != null ||
        record.resultB64 != null ||
        record.resultImageUrl != null;
  }

  bool get _canAppendCurrentImageToAttachments {
    final resultImagePath = record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return true;
    }

    final sourceImagePath = record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return true;
    }

    return record.sourceAttachmentPaths.any((path) => File(path).existsSync());
  }

  Future<void> _copyImageToClipboard(BuildContext context) async {
    try {
      await const ImageClipboardService().copyRecordImage(record);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制图片到剪贴板。')));
    } on ImageClipboardException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('复制图片失败：$error')));
    }
  }

  Future<void> _showErrorDetails(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final message = record.errorMessage?.trim();
    final displayMessage = message == null || message.isEmpty
        ? '没有记录到具体失败原因。'
        : message;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('失败原因'),
          content: SelectableText(displayMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }

  int _elapsedSeconds(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  String _apiProfileName(WidgetRef ref) {
    final profiles = ref.watch(settingsProvider).profiles;
    for (final p in profiles) {
      if (p.id == record.apiProfileId) return p.name;
    }
    return '未知';
  }

  String _compactLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 8) {
      return trimmed;
    }
    return '${trimmed.substring(0, 7)}…';
  }
}

class _InlineMenuButton extends StatelessWidget {
  const _InlineMenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 22,
      child: IconButton(
        tooltip: '更多操作',
        onPressed: onPressed,
        icon: const Icon(Icons.more_horiz_rounded, size: 17),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 22),
        visualDensity: VisualDensity.compact,
        splashRadius: 14,
        color: AppThemeTokens.textSecondary,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _MetaOverlay extends StatelessWidget {
  const _MetaOverlay({required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.58),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 14, 5, 5),
        child: Wrap(spacing: 4, runSpacing: 4, children: chips),
      ),
    );
  }
}

class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: selected
              ? AppThemeTokens.primary.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.06),
          border: Border.all(
            color: selected ? AppThemeTokens.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: _SelectionDot(selected: selected),
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppThemeTokens.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppThemeTokens.primary : AppThemeTokens.border,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.record,
    required this.requestStartedAt,
    required this.elapsedSeconds,
  });

  final ImageRecord record;
  final DateTime? requestStartedAt;
  final int Function(DateTime startedAt) elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final startedAt = requestStartedAt;
    if (record.status == ImageRecordStatus.loading && startedAt != null) {
      return StreamBuilder<int>(
        stream: Stream<int>.periodic(
          const Duration(seconds: 1),
          (tick) => tick,
        ),
        initialData: 0,
        builder: (context, snapshot) {
          return _OverlayChip(
            icon: Icons.timer_outlined,
            label: '${elapsedSeconds(startedAt)}s',
          );
        },
      );
    }

    final durationMs = record.durationMs;
    if (durationMs == null) {
      return const SizedBox.shrink();
    }

    return _OverlayChip(
      icon: Icons.timer_outlined,
      label: '${(durationMs / 1000).toStringAsFixed(1)}s',
    );
  }
}

class _ActualImageSizeChip extends StatelessWidget {
  const _ActualImageSizeChip({required this.record});

  final ImageRecord record;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveSizeLabel(),
      builder: (context, snapshot) {
        return _OverlayChip(
          icon: Icons.photo_size_select_actual_rounded,
          label: snapshot.data ?? '--',
        );
      },
    );
  }

  Future<String?> _resolveSizeLabel() async {
    if (record.status == ImageRecordStatus.loading ||
        record.status == ImageRecordStatus.pending) {
      return null;
    }

    final provider = _imageProvider();
    if (provider == null) {
      return null;
    }

    final info = await _resolveImageInfo(provider);
    final width = info.image.width;
    final height = info.image.height;
    info.dispose();
    return '$width×$height';
  }

  ImageProvider? _imageProvider() {
    final resultImagePath = record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return FileImage(File(resultImagePath));
    }

    final sourceImagePath = record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return FileImage(File(sourceImagePath));
    }

    final resultImageUrl = record.resultImageUrl;
    if (resultImageUrl != null && resultImageUrl.isNotEmpty) {
      return CachedNetworkImageProvider(resultImageUrl);
    }

    return null;
  }

  Future<ImageInfo> _resolveImageInfo(ImageProvider provider) {
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(image);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppThemeTokens.primaryStrong),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppThemeTokens.primaryStrong,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ImageRecordStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color backgroundColor;
    late final Color foregroundColor;

    switch (status) {
      case ImageRecordStatus.pending:
      case ImageRecordStatus.loading:
        backgroundColor = Colors.white.withValues(alpha: 0.92);
        foregroundColor = AppThemeTokens.primaryStrong;
      case ImageRecordStatus.done:
        backgroundColor = const Color(0xFFE4F6EE).withValues(alpha: 0.94);
        foregroundColor = const Color(0xFF177245);
      case ImageRecordStatus.error:
        backgroundColor = AppThemeTokens.dangerSurface.withValues(alpha: 0.96);
        foregroundColor = AppThemeTokens.dangerText;
      case ImageRecordStatus.cancelled:
        backgroundColor = const Color(0xFFFFF0D8).withValues(alpha: 0.96);
        foregroundColor = const Color(0xFF935E00);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foregroundColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _LoadingThumb extends StatelessWidget {
  const _LoadingThumb({this.preview});

  /// 流式生成时服务器推来的过程图（模糊/未完成）。有就先显示它，
  /// 让用户知道「已经在画了」，而不是盯着一个转圈等一分钟。
  final Uint8List? preview;

  @override
  Widget build(BuildContext context) {
    final previewBytes = preview;
    if (previewBytes != null && previewBytes.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            previewBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppThemeTokens.surface.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '正在生成',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppThemeTokens.surfaceSoft, AppThemeTokens.primarySoft],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppThemeTokens.surfaceSoft,
      child: Center(child: Icon(icon, color: AppThemeTokens.primary)),
    );
  }
}


/// 图卡右上角悬停浮现的快捷操作条。
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xxs / 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: AppShadow.raised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuickActionButton(
            icon: Icons.copy_rounded,
            tooltip: '复制图片',
            onPressed: onShowAll,
          ),
          _QuickActionButton(
            icon: Icons.open_in_full_rounded,
            tooltip: '放大查看',
            onPressed: onShowAll,
          ),
          _QuickActionButton(
            icon: Icons.more_horiz_rounded,
            tooltip: '更多操作（右键也可）',
            onPressed: onShowAll,
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxs),
            child: Icon(icon, size: AppIconSize.sm),
          ),
        ),
      ),
    );
  }
}
