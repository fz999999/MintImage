import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/models/image_record.dart';
import '../../core/models/settings_model.dart';
import '../../core/providers/image_aspect_ratio_provider.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/empty_state.dart';
import 'image_cell.dart';

class ImageListWidget extends ConsumerStatefulWidget {
  const ImageListWidget({
    super.key,
    required this.onReusePrompt,
    required this.onReuseEdit,
    required this.onRegenerateRecord,
    required this.onRetryRecord,
    required this.onCancelRecord,
    required this.onDeleteRecord,
    required this.onToggleFavorite,
    required this.onPreviewNavigation,
    required this.currentAttachmentCount,
    required this.onAppendRecordToAttachments,
    required this.selectionMode,
    required this.selectedRecordIds,
    required this.onToggleSelection,
    required this.onSelectRecord,
    required this.favoriteRecordIds,
    required this.activeFavoriteFolderTitle,
    required this.searchQuery,
  });

  final ValueChanged<ImageRecord> onReusePrompt;
  final ValueChanged<ImageRecord> onReuseEdit;
  final ValueChanged<ImageRecord> onRegenerateRecord;
  final ValueChanged<ImageRecord> onRetryRecord;
  final ValueChanged<String> onCancelRecord;
  final ValueChanged<ImageRecord> onDeleteRecord;
  final ValueChanged<ImageRecord> onToggleFavorite;
  final Future<void> Function(Future<void> Function() navigate)
  onPreviewNavigation;
  final int currentAttachmentCount;
  final ValueChanged<ImageRecord> onAppendRecordToAttachments;
  final bool selectionMode;
  final Set<String> selectedRecordIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onSelectRecord;
  final Set<String>? favoriteRecordIds;
  final String? activeFavoriteFolderTitle;
  final String searchQuery;

  @override
  ConsumerState<ImageListWidget> createState() => _ImageListWidgetState();
}

class _ImageListWidgetState extends ConsumerState<ImageListWidget> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _dragSelectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ImageListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectionMode && oldWidget.selectionMode) {
      _dragSelectedIds.clear();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = ref.watch(imageListProvider);
    final records = _filteredRecords(allRecords);
    final density = ref.watch(
      settingsProvider.select((settings) => settings.galleryDensity),
    );

    // 空态不再包 RefreshIndicator：下拉刷新与 P2 的滚动观感冲突，
    // 且首页已经有刷新入口。
    if (allRecords.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
        ),
        children: const [
          SizedBox(height: AppSpace.xl + AppSpace.md),
          EmptyState(
            title: '还没有生成记录',
            description: '输入提示词并点击发送后，新的生成任务会立即出现在这里。',
          ),
        ],
      );
    }

    if (records.isEmpty) {
      final activeFavoriteFolderTitle = widget.activeFavoriteFolderTitle;
      final hasSearchQuery = widget.searchQuery.trim().isNotEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
        ),
        children: [
          const SizedBox(height: AppSpace.xl + AppSpace.md),
          EmptyState(
            title: hasSearchQuery || activeFavoriteFolderTitle == null
                ? '没有匹配结果'
                : '$activeFavoriteFolderTitle 没有内容',
            description: hasSearchQuery || activeFavoriteFolderTitle == null
                ? '换一个提示词关键词再试试。'
                : '从生成结果菜单添加收藏，或在这个收藏夹中直接生成新图片。',
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewRecords = records
            .where(_canPreviewRecord)
            .toList(growable: false);
        final metrics = _GalleryMetrics.fromContext(
          context,
          constraints.maxWidth,
          density,
        );
        final ratioCache = ref.watch(imageAspectRatioCacheProvider.notifier);
        // 订阅解析进度：文件头解析出新比例后重建，卡片高度随即校正。
        ref.watch(imageAspectRatioCacheProvider);

        // 反过来喂缓存：清掉已删除记录的比例，长会话不会一直涨内存。
        ratioCache.retainOnly(records);

        final layout = _MasonryLayout.build(
          records: records,
          metrics: metrics,
          ratioOf: ratioCache.ratioFor,
        );
        final grid = MasonryGridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            metrics.sidePadding,
            metrics.topPadding,
            metrics.sidePadding,
            metrics.bottomPadding,
          ),
          itemCount: records.length,
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columnCount,
          ),
          mainAxisSpacing: metrics.gap,
          crossAxisSpacing: metrics.gap,
          itemBuilder: (context, index) {
            final record = records[index];
            return ImageCell(
              record: record,
              imageHeight: layout.imageHeights[index],
              imageFit: layout.imageFits[index],
              previewRecords: previewRecords,
              previewInitialIndex: previewRecords.indexWhere(
                (item) => item.id == record.id,
              ),
              onReusePrompt: () => widget.onReusePrompt(record),
              onReuseEdit: () => widget.onReuseEdit(record),
              onRegenerate: () => widget.onRegenerateRecord(record),
              onRetry: () => widget.onRetryRecord(record),
              onCancel: () => widget.onCancelRecord(record.id),
              onDelete: () => widget.onDeleteRecord(record),
              onToggleFavorite: () => widget.onToggleFavorite(record),
              onPreviewNavigation: widget.onPreviewNavigation,
              currentAttachmentCount: widget.currentAttachmentCount,
              onAppendCurrentImageToAttachments: () =>
                  widget.onAppendRecordToAttachments(record),
              selectionMode: widget.selectionMode,
              selected: widget.selectedRecordIds.contains(record.id),
              onSelectionToggle: () => widget.onToggleSelection(record.id),
            );
          },
        );

        if (!widget.selectionMode) {
          return grid;
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _dragSelectedIds.clear(),
          onPointerMove: (event) {
            _selectAtPosition(event.localPosition, layout, records);
          },
          onPointerUp: (_) => _dragSelectedIds.clear(),
          onPointerCancel: (_) => _dragSelectedIds.clear(),
          child: grid,
        );
      },
    );
  }

  List<ImageRecord> _filteredRecords(List<ImageRecord> records) {
    final query = widget.searchQuery.trim().toLowerCase();
    final favoriteRecordIds = widget.favoriteRecordIds;
    return records
        .where((record) {
          if (favoriteRecordIds != null &&
              !favoriteRecordIds.contains(record.id)) {
            return false;
          }
          if (query.isNotEmpty &&
              !record.prompt.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool _canPreviewRecord(ImageRecord record) {
    return record.resultImagePath != null ||
        record.resultImageUrl != null ||
        record.sourceAttachmentPaths.isNotEmpty;
  }

  void _selectAtPosition(
    Offset localPosition,
    _MasonryLayout layout,
    List<ImageRecord> records,
  ) {
    final index = layout.indexAt(
      localPosition,
      scrollOffset: _scrollController.offset,
    );
    if (index == null) {
      return;
    }

    final recordId = records[index].id;
    if (_dragSelectedIds.add(recordId)) {
      widget.onSelectRecord(recordId);
    }
  }
}

/// 图墙的几何计算。
///
/// 卡片宽高不再统一：图区高度 = 列宽 ÷ 图片真实宽高比，
/// 这样竖图就长、横图就矮，**一张都不会被裁**。
/// 密度档位只影响「卡片至少多宽」和「图区最多多高」两个约束。
class _GalleryMetrics {
  const _GalleryMetrics({
    required this.columnCount,
    required this.cellWidth,
    required this.sidePadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.gap,
    required this.maxImageHeight,
    required this.minImageHeight,
  });

  /// 桌面列数上限：紧凑 6 / 标准 4 / 大图 3（由密度档位给出）。
  static const int _phoneColumns = 2;

  /// 手机判定：最短边小于 600 视为手机布局。
  static const double _phoneBreakpoint = 600;

  /// 文字区固定高度：prompt 两行 + 元信息一行 + 时间/星标/菜单一行。
  /// 文字区高度（上移自 [ImageCell.footerHeight]，两边必须一致，
  /// 否则排版表算出的卡片高度会与真实渲染对不上，拖拽命中会偏）。
  static const double footerHeight = ImageCell.footerHeight;

  /// 太扁的图（例如 4:1 长条）会矮到看不见，垫个下限。
  static const double minImageHeightFloor = 90;

  final int columnCount;
  final double cellWidth;
  final double sidePadding;
  final double topPadding;
  final double bottomPadding;
  final double gap;
  final double maxImageHeight;
  final double minImageHeight;

  static _GalleryMetrics fromContext(
    BuildContext context,
    double width,
    GalleryDensity density,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final isPhone = screen.shortestSide < _phoneBreakpoint;
    final sidePadding = isPhone ? 10.0 : 14.0;
    const topPadding = 10.0;
    const bottomPadding = AppSpace.lg;
    final gap = isPhone ? 8.0 : 12.0;
    final availableWidth = width - sidePadding * 2;

    // 列数反推：floor((可用宽 + gap) / (最小卡宽 + gap))，再夹到密度上限。
    final rawColumns =
        ((availableWidth + gap) / (density.minCardWidth + gap)).floor();
    final columnCount = isPhone
        ? _phoneColumns
        : rawColumns.clamp(1, density.maxColumns).toInt();
    final cellWidth = (availableWidth - gap * (columnCount - 1)) / columnCount;

    return _GalleryMetrics(
      columnCount: columnCount,
      cellWidth: cellWidth,
      sidePadding: sidePadding,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      gap: gap,
      maxImageHeight: density.maxImageHeight,
      minImageHeight: math.min(minImageHeightFloor, cellWidth),
    );
  }

  /// 图区高度：按真实比例算，夹到 [minImageHeight, maxImageHeight]。
  double imageHeightFor(double aspectRatio) {
    final ratio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : ImageAspectRatioCache.fallbackAspectRatio;
    final natural = cellWidth / ratio;
    return natural.clamp(minImageHeight, math.max(minImageHeight, maxImageHeight));
  }

  /// 只有「被夹高」的图才需要 letterbox，否则比例严丝合缝，用 cover 也不裁。
  BoxFit fitFor(double aspectRatio, double imageHeight) {
    final ratio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : ImageAspectRatioCache.fallbackAspectRatio;
    final natural = cellWidth / ratio;
    return (natural - imageHeight).abs() < 0.5
        ? BoxFit.cover
        : BoxFit.contain;
  }
}

/// 与 [SliverMasonryGrid] 同一套贪心算法（每次放到最短的那一列）的离线排版表。
///
/// 自己算一遍而不是去问渲染树，是为了批量选择时能用纯数学把「指针在哪一格」
/// 换算成索引 —— 瀑布流每格高度不同，原来按行高整除的映射已经失效。
class _MasonryLayout {
  const _MasonryLayout({
    required this.imageHeights,
    required this.imageFits,
    required this.cellTops,
    required this.cellLefts,
    required this.cellHeights,
    required this.metrics,
  });

  final List<double> imageHeights;
  final List<BoxFit> imageFits;

  /// 每格在滚动内容坐标系里的左上角与高度（不含 padding 偏移）。
  final List<double> cellTops;
  final List<double> cellLefts;
  final List<double> cellHeights;
  final _GalleryMetrics metrics;

  static _MasonryLayout build({
    required List<ImageRecord> records,
    required _GalleryMetrics metrics,
    required double Function(ImageRecord) ratioOf,
  }) {
    final count = records.length;
    final imageHeights = List<double>.filled(count, 0);
    final imageFits = List<BoxFit>.filled(count, BoxFit.cover);
    final cellTops = List<double>.filled(count, 0);
    final cellLefts = List<double>.filled(count, 0);
    final cellHeights = List<double>.filled(count, 0);

    final columnBottoms = List<double>.filled(metrics.columnCount, 0);

    for (var i = 0; i < count; i++) {
      final ratio = ratioOf(records[i]);
      final imageHeight = metrics.imageHeightFor(ratio);
      final cardHeight = imageHeight + _GalleryMetrics.footerHeight;

      var column = 0;
      for (var c = 1; c < columnBottoms.length; c++) {
        if (columnBottoms[c] < columnBottoms[column]) {
          column = c;
        }
      }

      imageHeights[i] = imageHeight;
      imageFits[i] = metrics.fitFor(ratio, imageHeight);
      cellTops[i] = columnBottoms[column];
      cellLefts[i] = column * (metrics.cellWidth + metrics.gap);
      cellHeights[i] = cardHeight;
      columnBottoms[column] = columnBottoms[column] + cardHeight + metrics.gap;
    }

    return _MasonryLayout(
      imageHeights: imageHeights,
      imageFits: imageFits,
      cellTops: cellTops,
      cellLefts: cellLefts,
      cellHeights: cellHeights,
      metrics: metrics,
    );
  }

  /// 把指针位置换算成记录索引；落在缝隙或空白处返回 null。
  int? indexAt(Offset localPosition, {required double scrollOffset}) {
    final x = localPosition.dx - metrics.sidePadding;
    final y = localPosition.dy + scrollOffset - metrics.topPadding;
    if (x < 0 || y < 0) {
      return null;
    }

    for (var i = 0; i < cellTops.length; i++) {
      final left = cellLefts[i];
      if (x < left || x > left + metrics.cellWidth) {
        continue;
      }
      final top = cellTops[i];
      if (y >= top && y <= top + cellHeights[i]) {
        return i;
      }
    }
    return null;
  }
}
