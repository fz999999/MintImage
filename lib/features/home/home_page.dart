import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/generation_request.dart';
import '../../core/models/image_record.dart';
import '../../core/providers/favorite_folders_provider.dart';
import '../../core/providers/generation_provider.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/update_check_provider.dart';
import '../../core/version/app_version.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/desktop/desktop_dialog.dart';
import '../favorites/favorite_folder_sheet.dart';
import '../image_list/image_list_widget.dart';
import '../input/bottom_input_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.onOpenSettings});

  /// 打开设置 tab 的入口，由应用外壳注入（设置已从顶栏移到左导航）。
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey<BottomInputBarState> _inputBarKey =
      GlobalKey<BottomInputBarState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _selectionMode = false;
  Set<String> _selectedRecordIds = const <String>{};
  String? _activeFavoriteFolderId;
  bool _searchExpanded = false;
  String _searchQuery = '';
  int _attachmentCount = 0;
  final GlobalKey _favoriteButtonKey = GlobalKey();
  final Set<String> _deletingRecordIds = {};
  bool _favoriteBrowserOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final updateState = ref.watch(updateCheckProvider);
    final favoriteFoldersState = ref.watch(favoriteFoldersProvider);
    final b = Theme.of(context).brightness;
    final hasApiKey = settings.activeProfile.apiKey.trim().isNotEmpty;
    final activeFavoriteFolderId =
        _activeFavoriteFolderId != null &&
            favoriteFoldersState.containsFolder(_activeFavoriteFolderId!)
        ? _activeFavoriteFolderId
        : null;
    final activeFavoriteFolder = activeFavoriteFolderId == null
        ? null
        : favoriteFoldersState.folderById(activeFavoriteFolderId);
    final activeFavoriteRecordIds = activeFavoriteFolderId == null
        ? null
        : favoriteFoldersState.recordIdsForFolder(activeFavoriteFolderId);
    final hasActiveFavoriteFolder = activeFavoriteFolderId != null;
    final collectionLabel = _collectionLabel(
      hasFavoriteFolder: hasActiveFavoriteFolder,
      favoriteFolderTitle: activeFavoriteFolder?.title,
      count: _filteredRecordCount(
        ref.watch(imageListProvider),
        activeFavoriteRecordIds,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(child: _CollectionChip(label: collectionLabel)),
            if (updateState.hasUpdate) ...[
              const SizedBox(width: AppSpace.xs),
              _NewVersionBadge(onTap: () => _handleUpdateTap(updateState)),
            ],
          ],
        ),
        actions: [
          if (_selectionMode && _selectedRecordIds.isNotEmpty)
            IconButton(
              tooltip: '删除选中图像',
              onPressed: _confirmDeleteSelectedRecords,
              icon: const Icon(Icons.delete_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _selectionMode
                ? IconButton(
                    tooltip: '取消选择',
                    onPressed: _exitSelectionMode,
                    icon: const Icon(Icons.close_rounded),
                  )
                : TextButton(
                    onPressed: _enterSelectionMode,
                    child: const Text('选择'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IconButton(
              key: _favoriteButtonKey,
              tooltip: hasActiveFavoriteFolder ? '显示全部' : '选择收藏夹',
              onPressed: hasActiveFavoriteFolder
                  ? _clearFavoriteFolderFilter
                  : _openFavoriteFolders,
              color: hasActiveFavoriteFolder ? AppColors.favorite(b) : null,
              icon: Icon(
                hasActiveFavoriteFolder
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: IconButton(
              tooltip: _searchExpanded ? '关闭搜索' : '搜索提示词',
              onPressed: _toggleSearchPanel,
              color: _searchExpanded ? AppColors.primary(b) : null,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_searchExpanded ? 52 : 0),
          child: ClipRect(
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              height: _searchExpanded ? 52 : 0,
              padding: EdgeInsets.fromLTRB(12, 0, 12, _searchExpanded ? 8 : 0),
              alignment: Alignment.topCenter,
              child: _searchExpanded
                  ? TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _handleSearchChanged,
                      minLines: 1,
                      maxLines: 1,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '搜索 Prompt',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: AppIconSize.sm,
                        ),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清空搜索',
                                onPressed: _clearSearchQuery,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: AppIconSize.sm,
                                ),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.canvas(b), AppColors.canvasTint(b)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _BackgroundOrb(
                size: 220,
                colors: [
                  AppColors.primary(b).withValues(alpha: 0.035),
                  AppColors.primary(b).withValues(alpha: 0),
                ],
              ),
            ),
            Positioned(
              top: 120,
              left: -70,
              child: _BackgroundOrb(
                size: 180,
                colors: [
                  AppColors.primary(b).withValues(alpha: 0.025),
                  AppColors.primary(b).withValues(alpha: 0),
                ],
              ),
            ),
            Positioned(
              bottom: 90,
              right: -50,
              child: _BackgroundOrb(
                size: 200,
                colors: [
                  AppColors.primary(b).withValues(alpha: 0.025),
                  AppColors.primary(b).withValues(alpha: 0),
                ],
              ),
            ),
            Positioned.fill(
              child: hasApiKey
                  ? Column(
                      children: [
                        Expanded(
                          child: ImageListWidget(
                            onReusePrompt: (record) {
                              _inputBarKey.currentState?.prefillFromRecord(
                                record,
                              );
                            },
                            onReuseEdit: (record) {
                              _inputBarKey.currentState?.prefillForEdit(record);
                            },
                            onRegenerateRecord: _regenerateRecord,
                            onRetryRecord: _retryRecord,
                            onCancelRecord: _cancelRecord,
                            onDeleteRecord: _confirmDeleteRecord,
                            onToggleFavorite: _toggleRecordFavorite,
                            onPreviewNavigation: _handlePreviewNavigation,
                            currentAttachmentCount: _attachmentCount,
                            onAppendRecordToAttachments:
                                _appendRecordToAttachments,
                            selectionMode: _selectionMode,
                            selectedRecordIds: _selectedRecordIds,
                            onToggleSelection: _toggleRecordSelection,
                            onSelectRecord: _selectRecord,
                            favoriteRecordIds: activeFavoriteRecordIds,
                            activeFavoriteFolderTitle:
                                activeFavoriteFolder?.title,
                            searchQuery: _searchQuery,
                          ),
                        ),
                        BottomInputBar(
                          key: _inputBarKey,
                          onSubmit: _submitRequest,
                          onAttachmentCountChanged: (count) {
                            if (mounted) {
                              setState(() {
                                _attachmentCount = count;
                              });
                            }
                          },
                        ),
                      ],
                    )
                  : EmptyState(
                      title: '请先设置 API Key',
                      description:
                          '先在设置页补充 Base URL、模型名和 Key，然后就可以从底部输入框直接开始生成。',
                      actionLabel: '前往设置',
                      onAction: _handleOpenSettings,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest(GenerationRequest request) async {
    final favoriteFolderId =
        _activeFavoriteFolderId != null &&
            ref
                .read(favoriteFoldersProvider)
                .containsFolder(_activeFavoriteFolderId!)
        ? _activeFavoriteFolderId
        : null;
    await ref
        .read(generationProvider.notifier)
        .submit(request, favoriteFolderId: favoriteFolderId);
  }

  Future<void> _retryRecord(ImageRecord record) async {
    await ref.read(generationProvider.notifier).retryRecord(record);
  }

  Future<void> _regenerateRecord(ImageRecord record) async {
    await ref.read(generationProvider.notifier).regenerateRecord(record);
  }

  void _cancelRecord(String recordId) {
    ref.read(generationProvider.notifier).cancel(recordId);
  }

  Future<void> _confirmDeleteRecord(ImageRecord record) async {
    if (_selectionMode || !_deletingRecordIds.add(record.id)) return;
    try {
      if ((defaultTargetPlatform == TargetPlatform.windows)) {
        final confirmed = await showDesktopConfirm(
          context: context,
          title: '删除图像',
          message: '确认删除这条图像记录？此操作无法撤销。',
        );
        if (!confirmed || !mounted || _selectionMode) return;
      }
      await _deleteRecord(record);
    } catch (error) {
      if (mounted) {
        if ((defaultTargetPlatform == TargetPlatform.windows)) {
          await showDesktopInfo(context: context, title: '删除失败', text: '$error');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$error')));
        }
      }
    } finally {
      _deletingRecordIds.remove(record.id);
    }
  }

  Future<void> _deleteRecord(ImageRecord record) async {
    if (record.isInProgress) {
      await ref.read(generationProvider.notifier).deleteRecord(record.id);
      return;
    }

    await ref.read(imageListProvider.notifier).removeRecord(record.id);
  }

  Future<void> _toggleRecordFavorite(ImageRecord record) async {
    await showFavoriteFolderRecordSheet(context, record: record);
  }

  Future<void> _appendRecordToAttachments(ImageRecord record) async {
    final added = await _inputBarKey.currentState?.appendImageFromRecord(
      record,
    );
    if (added != true || !mounted) {
      return;
    }

    final count =
        _inputBarKey.currentState?.attachmentCount ?? _attachmentCount;
    setState(() {
      _attachmentCount = count;
    });
  }

  Future<void> _handlePreviewNavigation(
    Future<void> Function() navigate,
  ) async {
    _clearHomeInputFocus();
    await navigate();
    if (!mounted) {
      return;
    }
    _clearHomeInputFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _clearHomeInputFocus();
      }
    });
  }

  void _clearHomeInputFocus() {
    _inputBarKey.currentState?.unfocusPrompt();
    _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedRecordIds = const <String>{};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedRecordIds = const <String>{};
    });
  }

  void _toggleRecordSelection(String recordId) {
    if (!_selectionMode) {
      return;
    }

    final selected = {..._selectedRecordIds};
    if (!selected.add(recordId)) {
      selected.remove(recordId);
    }
    setState(() {
      _selectedRecordIds = selected;
    });
  }

  void _selectRecord(String recordId) {
    if (!_selectionMode || _selectedRecordIds.contains(recordId)) {
      return;
    }

    setState(() {
      _selectedRecordIds = {..._selectedRecordIds, recordId};
    });
  }

  void _clearFavoriteFolderFilter() {
    _clearHomeInputFocus();
    setState(() {
      _selectionMode = false;
      _selectedRecordIds = const <String>{};
      _activeFavoriteFolderId = null;
    });
  }

  Future<void> _openFavoriteFolders() async {
    if (_favoriteBrowserOpen) return;
    final box = _favoriteButtonKey.currentContext?.findRenderObject();
    final anchor = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size : null;
    _clearHomeInputFocus();
    _exitSelectionMode();
    _favoriteBrowserOpen = true;
    String? folderId;
    try {
      folderId = await showFavoriteFolderBrowserSheet(context, anchorRect: anchor);
    } finally {
      _favoriteBrowserOpen = false;
    }
    if (!mounted || folderId == null) {
      return;
    }

    setState(() {
      _activeFavoriteFolderId = folderId;
    });
  }

  void _toggleSearchPanel() {
    if (_searchExpanded) {
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _selectionMode = false;
        _selectedRecordIds = const <String>{};
        _searchExpanded = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _selectionMode = false;
      _selectedRecordIds = const <String>{};
      _searchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearchQuery() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _confirmDeleteSelectedRecords() async {
    final selectedCount = _selectedRecordIds.length;
    if (selectedCount == 0) {
      return;
    }

    _clearHomeInputFocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除图像'),
          content: Text('确认删除这 $selectedCount 个图像？'),
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
    _clearHomeInputFocus();

    if (confirmed != true) {
      return;
    }

    final selectedIds = {..._selectedRecordIds};
    final records = ref
        .read(imageListProvider)
        .where((record) => selectedIds.contains(record.id))
        .toList();

    _exitSelectionMode();

    for (final record in records) {
      await _deleteRecord(record);
    }
  }

  /// 空态里的「前往设置」：先收掉页面内焦点，再切到设置 tab。
  void _handleOpenSettings() {
    _clearHomeInputFocus();
    widget.onOpenSettings?.call();
  }

  /// 「全部作品 (N)」的 N：与图墙同一套筛选（收藏夹 + 提示词搜索）。
  int _filteredRecordCount(
    List<ImageRecord> records,
    Set<String>? favoriteRecordIds,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    var count = 0;
    for (final record in records) {
      if (favoriteRecordIds != null &&
          !favoriteRecordIds.contains(record.id)) {
        continue;
      }
      if (query.isNotEmpty && !record.prompt.toLowerCase().contains(query)) {
        continue;
      }
      count++;
    }
    return count;
  }

  /// 标题区文案：搜索优先，其次收藏夹名，最后「全部作品」。
  String _collectionLabel({
    required bool hasFavoriteFolder,
    required String? favoriteFolderTitle,
    required int count,
  }) {
    if (_searchQuery.trim().isNotEmpty) {
      return '搜索结果 ($count)';
    }
    if (hasFavoriteFolder) {
      return '${favoriteFolderTitle ?? '收藏'} ($count)';
    }
    return '全部作品 ($count)';
  }

  Future<void> _handleUpdateTap(UpdateCheckState updateState) async {
    if (!updateState.hasUpdate) {
      return;
    }

    if (Platform.isIOS) {
      _clearHomeInputFocus();
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('发现新版本'),
            content: Text(
              '有新的版本 ${updateState.latestVersion ?? ''}，请前往 ${AppVersion.repositoryUrl} 下载。',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
      _clearHomeInputFocus();
      return;
    }

    var launched = false;
    try {
      final uri = Uri.parse(updateState.releaseUrl);
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开下载页：${updateState.releaseUrl}')),
      );
    }
  }
}

/// 标题区的作品计数：`全部作品 (N)` / `收藏夹名 (N)` / `搜索结果 (N)`。
class _CollectionChip extends StatelessWidget {
  const _CollectionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.grid_view,
          size: AppIconSize.sm,
          color: AppColors.textTertiary(b),
        ),
        const SizedBox(width: AppSpace.xxs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFontSize.label,
              color: AppColors.textTertiary(b),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewVersionBadge extends StatelessWidget {
  const _NewVersionBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.successSurface(b),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: AppColors.successText(b).withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          'New',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.successText(b),
            fontSize: AppFontSize.caption,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
