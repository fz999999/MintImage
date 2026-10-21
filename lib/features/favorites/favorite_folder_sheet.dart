import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/favorite_folder.dart';
import '../../core/models/image_record.dart';
import '../../core/providers/favorite_folders_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/desktop/desktop_dialog.dart';
import '../../shared/widgets/desktop/desktop_menu.dart';
import '../../shared/widgets/desktop/desktop_popover.dart';

Future<String?> showFavoriteFolderBrowserSheet(
  BuildContext context, {
  Rect? anchorRect,
}) {
  if ((defaultTargetPlatform == TargetPlatform.windows)) {
    return showDesktopPopover<String>(
      context: context,
      anchorRect: anchorRect,
      width: 400,
      builder: (_) => const _FavoriteFolderSheet(),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _FavoriteFolderSheet(),
  );
}

Future<void> showFavoriteFolderRecordSheet(
  BuildContext context, {
  required ImageRecord record,
  Rect? anchorRect,
}) async {
  if ((defaultTargetPlatform == TargetPlatform.windows)) {
    await showDesktopPopover<void>(
      context: context,
      anchorRect: anchorRect,
      width: 400,
      builder: (_) => _FavoriteFolderSheet(record: record),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FavoriteFolderSheet(record: record),
  );
}

class _FavoriteFolderSheet extends ConsumerStatefulWidget {
  const _FavoriteFolderSheet({this.record});

  final ImageRecord? record;

  @override
  ConsumerState<_FavoriteFolderSheet> createState() =>
      _FavoriteFolderSheetState();
}

class _FavoriteFolderSheetState extends ConsumerState<_FavoriteFolderSheet> {
  final TextEditingController _folderController = TextEditingController();
  final FocusNode _folderFocusNode = FocusNode();
  bool _creating = false;
  String? _createError;
  bool _createBusy = false;
  bool _folderMenuOpen = false;
  String _query = '';
  final Set<String> _busyFolderIds = {};
  final Map<String, String> _folderErrors = {};

  bool get _isRecordMode => widget.record != null;

  @override
  void dispose() {
    _folderController.dispose();
    _folderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final state = ref.watch(favoriteFoldersProvider);
    final folders = (defaultTargetPlatform == TargetPlatform.windows) && _query.isNotEmpty
        ? state.folders.where((folder) =>
            folder.title.toLowerCase().contains(_query.toLowerCase())).toList()
        : state.folders;
    final selectedFolderIds = widget.record == null
        ? const <String>{}
        : state.folderIdsForRecord(widget.record!.id);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight:
            defaultTargetPlatform == TargetPlatform.windows
                ? double.infinity : screenHeight * 0.72),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            defaultTargetPlatform == TargetPlatform.windows ? 16 : 0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRecordMode ? '收藏到' : '收藏夹',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(b),
                ),
              ),
              if (_isRecordMode) ...[
                const SizedBox(height: 4),
                Text(
                  '将结果收藏到：',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if ((defaultTargetPlatform == TargetPlatform.windows) && state.folders.length > 8) ...[
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '搜索收藏夹',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    final busy = _busyFolderIds.contains(folder.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FavoriteFolderRow(
                          folder: folder,
                          selected: selectedFolderIds.contains(folder.id),
                          recordMode: _isRecordMode,
                          busy: busy,
                          onTap: busy ? null : () => _handleFolderTap(folder.id),
                          onLongPress: folder.isDefault || busy
                              ? null
                              : () => _confirmDeleteFolder(folder),
                          onMenu: !(defaultTargetPlatform == TargetPlatform.windows) || busy || folder.isDefault
                              ? null
                              : (anchor) => _showFolderMenu(folder, anchor),
                        ),
                        if (_folderErrors[folder.id] case final error?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(error,
                              style: TextStyle(color: AppColors.dangerText(b))),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _buildCreateRow(context),
              if ((defaultTargetPlatform == TargetPlatform.windows) && _isRecordMode) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busyFolderIds.isNotEmpty || _createBusy
                        ? null : () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRow(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (!_creating) {
      return InkWell(
        borderRadius: AppRadius.smAll,
        onTap: () {
          setState(() {
            _creating = true;
            _createError = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _folderFocusNode.requestFocus();
            }
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft(b),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.border(b)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.primaryStrong(b)),
              const SizedBox(width: 6),
              Text(
                '新建收藏夹',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryStrong(b),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                enabled: !_createBusy,
                controller: _folderController,
                focusNode: _folderFocusNode,
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createFolder(),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '收藏夹名称',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_createBusy)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: '创建',
                icon: const Icon(Icons.check_rounded, size: 18),
                color: AppColors.primaryStrong(b),
                onPressed: _createFolder,
              ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '取消新建',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textSecondary(b),
              onPressed: _createBusy ? null : _cancelCreate,
            ),
          ],
        ),
        if (_createError != null) ...[
          const SizedBox(height: 6),
          Text(
            _createError!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.dangerText(
                Theme.of(context).brightness,
              ),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleFolderTap(String folderId) async {
    if (_busyFolderIds.contains(folderId)) return;
    final record = widget.record;
    if (record == null) {
      Navigator.of(context).pop(folderId);
      return;
    }
    setState(() {
      _busyFolderIds.add(folderId);
      _folderErrors.remove(folderId);
    });
    try {
      await ref.read(favoriteFoldersProvider.notifier)
          .toggleRecordInFolder(folderId: folderId, recordId: record.id);
    } catch (error) {
      if (mounted) setState(() => _folderErrors[folderId] = '收藏更新失败：$error');
    } finally {
      if (mounted) setState(() => _busyFolderIds.remove(folderId));
    }
  }

  Future<void> _createFolder() async {
    if (_createBusy) return;
    setState(() {
      _createBusy = true;
      _createError = null;
    });
    bool created;
    try {
      created = await ref.read(favoriteFoldersProvider.notifier)
          .createFolder(_folderController.text);
    } catch (error) {
      if (mounted) setState(() => _createError = '创建失败：$error');
      return;
    } finally {
      if (mounted) setState(() => _createBusy = false);
    }
    if (!mounted) {
      return;
    }
    if (!created) {
      setState(() {
        _createError = '名称不能为空，也不能和已有收藏夹重复。';
      });
      return;
    }

    _folderController.clear();
    setState(() {
      _creating = false;
      _createError = null;
    });
  }

  void _cancelCreate() {
    _folderController.clear();
    _folderFocusNode.unfocus();
    setState(() {
      _creating = false;
      _createError = null;
    });
  }

  Future<void> _showFolderMenu(FavoriteFolderSummary folder, Rect anchor) async {
    if (folder.isDefault || _folderMenuOpen ||
        _busyFolderIds.contains(folder.id)) {
      return;
    }
    _folderMenuOpen = true;
    try {
      final action = await showDesktopMenu<String>(
        context: context,
        anchorRect: anchor,
        items: const [DesktopMenuItem(
          value: 'delete', label: '删除收藏夹', destructive: true,
          leading: Icon(Icons.delete_rounded),
        )],
      );
      if (mounted && action == 'delete') await _confirmDeleteFolder(folder);
    } finally {
      _folderMenuOpen = false;
    }
  }

  Future<void> _confirmDeleteFolder(FavoriteFolderSummary folder) async {
    if (folder.isDefault || _busyFolderIds.contains(folder.id)) return;
    setState(() => _busyFolderIds.add(folder.id));
    try {
    final confirmed = (defaultTargetPlatform == TargetPlatform.windows)
        ? await showDesktopConfirm(
            context: context,
            title: '删除收藏夹',
            message: '确认删除“${folder.title}”？其中的生成结果不会被删除。',
          )
        : await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除收藏夹'),
          content: Text('确认删除“${folder.title}”？其中的生成结果不会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(favoriteFoldersProvider.notifier).deleteFolder(folder.id);
    } catch (error) {
      if (mounted) setState(() => _folderErrors[folder.id] = '删除失败：$error');
    } finally {
      if (mounted) setState(() => _busyFolderIds.remove(folder.id));
    }
  }
}

class _FavoriteFolderRow extends StatelessWidget {
  const _FavoriteFolderRow({
    required this.folder,
    required this.selected,
    required this.recordMode,
    required this.onTap,
    required this.onLongPress,
    required this.busy,
    this.onMenu,
  });

  final bool busy;
  final void Function(Rect anchor)? onMenu;
  final FavoriteFolderSummary folder;
  final bool selected;
  final bool recordMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onMenu == null ? null : (details) => onMenu!(
        Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 1, 1)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.favorite(b).withValues(alpha: 0.16)
              : AppColors.surfaceSoft(b).withValues(alpha: 0.72),
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: selected ? AppColors.favorite(b) : AppColors.border(b),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${folder.title}（${folder.recordCount}）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary(b),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (recordMode && selected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.favorite(b),
              ),
            ],
            const SizedBox(width: 10),
            _FolderPreviewStrip(records: folder.previewRecords),
            if (busy)
              const SizedBox.square(dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            if (onMenu != null)
              Builder(builder: (buttonContext) => IconButton(
                tooltip: '收藏夹操作',
                onPressed: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize) {
                    onMenu!(box.localToGlobal(Offset.zero) & box.size);
                  }
                },
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
              )), 
          ],
        ),
      ),
    );
  }
}

class _FolderPreviewStrip extends StatelessWidget {
  const _FolderPreviewStrip({required this.records});

  final List<ImageRecord> records;

  static const double _thumbSize = 50.0;
  static const double _step = 23.0;
  static const double _sidePadding = 10.0;
  static const double _bottomPadding = 8.0;
  static const double _angleStep = 0.22;
  static const int _maxShow = 4;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (records.isEmpty) {
      return SizedBox(
        height: _thumbSize,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            '暂无收藏',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary(b),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final count = records.length.clamp(0, _maxShow);
    final totalWidth = _step * (count - 1) + _thumbSize + _sidePadding * 2;
    const totalHeight = _thumbSize + 22.0;
    final centerIndex = (count - 1) / 2;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < count; i++)
            Positioned(
              left: _sidePadding + i * _step,
              bottom: _bottomPadding,
              child: Transform.rotate(
                angle: (i - centerIndex) * _angleStep,
                alignment: Alignment.bottomCenter,
                child: _buildCard(records[i], i, count, b),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(ImageRecord record, int index, int count, Brightness b) {
    final depth = count <= 1 ? 1.0 : index / (count - 1);
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        borderRadius: AppRadius.xsAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1 + depth * 0.17),
            blurRadius: 4 + depth * 7,
            spreadRadius: 0,
            offset: const Offset(1.0, 2.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xsAll,
        child: ColoredBox(
          color: AppColors.surfaceSoft(b),
          child: _buildImage(record, b),
        ),
      ),
    );
  }

  Widget _buildImage(ImageRecord record, Brightness b) {
    final localPath = record.resultImagePath ?? record.sourceImagePath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 100,
      );
    }

    final url = record.resultImageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: 100,
        maxWidthDiskCache: 100,
        placeholder: (_, _) => ColoredBox(color: AppColors.surface(b)),
        errorWidget: (_, _, _) =>
            const Icon(Icons.image_not_supported_rounded, size: 14),
      );
    }

    return ColoredBox(
      color: AppColors.surfaceSoft(b),
      child: const Center(child: Icon(Icons.broken_image_rounded, size: 14)),
    );
  }
}

