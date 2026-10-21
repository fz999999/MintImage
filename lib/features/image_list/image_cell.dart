import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/generation_provider.dart';
import '../../core/services/image_clipboard_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/checkerboard_background.dart';
import '../../shared/widgets/desktop/desktop_dialog.dart';
import '../../shared/widgets/desktop/desktop_menu.dart';
import '../favorites/favorite_folder_sheet.dart';
import 'image_preview_page.dart';

/// 图墙里的一张图片卡。
///
/// P2 升级要点：
/// - 改成有状态组件，自己记 hover：卡片上移 1px、图片放大 1.05、压暗蒙层、
///   描边转主色、阴影抬升，统一 `AppMotion.normal`（180ms）。
/// - 图上只留左上「像素角标」和右上「状态徽章」；比例/质量/格式等元信息
///   下沉到 76px 高的文字区，渠道名不再显示。
/// - 三个动作（预览 / 保存到本地 / 复制）不再压在图片中央，改到文字区
///   右下角常驻占位、hover 停留后才淡入，避免指针一扫过就出现按钮导致误触。
class ImageCell extends ConsumerStatefulWidget {
  /// 文字区固定高度。
  ///
  /// 瀑布流给子项的纵向约束是**无界的**，这里不能用 `Expanded` 去撑——
  /// 只能在内部就把高度定量好，图墙排版表也按这个值算卡片高度。
  static const double footerHeight = 88;

  const ImageCell({
    super.key,
    required this.record,
    required this.imageHeight,
    this.imageFit = BoxFit.cover,
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

  /// 图片在图区里怎么摆。
  ///
  /// 瀑布流按真实宽高比给卡片定了高，比例对得上时 `cover` 不裁任何像素；
  /// 只有被最小/最大高度夹住的极端比例才传 `contain`，宁可留边也不裁。
  final BoxFit imageFit;
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
  /// 指针停留多久才让文字区的动作钮淡入。
  ///
  /// 指针只是从图墙上扫过时不会闪出一排按钮，必须先停在这张卡上。
  static const Duration _actionsRevealDelay = Duration(milliseconds: 240);

  /// 文字区动作钮的命中尺寸（图标 16，留 24 的点击热区）。
  static const double _footerActionHitSize = 24;

  bool _hovered = false;
  bool _actionsRevealed = false;
  bool _menuOpen = false;
  Timer? _actionsRevealTimer;
  final GlobalKey _menuButtonKey = GlobalKey();
  final GlobalKey _cardContentKey = GlobalKey();
  final FocusNode _cardFocusNode = FocusNode(debugLabel: 'image card');

  @override
  void dispose() {
    _actionsRevealTimer?.cancel();
    _cardFocusNode.dispose();
    super.dispose();
  }

  Rect? _anchorRect([BuildContext? anchorContext]) {
    final box = (anchorContext ?? _menuButtonKey.currentContext ?? context)
        .findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size : null;
  }

  ImageRecord get _record => widget.record;

  /// 进卡立刻给抬升反馈，但动作钮要等指针停留一会儿才出现。
  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    _actionsRevealTimer?.cancel();
    if (!value) {
      setState(() {
        _hovered = false;
        _actionsRevealed = false;
      });
      return;
    }
    setState(() => _hovered = true);
    _actionsRevealTimer = Timer(_actionsRevealDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _actionsRevealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    // 流式生成时服务器推来的过程图；没有就是 null（走原来的 loading 占位）。
    final partialImage = ref.watch(
      generationProvider.select(
        (state) => state.partialImages[widget.record.id],
      ),
    );
    // 多选时不做 hover 抬升，避免和拖拽选框抢交互。
    final hoverActive = _hovered && !widget.selectionMode;

    return Focus(
      focusNode: _cardFocusNode,
      // 键盘 Tab 到卡片上也把动作钮亮出来，不留死角。
      onFocusChange: (focused) {
        if (focused) {
          if (!_actionsRevealed) {
            setState(() => _actionsRevealed = true);
          }
          return;
        }
        if (!_hovered && _actionsRevealed) {
          setState(() => _actionsRevealed = false);
        }
      },
      onKeyEvent: (_, event) {
        if ((defaultTargetPlatform == TargetPlatform.windows) && !widget.selectionMode &&
            event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed) {
          _showActions(context, anchorRect: _anchorRect());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
      key: _cardContentKey,
      cursor: widget.selectionMode
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        transform: Matrix4.translationValues(0, hoverActive ? -1 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface(b),
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: hoverActive ? AppColors.primary(b) : AppColors.border(b),
          ),
          boxShadow: hoverActive ? AppShadow.raised(b) : AppShadow.card(b),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.smAll,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.selectionMode ? widget.onSelectionToggle : null,
              onSecondaryTapDown: !(defaultTargetPlatform == TargetPlatform.windows) || widget.selectionMode
                  ? null : (details) => _showActions(context,
                      anchorRect: Rect.fromLTWH(details.globalPosition.dx,
                        details.globalPosition.dy, 1, 1)), 
              onLongPress: widget.selectionMode
                  ? widget.onSelectionToggle
                  : () => _showActions(context),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: widget.imageHeight,
                        width: double.infinity,
                        child: _buildImageArea(context, b, partialImage),
                      ),
                      SizedBox(
                        height: ImageCell.footerHeight,
                        child: _buildFooter(context, b),
                      ),
                    ],
                  ),
                  // 描边画在内容之上，否则会被图片盖掉。
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.smAll,
                          border: Border.all(
                            color: hoverActive
                                ? AppColors.primary(b)
                                : AppColors.border(b),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// 图片区：预览点击、hover 缩放、图上角标、状态徽章。
  Widget _buildImageArea(
    BuildContext context,
    Brightness b,
    Uint8List? partialImage,
  ) {
    final hoverActive = _hovered && !widget.selectionMode;
    final requestStartedAt = ref.watch(
      generationProvider.select(
        (state) => state.requestStartedAts[widget.record.id],
      ),
    );

    return ClipRect(
      child: InkWell(
        onTap: widget.selectionMode
            ? widget.onSelectionToggle
            : !_canPreview ? null : () => _openPreview(context),
        onLongPress: widget.selectionMode ? null : () => _showActions(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: hoverActive ? 1.05 : 1,
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: Hero(
                tag: 'image-${widget.record.id}',
                child: _buildImage(partialImage),
              ),
            ),
            // 图片区不再叠 hover 蒙层：动作钮已搬到文字区，压暗只会让画面发灰。
            Positioned(
              top: AppSpace.xs,
              left: AppSpace.xs,
              child: Wrap(
                spacing: AppSpace.xxs,
                runSpacing: AppSpace.xxs,
                children: [
                  _ActualImageSizeChip(record: widget.record),
                  _DurationChip(
                    record: widget.record,
                    requestStartedAt: requestStartedAt,
                    elapsedSeconds: _elapsedSeconds,
                  ),
                ],
              ),
            ),
            Positioned(
              top: AppSpace.xs,
              right: AppSpace.xs,
              child: _buildStatusWidget(context),
            ),
            if (widget.selectionMode)
              Positioned.fill(
                child: _SelectionOverlay(selected: widget.selected),
              ),
          ],
        ),
      ),
    );
  }

  /// 文字区（图墙给 88px）：prompt 两行 + 元信息一行 + 时间/星标/⋯ 一行。
  Widget _buildFooter(BuildContext context, Brightness b) {
    final theme = Theme.of(context);
    final record = widget.record;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            record.prompt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: AppFontSize.bodySm,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: AppColors.textPrimary(b),
            ),
          ),
          Text(
            _metaLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppFontSize.micro,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: 0,
              color: AppColors.textSecondary(b),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _timeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: AppFontSize.caption,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1,
                          color: AppColors.textSecondary(b),
                        ),
                      ),
                    ),
                    if (record.isFavorite) ...[
                      const SizedBox(width: AppSpace.xxs),
                      Icon(
                        Icons.star_rounded,
                        size: AppIconSize.sm,
                        color: AppColors.favorite(b),
                      ),
                    ],
                  ],
                ),
              ),
              // 移动端没有 hover，这组按钮永远不亮，等于不存在（走长按菜单）。
              if (!widget.selectionMode) ...[
                _buildFooterActions(context, b),
                const SizedBox(width: AppSpace.xxs),
              ],
              if (_showsInlineMenuButton && !widget.selectionMode)
                KeyedSubtree(
                  key: _menuButtonKey,
                  child: _InlineMenuButton(onPressed: () =>
                    _showActions(context, anchorRect: _anchorRect())),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _showsInlineMenuButton => Platform.isMacOS || (defaultTargetPlatform == TargetPlatform.windows);

  /// 文字区右下角的三个动作：预览 / 保存到本地 / 复制。
  ///
  /// 位置从「图片中央」挪到这里，并且要指针停留 [_actionsRevealDelay] 之后
  /// 才淡入，避免鼠标扫过图墙时误触。始终占位，出现时不推动其它元素。
  Widget _buildFooterActions(BuildContext context, Brightness b) {
    final revealed = _actionsRevealed && !widget.selectionMode;
    final canPreview = _canPreview;
    final canSave = _canSaveImage;
    final canCopy = _showsCopyImageAction && _canCopyImage;

    return ExcludeFocus(
      excluding: !revealed,
      child: IgnorePointer(
      ignoring: !revealed,
      child: AnimatedOpacity(
        opacity: revealed ? 1 : 0,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FooterActionButton(
              tooltip: '预览',
              enabled: canPreview,
              onPressed: () => _openPreview(context),
              child: Icon(
                Icons.visibility_rounded,
                size: AppIconSize.sm,
                color: canPreview
                    ? AppColors.textSecondary(b)
                    : AppColors.textTertiary(b),
              ),
            ),
            _FooterActionButton(
              tooltip: '保存到本地',
              enabled: canSave,
              onPressed: () => _saveImage(context),
              child: Icon(
                Icons.download_rounded,
                size: AppIconSize.sm,
                color: canSave
                    ? AppColors.textSecondary(b)
                    : AppColors.textTertiary(b),
              ),
            ),
            _FooterActionButton(
              tooltip: '复制',
              enabled: canCopy,
              onPressed: () => _copyImageToClipboard(context),
              child: Icon(
                Icons.copy_all_rounded,
                size: AppIconSize.sm,
                color: canCopy
                    ? AppColors.textSecondary(b)
                    : AppColors.textTertiary(b),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  bool get _canPreview {
    return _record.resultImagePath != null ||
        _record.resultImageUrl != null ||
        _record.sourceAttachmentPaths.isNotEmpty;
  }

  /// 有本地文件或远程地址才谈得上「保存到本地」。
  bool get _canSaveImage {
    return _record.resultImagePath != null || _record.resultImageUrl != null;
  }

  /// 元信息一行：`16:9 • 高 • WEBP`，单图回退时追加 `• 单图`。
  String get _metaLabel {
    final parts = <String>[
      _ratioLabel,
      _record.qualityLabel,
      _record.outputFormatLabel,
    ];
    if (_record.usedSingleImageFallback) {
      parts.add('单图');
    }
    return parts.join(' • ');
  }

  /// 按 `record.width/height` 约分；算不出比例就写「自动」。
  String get _ratioLabel {
    final width = _record.width;
    final height = _record.height;
    if (width <= 0 || height <= 0) {
      return '自动';
    }

    final divisor = _greatestCommonDivisor(width, height);
    final reducedWidth = width ~/ divisor;
    final reducedHeight = height ~/ divisor;
    if (reducedWidth <= 32 && reducedHeight <= 32) {
      return '$reducedWidth:$reducedHeight';
    }

    final ratio = width / height;
    return ratio >= 1
        ? '${ratio.toStringAsFixed(2)}:1'
        : '1:${(1 / ratio).toStringAsFixed(2)}';
  }

  int _greatestCommonDivisor(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final remainder = x % y;
      x = y;
      y = remainder;
    }
    return x == 0 ? 1 : x;
  }

  Widget _buildImage(Uint8List? partialImage) {
    if (_record.status == ImageRecordStatus.loading ||
        _record.status == ImageRecordStatus.pending) {
      return _LoadingThumb(preview: partialImage);
    }

    if (_record.resultImagePath != null &&
        File(_record.resultImagePath!).existsSync()) {
      return CheckerboardBackground(
        child: Image.file(
          File(_record.resultImagePath!),
          width: double.infinity,
          height: double.infinity,
          fit: widget.imageFit,
        ),
      );
    }

    if (_record.sourceImagePath != null &&
        File(_record.sourceImagePath!).existsSync()) {
      return Image.file(
        File(_record.sourceImagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: widget.imageFit,
      );
    }

    if (_record.resultImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: _record.resultImageUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: widget.imageFit,
        placeholder: (context, url) => const _LoadingThumb(),
        errorWidget: (context, url, error) => const _FallbackThumb(),
      );
    }

    return const _FallbackThumb(broken: true);
  }

  Widget _buildStatusWidget(BuildContext context) {
    final chip = _StatusPill(status: _record.status);
    if (_record.status != ImageRecordStatus.error) {
      return chip;
    }

    return Tooltip(
      message: '查看失败原因',
      child: InkWell(
        borderRadius: AppRadius.fullAll,
        onTap: widget.selectionMode ? widget.onSelectionToggle
            : () => _showErrorDetails(context),
        child: chip,
      ),
    );
  }

  Future<void> _openPreview(BuildContext context) async {
    final records = widget.previewRecords.isEmpty
        ? [_record]
        : widget.previewRecords;
    final resolvedInitialIndex =
        widget.previewInitialIndex ??
        records.indexWhere((item) => item.id == _record.id);
    final navigator = Navigator.of(context);

    await widget.onPreviewNavigation(
      () => navigator.push(
        MaterialPageRoute<void>(
          requestFocus: false,
          builder: (_) => ImagePreviewPage(
            record: _record,
            records: records,
            initialIndex: resolvedInitialIndex < 0 ? 0 : resolvedInitialIndex,
          ),
        ),
      ),
    );
  }

  /// 保存到本地：复用 `image_preview_page.dart` 的保存实现。
  Future<void> _saveImage(BuildContext context) async {
    try {
      final savedPath = await ref
          .read(imageSaveServiceProvider)
          .saveImage(
            suggestedFileName: 'mint-image-${_record.id}.$_fileExtension',
            localPath: _record.resultImagePath,
            imageUrl: _record.resultImageUrl,
          );

      if (!context.mounted) {
        return;
      }

      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消保存。')));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片已保存到：$savedPath')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  /// 保存时用的扩展名：本地文件优先，其次记录里配置的输出格式。
  String get _fileExtension {
    final localPath = _record.resultImagePath;
    if (localPath != null) {
      final extension = localPath.split('.').last;
      if (extension.isNotEmpty && extension != localPath) {
        return extension;
      }
    }
    return _record.outputFormat;
  }

  Future<void> _showActions(BuildContext context, {Rect? anchorRect}) async {
    if (widget.selectionMode || _menuOpen) return;
    if ((defaultTargetPlatform == TargetPlatform.windows)) {
      _cardFocusNode.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      _menuOpen = true;
      try {
        await _showDesktopActions(anchorRect ?? _anchorRect());
      } finally {
        _menuOpen = false;
      }
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final canEdit = _record.status == ImageRecordStatus.done;
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
                    widget.onReusePrompt();
                  },
                ),
                if (canEdit)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('再生成一张'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onRegenerate();
                    },
                  ),
                if (canEdit)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('以此改图'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onReuseEdit();
                    },
                  ),
                if (_canAppendCurrentImageToAttachments)
                  ListTile(
                    leading: const Icon(Icons.add_photo_alternate_rounded),
                    title: Text('将此图添加到附件${widget.currentAttachmentCount + 1}'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onAppendCurrentImageToAttachments();
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
                    color: _record.isFavorite
                        ? AppColors.favorite(Theme.of(sheetContext).brightness)
                        : null,
                  ),
                  title: const Text('收藏到...'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    widget.onToggleFavorite();
                  },
                ),
                if (_record.status == ImageRecordStatus.loading ||
                    _record.status == ImageRecordStatus.pending)
                  ListTile(
                    leading: const Icon(Icons.close_rounded),
                    title: const Text('取消当前请求'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onCancel();
                    },
                  ),
                if (_record.status == ImageRecordStatus.error ||
                    _record.status == ImageRecordStatus.cancelled)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('重试本次请求'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onRetry();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded),
                  title: const Text('删除这条记录'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    widget.onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDesktopActions(Rect? anchor) async {
    final canEdit = _record.status == ImageRecordStatus.done;
    final action = await showDesktopMenu<String>(
      context: _cardContentKey.currentContext ?? context,
      anchorRect: anchor,
      searchable: true,
      items: [
        const DesktopMenuItem(value: 'reuse', label: '复用提示词',
          leading: Icon(Icons.refresh_rounded)),
        if (canEdit) ...[
          const DesktopMenuItem(value: 'regenerate', label: '再生成一张',
            leading: Icon(Icons.refresh_rounded)),
          const DesktopMenuItem(value: 'edit', label: '以此改图',
            leading: Icon(Icons.edit_rounded)),
        ],
        if (_canAppendCurrentImageToAttachments)
          DesktopMenuItem(value: 'attach',
            label: '将此图添加到附件${widget.currentAttachmentCount + 1}',
            leading: const Icon(Icons.add_photo_alternate_rounded)),
        if (_showsCopyImageAction && _canCopyImage)
          const DesktopMenuItem(value: 'copy', label: '复制图片到剪贴板',
            leading: Icon(Icons.copy_rounded)),
        const DesktopMenuItem(value: 'favorite', label: '收藏到...',
          leading: Icon(Icons.star_border_rounded)),
        if (_record.isInProgress)
          const DesktopMenuItem(value: 'cancel', label: '取消当前请求',
            leading: Icon(Icons.close_rounded)),
        if (_record.status == ImageRecordStatus.error ||
            _record.status == ImageRecordStatus.cancelled)
          const DesktopMenuItem(value: 'retry', label: '重试本次请求',
            leading: Icon(Icons.refresh_rounded)),
        const DesktopMenuItem(value: 'delete', label: '删除这条记录',
          destructive: true, leading: Icon(Icons.delete_rounded)),
      ],
    );
    if (!mounted || widget.selectionMode || action == null) return;
    switch (action) {
      case 'reuse': widget.onReusePrompt();
      case 'regenerate': widget.onRegenerate();
      case 'edit': widget.onReuseEdit();
      case 'attach': widget.onAppendCurrentImageToAttachments();
      case 'copy': await _copyImageToClipboard(context);
      case 'favorite':
        await showFavoriteFolderRecordSheet(context,
          record: _record, anchorRect: anchor);
      case 'cancel': widget.onCancel();
      case 'retry': widget.onRetry();
      case 'delete': widget.onDelete();
    }
  }

  bool get _showsCopyImageAction {
    return Platform.isMacOS || (defaultTargetPlatform == TargetPlatform.windows);
  }

  bool get _canCopyImage {
    return _record.resultImagePath != null ||
        _record.sourceImagePath != null ||
        _record.resultB64 != null ||
        _record.resultImageUrl != null;
  }

  bool get _canAppendCurrentImageToAttachments {
    final resultImagePath = _record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return true;
    }

    final sourceImagePath = _record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return true;
    }

    return _record.sourceAttachmentPaths.any((path) => File(path).existsSync());
  }

  Future<void> _copyImageToClipboard(BuildContext context) async {
    try {
      await const ImageClipboardService().copyRecordImage(_record);
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
    final message = _record.errorMessage;
    final displayMessage = message == null || message.trim().isEmpty
        ? '没有记录到具体失败原因。'
        : message;

    if ((defaultTargetPlatform == TargetPlatform.windows)) {
      await showDesktopInfo(context: context, title: '失败原因', text: displayMessage);
      return;
    }
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

  /// 相对时间优先（10分钟前），超过一周或算不出就退到 `HH:mm`。
  String get _timeLabel {
    final now = DateTime.now();
    final difference = now.difference(_record.createdAt);
    if (difference.isNegative) {
      return _clockLabel(_record.createdAt);
    }
    if (difference.inSeconds < 60) {
      return '刚刚';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    }
    return _clockLabel(_record.createdAt);
  }

  String _clockLabel(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _elapsedSeconds(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }
}

/// 文字区右下角的小动作钮：24×24 热区、无实底，只在 hover 时整体淡入。
class _FooterActionButton extends StatefulWidget {
  const _FooterActionButton({
    required this.tooltip,
    required this.child,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final Widget child;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_FooterActionButton> createState() => _FooterActionButtonState();
}

class _FooterActionButtonState extends State<_FooterActionButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Material(
          color: _hovered && widget.enabled
              ? AppColors.surfaceMuted(b)
              : Colors.transparent,
          borderRadius: AppRadius.smAll,
          child: InkWell(
            borderRadius: AppRadius.smAll,
            onTap: widget.enabled ? widget.onPressed : null,
            child: SizedBox(
              width: _ImageCellState._footerActionHitSize,
              height: _ImageCellState._footerActionHitSize,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMenuButton extends StatelessWidget {
  const _InlineMenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SizedBox(
      width: AppSpace.lg,
      height: AppIconSize.md,
      child: IconButton(
        tooltip: '更多操作',
        onPressed: onPressed,
        icon: const Icon(Icons.more_horiz_rounded, size: AppIconSize.sm),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: AppSpace.lg,
          height: AppIconSize.md,
        ),
        visualDensity: VisualDensity.compact,
        splashRadius: 14,
        color: AppColors.textSecondary(b),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return IgnorePointer(
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer(b).withValues(alpha: 0.18)
              : AppColors.scrim(b).withValues(alpha: 0.06),
          border: Border.all(
            color: selected ? AppColors.primary(b) : Colors.transparent,
            width: 3,
          ),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xs),
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
    final b = Theme.of(context).brightness;
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: AppSpace.lg,
      height: AppSpace.lg,
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryContainer(b) : AppColors.surface(b),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary(b) : AppColors.border(b),
          width: 2,
        ),
        boxShadow: AppShadow.card(b),
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: AppIconSize.sm,
              color: AppColors.onPrimaryContainer(b),
            )
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
          return _ImageChip(label: '${elapsedSeconds(startedAt)}s');
        },
      );
    }

    final durationMs = record.durationMs;
    if (durationMs == null) {
      return const SizedBox.shrink();
    }

    return _ImageChip(label: '${(durationMs / 1000).toStringAsFixed(1)}s');
  }
}

/// 左上角标：真实像素尺寸。
///
/// 解析不到（网络图未下载、文件缺失）时退回 `record.sizeLabel`，角标不留空。
class _ActualImageSizeChip extends StatefulWidget {
  const _ActualImageSizeChip({required this.record});

  final ImageRecord record;

  @override
  State<_ActualImageSizeChip> createState() => _ActualImageSizeChipState();
}

class _ActualImageSizeChipState extends State<_ActualImageSizeChip> {
  late Future<String?> _sizeFuture;

  @override
  void initState() {
    super.initState();
    _sizeFuture = _resolveSizeLabel();
  }

  @override
  void didUpdateWidget(covariant _ActualImageSizeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final record = widget.record;
    final oldRecord = oldWidget.record;
    if (oldRecord.id != record.id ||
        oldRecord.status != record.status ||
        oldRecord.resultImagePath != record.resultImagePath ||
        oldRecord.resultImageUrl != record.resultImageUrl) {
      _sizeFuture = _resolveSizeLabel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _sizeFuture,
      builder: (context, snapshot) {
        return _ImageChip(label: snapshot.data ?? widget.record.sizeLabel);
      },
    );
  }

  Future<String?> _resolveSizeLabel() async {
    if (widget.record.status == ImageRecordStatus.loading ||
        widget.record.status == ImageRecordStatus.pending) {
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
    final resultImagePath = widget.record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return FileImage(File(resultImagePath));
    }

    final sourceImagePath = widget.record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return FileImage(File(sourceImagePath));
    }

    final resultImageUrl = widget.record.resultImageUrl;
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

/// 图上角标/徽章：文字只有一档（caption 10）。
class _ImageChip extends StatelessWidget {
  const _ImageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      constraints: const BoxConstraints(maxWidth: 94),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.imageChipFill(b),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppFontSize.caption,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1,
          color: AppColors.imageChipText(b),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ImageRecordStatus status;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    late final Color backgroundColor;
    late final Color foregroundColor;

    switch (status) {
      case ImageRecordStatus.pending:
        backgroundColor = AppColors.neutralSurface(b);
        foregroundColor = AppColors.neutralText(b);
      case ImageRecordStatus.loading:
        backgroundColor = AppColors.infoSurface(b);
        foregroundColor = AppColors.infoText(b);
      case ImageRecordStatus.done:
        backgroundColor = AppColors.successSurface(b);
        foregroundColor = AppColors.successText(b);
      case ImageRecordStatus.error:
        backgroundColor = AppColors.dangerSurface(b);
        foregroundColor = AppColors.dangerText(b);
      case ImageRecordStatus.cancelled:
        backgroundColor = AppColors.warningSurface(b);
        foregroundColor = AppColors.warningText(b);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.fullAll,
        boxShadow: AppShadow.card(b),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xxs,
        ),
        child: Text(
          status.label,
          style: TextStyle(
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            height: 1,
            color: foregroundColor,
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
    final b = Theme.of(context).brightness;
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
            left: AppSpace.xs,
            bottom: AppSpace.xs,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface(b).withValues(alpha: 0.86),
                borderRadius: AppRadius.fullAll,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: AppSpace.xxs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: AppIconSize.xs,
                      height: AppIconSize.xs,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    ),
                    const SizedBox(width: AppSpace.xxs),
                    Text(
                      '正在生成',
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(b),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceSoft(b), AppColors.primarySoft(b)],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: AppSpace.lg,
          height: AppSpace.lg,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({this.broken = false});

  /// 文件彻底缺失（true）与网络图加载失败（false）用不同图标。
  final bool broken;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ColoredBox(
      color: AppColors.surfaceSoft(b),
      child: Center(
        child: broken
            ? Icon(Icons.broken_image_rounded, color: AppColors.textTertiary(b))
            : Icon(
                Icons.image_not_supported_rounded,
                color: AppColors.textTertiary(b),
              ),
      ),
    );
  }
}
