import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/image_list_provider.dart';
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
        final metrics = _GridMetrics.fromContext(context, constraints.maxWidth);
        final grid = GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            metrics.sidePadding,
            metrics.topPadding,
            metrics.sidePadding,
            metrics.bottomPadding,
          ),
          itemCount: records.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columnCount,
            crossAxisSpacing: metrics.gap,
            mainAxisSpacing: metrics.gap,
            mainAxisExtent: metrics.cellHeight,
          ),
          itemBuilder: (context, index) {
            final record = records[index];
            return ImageCell(
              record: record,
              imageHeight: metrics.imageHeight,
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
            _selectAtPosition(event.localPosition, metrics, records);
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
    _GridMetrics metrics,
    List<ImageRecord> records,
  ) {
    final index = _indexAtPosition(localPosition, metrics, records.length);
    if (index == null) {
      return;
    }

    final recordId = records[index].id;
    if (_dragSelectedIds.add(recordId)) {
      widget.onSelectRecord(recordId);
    }
  }

  int? _indexAtPosition(
    Offset localPosition,
    _GridMetrics metrics,
    int recordCount,
  ) {
    final x = localPosition.dx - metrics.sidePadding;
    final y = localPosition.dy + _scrollController.offset - metrics.topPadding;

    if (x < 0 || y < 0) {
      return null;
    }

    final columnStride = metrics.cellWidth + metrics.gap;
    final rowStride = metrics.cellHeight + metrics.gap;
    final column = x ~/ columnStride;
    final row = y ~/ rowStride;

    if (column < 0 || column >= metrics.columnCount) {
      return null;
    }

    final xInCell = x - column * columnStride;
    final yInCell = y - row * rowStride;
    if (xInCell > metrics.cellWidth || yInCell > metrics.cellHeight) {
      return null;
    }

    final index = row * metrics.columnCount + column;
    if (index < 0 || index >= recordCount) {
      return null;
    }

    return index;
  }
}

/// 图墙的几何计算。
///
/// P2 起卡片是 16:9 的图 + 76px 文字区，图高由列宽推导，
/// 不再写死 188/206，宽屏下卡片才不会被压扁。
class _GridMetrics {
  const _GridMetrics({
    required this.columnCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.imageHeight,
    required this.sidePadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.gap,
  });

  /// 卡片最小宽度：低于这个值列数就减一。
  ///
  /// 取 220 而不是 180：180 时 1280 宽的窗口会排到 6 列，单卡图高只剩 112px，
  /// 已经看不清画面；220 时 1280 约 5 列（图高 136）、1600 封顶 6 列（图高 146）。
  static const double _minCardWidth = 220;

  /// 桌面列数区间。窄窗靠 [columnCount] 的下限保 3 列，
  /// 宽屏封顶 6 列（与 Stitch 稿 1600 宽 6 列一致），避免图被压成小方块。
  static const int _minColumns = 3;
  static const int _maxColumns = 6;

  /// 文字区固定高度：prompt 两行 + 元信息一行 + 时间/星标/菜单一行。
  static const double _footerHeight = 88;

  /// 手机判定：最短边小于 600 视为手机布局（保持 2 列）。
  static const double _phoneBreakpoint = 600;

  final int columnCount;
  final double cellWidth;
  final double cellHeight;
  final double imageHeight;
  final double sidePadding;
  final double topPadding;
  final double bottomPadding;
  final double gap;

  static _GridMetrics fromContext(BuildContext context, double width) {
    final screen = MediaQuery.sizeOf(context);
    final isPhone = screen.shortestSide < _phoneBreakpoint;
    final sidePadding = isPhone ? 10.0 : 14.0;
    const topPadding = 10.0;
    const bottomPadding = AppSpace.lg;
    final gap = isPhone ? 8.0 : 10.0;
    final availableWidth = width - sidePadding * 2;

    // 列数反推：先按「卡片最小宽 180」算极限列数，形如
    // floor((可用宽 + gap) / (180 + gap))，再夹到 3~8 列。
    final desktopColumnCount = ((availableWidth + gap) / (_minCardWidth + gap))
        .floor();
    final columnCount = isPhone
        ? 2
        : desktopColumnCount.clamp(_minColumns, _maxColumns).toInt();
    final cellWidth = (availableWidth - gap * (columnCount - 1)) / columnCount;
    // 16:9 图区高度完全跟列宽走。
    final imageHeight = cellWidth * 9 / 16;

    return _GridMetrics(
      columnCount: columnCount,
      cellWidth: cellWidth,
      cellHeight: imageHeight + _footerHeight,
      imageHeight: imageHeight,
      sidePadding: sidePadding,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      gap: gap,
    );
  }
}
