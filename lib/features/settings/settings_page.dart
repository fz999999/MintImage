import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/favorite_folders_provider.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/storage_cleanup_service.dart';
import '../../core/services/webdav_backup_service.dart';
import '../../core/version/app_version.dart';
import '../../shared/theme.dart';
import '../logs/request_log_page.dart';
import 'api_profile_edit_page.dart';
import 'prompt_optimization_profile_edit_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _wideLayoutBreakpoint = 840.0;
  static const _wideContentMaxWidth = 1120.0;
  static const _compactContentMaxWidth = 720.0;
  static const _sectionSpacing = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppThemeTokens.canvas, AppThemeTokens.canvasTint],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideLayoutBreakpoint;
            final apiSections = [
              _buildImageProfilesSection(context, ref, settings, wide: wide),
              const SizedBox(height: _sectionSpacing),
              _buildPromptOptimizationSection(
                context,
                ref,
                settings,
                wide: wide,
              ),
              const SizedBox(height: _sectionSpacing),
              _buildRequestGroup(context, ref, settings),
            ];
            final dataSections = [
              _buildBackupGroup(context, ref, settings),
              const SizedBox(height: _sectionSpacing),
              _SettingsGroup(
                title: '历史与存储',
                children: [
                  _SettingsTile(
                    icon: Icons.cleaning_services_rounded,
                    title: '清理缓存',
                    subtitle: '删除不再被记录使用的图片、标注图与临时文件',
                    onTap: () => _cleanStorage(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_sweep_rounded,
                    title: '清除历史记录',
                    subtitle: '删除所有生成记录，不会清除 API 配置',
                    destructive: true,
                    onTap: () => _clearHistory(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: _sectionSpacing),
              _buildAboutGroup(context),
            ];

            return ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 16,
                8,
                wide ? 24 : 16,
                32,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: wide
                          ? _wideContentMaxWidth
                          : _compactContentMaxWidth,
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: apiSections,
                                ),
                              ),
                              const SizedBox(width: _sectionSpacing),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: dataSections,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...apiSections,
                              const SizedBox(height: _sectionSpacing),
                              ...dataSections,
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageProfilesSection(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings, {
    required bool wide,
  }) {
    final canDelete = settings.profiles.length > 1;
    return _ProfileSection(
      icon: Icons.auto_awesome_motion_rounded,
      title: '生图 API',
      subtitle: '点击卡片切换当前使用的配置',
      addLabel: '添加',
      onAdd: () => _openImageEditor(context),
      emptyText: '还没有生图 API，添加后即可开始生成图片。',
      children: [
        for (final profile in settings.profiles)
          _ProfileCard(
            key: ValueKey('image-${profile.id}'),
            name: profile.name,
            badge: profile.apiMode.shortLabel,
            baseUrl: profile.normalizedBaseUrl,
            model: profile.model,
            isActive: profile.id == settings.activeProfileId,
            swipeToDelete: !wide,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setActiveProfile(profile.id),
            onEdit: () => _openImageEditor(context, profile: profile),
            onDelete: canDelete
                ? () => _deleteProfile(
                    context,
                    name: profile.name,
                    confirm: wide,
                    delete: () => ref
                        .read(settingsProvider.notifier)
                        .deleteProfile(profile.id),
                  )
                : null,
          ),
      ],
    );
  }

  Widget _buildPromptOptimizationSection(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings, {
    required bool wide,
  }) {
    return _ProfileSection(
      icon: Icons.auto_fix_high_rounded,
      title: '提示词优化 API',
      subtitle: '用于首页输入框右侧的提示词优化',
      addLabel: '添加',
      onAdd: () => _openPromptOptimizationEditor(context),
      emptyText: '还没有提示词优化 API。添加后，首页输入框右侧会启用提示词优化。',
      children: [
        for (final profile in settings.promptOptimizationProfiles)
          _ProfileCard(
            key: ValueKey('optimizer-${profile.id}'),
            name: profile.name,
            badge: profile.protocol.label,
            baseUrl: profile.normalizedBaseUrl,
            model: profile.model,
            isActive: profile.id == settings.activePromptOptimizationProfileId,
            swipeToDelete: !wide,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setActivePromptOptimizationProfile(profile.id),
            onEdit: () =>
                _openPromptOptimizationEditor(context, profile: profile),
            onDelete: () => _deleteProfile(
              context,
              name: profile.name,
              confirm: wide,
              delete: () => ref
                  .read(settingsProvider.notifier)
                  .deletePromptOptimizationProfile(profile.id),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestGroup(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) {
    return _SettingsGroup(
      title: '请求',
      children: [
        _SettingsTile(
          icon: Icons.timer_outlined,
          title: '请求超时',
          subtitle: '生成较慢时可以适当调高',
          trailing: _ValuePill(text: '${settings.requestTimeoutSeconds} 秒'),
          onTap: () => _editRequestTimeout(context, ref, settings),
        ),
        _SettingsTile(
          icon: Icons.receipt_long_rounded,
          title: '请求日志',
          subtitle: '查看当前进程记录的请求、响应和错误详情',
          trailing: _supportsDetachedLogWindow
              ? const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: AppThemeTokens.textSecondary,
                )
              : null,
          showChevron: !_supportsDetachedLogWindow,
          onTap: () => _openRequestLogs(context),
        ),
      ],
    );
  }

  Widget _buildBackupGroup(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) {
    final webDavConfig = settings.webDavBackupConfig;
    final webDavConfigured = webDavConfig?.isConfigured ?? false;
    return _SettingsGroup(
      title: '数据备份与恢复',
      children: [
        _SettingsTile(
          icon: Icons.settings_input_component_rounded,
          title: 'WebDAV 设置',
          subtitle: webDavConfigured
              ? webDavConfig!.remoteDirectory
              : '配置后可在多台设备间同步数据',
          trailing: webDavConfigured
              ? const _ValuePill(text: '已配置')
              : const _ValuePill(
                  text: '未配置',
                  color: AppThemeTokens.warningSurface,
                  textColor: AppThemeTokens.warningText,
                ),
          onTap: () => _editWebDavConfig(context, ref, settings),
        ),
        _SettingsTile(
          icon: Icons.cloud_upload_rounded,
          title: '同步到 WebDAV',
          subtitle: '上传设置、历史记录、收藏夹和图片',
          onTap: () => _syncBackupToWebDav(context, ref, settings),
        ),
        _SettingsTile(
          icon: Icons.cloud_download_rounded,
          title: '从 WebDAV 恢复',
          subtitle: '下载最新备份并替换本地数据',
          onTap: () => _restoreBackupFromWebDav(context, ref, settings),
        ),
        _SettingsTile(
          icon: Icons.upload_file_rounded,
          title: '导出到文件',
          subtitle: '保存为 .mintbackup 备份文件',
          onTap: () => _exportBackupToFile(context, ref, settings),
        ),
        _SettingsTile(
          icon: Icons.restore_page_rounded,
          title: '从文件恢复',
          subtitle: '选择 .mintbackup 文件恢复数据',
          onTap: () => _restoreBackupFromFile(context, ref, settings),
        ),
      ],
    );
  }

  Widget _buildAboutGroup(BuildContext context) {
    return _SettingsGroup(
      title: '关于',
      children: [
        const _SettingsTile(
          icon: Icons.sell_outlined,
          title: 'MintImage',
          subtitle: '当前版本',
          trailing: _ValuePill(text: AppVersion.current),
        ),
        _SettingsTile(
          icon: Icons.code_rounded,
          title: '开源地址',
          subtitle: AppVersion.repositoryUrl,
          trailing: const Icon(
            Icons.open_in_new_rounded,
            size: 18,
            color: AppThemeTokens.textSecondary,
          ),
          showChevron: false,
          onTap: () => _openRepository(context),
        ),
      ],
    );
  }

  Future<void> _deleteProfile(
    BuildContext context, {
    required String name,
    required bool confirm,
    required Future<void> Function() delete,
  }) async {
    if (confirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('删除配置'),
            content: Text('确定删除「$name」吗？此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppThemeTokens.dangerText,
                ),
                child: const Text('删除'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) {
        return;
      }
    }
    await delete();
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清除历史记录'),
          content: const Text('这会删除所有生成记录，但不会清除 API 配置。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认清除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref.read(imageListProvider.notifier).clearHistory();
    if (!context.mounted) {
      return;
    }
    _showSnack(context, '历史记录已清空，可在「清理缓存」中释放图片占用的空间。');
  }

  Future<void> _cleanStorage(BuildContext context, WidgetRef ref) async {
    final service = ref.read(storageCleanupServiceProvider);
    final draft = ref.read(attachmentPickerServiceProvider).draftMarkupPath;
    final StorageCleanupPlan? plan;
    try {
      plan = await _runWithProgress<StorageCleanupPlan>(
        context,
        message: '正在统计缓存...',
        task: () => service.scan(keep: {?draft}),
      );
    } catch (error) {
      if (context.mounted) _showSnack(context, '统计缓存失败：$error');
      return;
    }
    if (plan == null || !context.mounted) return;
    if (plan.isEmpty) {
      _showSnack(context, '没有可清理的缓存。');
      return;
    }

    final selected = <StorageCleanupCategory>{
      for (final category in StorageCleanupCategory.values)
        if (category.byDefault && plan.count(category) > 0) category,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final total = selected.fold(
            0,
            (sum, category) => sum + plan!.bytes(category),
          );
          return AlertDialog(
            title: const Text('清理缓存'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final category in StorageCleanupCategory.values)
                    CheckboxListTile(
                      key: ValueKey('storage-cleanup-${category.name}'),
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(category),
                      onChanged: plan!.count(category) == 0
                          ? null
                          : (value) => setState(() {
                              value == true
                                  ? selected.add(category)
                                  : selected.remove(category);
                            }),
                      title: Text(category.label),
                      subtitle: Text(
                        '${category.description}\n'
                        '${plan.count(category)} 个文件 · '
                        '${_formatBytes(plan.bytes(category))}',
                      ),
                      isThreeLine: true,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '历史记录、收藏和 API 配置不受影响；最近 10 分钟内生成的文件会保留。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const Key('storage-cleanup-confirm'),
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: Text('清理 ${_formatBytes(total)}'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await _runWithProgress<StorageCleanupResult>(
      context,
      message: '正在清理...',
      task: () => service.clean(plan!, selected),
    );
    if (result == null || !context.mounted) return;
    _showSnack(
      context,
      '已删除 ${result.deletedFiles} 个文件，释放 ${_formatBytes(result.freedBytes)}'
      '${result.failedFiles > 0 ? '；${result.failedFiles} 个文件正在使用，未能删除' : ''}。',
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _openRepository(BuildContext context) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(AppVersion.repositoryUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      _showSnack(context, '无法打开 GitHub 地址。');
    }
  }

  Future<void> _openImageEditor(
    BuildContext context, {
    ApiProfile? profile,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApiProfileEditPage(profile: profile),
      ),
    );
  }

  Future<void> _openPromptOptimizationEditor(
    BuildContext context, {
    PromptOptimizationProfile? profile,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PromptOptimizationProfileEditPage(profile: profile),
      ),
    );
  }

  Future<void> _editRequestTimeout(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final controller = TextEditingController(
      text: settings.requestTimeoutSeconds.toString(),
    );

    final timeoutSeconds = await showDialog<int>(
      context: context,
      builder: (context) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('请求超时（秒）'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '超时时间',
                      suffixText: '秒',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '默认 600 秒。生成较慢时可以适当调高。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed == null || parsed <= 0) {
                      setState(() {
                        errorText = '请输入大于 0 的整数';
                      });
                      return;
                    }

                    Navigator.of(context).pop(parsed);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (timeoutSeconds == null) {
      return;
    }

    await ref
        .read(settingsProvider.notifier)
        .setRequestTimeoutSeconds(timeoutSeconds);
  }

  Future<void> _exportBackupToFile(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final confirmed = await _confirmSensitiveBackup(context, title: '导出备份');
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final backup = await _runWithProgress<BackupArchiveResult>(
        context,
        message: '正在生成备份...',
        task: () => ref
            .read(backupServiceProvider)
            .createBackupArchive(settings: settings),
      );
      if (backup == null || !context.mounted) {
        return;
      }

      final savedPath = await FilePicker.saveFile(
        dialogTitle: '导出备份',
        fileName: backup.fileName,
        type: FileType.custom,
        allowedExtensions: const ['mintbackup'],
        bytes: await backup.file.readAsBytes(),
        lockParentWindow: true,
      );
      if (savedPath == null || !context.mounted) {
        return;
      }

      _showSnack(context, '备份已导出：${p.basename(savedPath)}');
      await _showBackupWarnings(context, backup.warnings);
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, _errorMessage(error));
      }
    }
  }

  Future<void> _restoreBackupFromFile(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: const ['mintbackup'],
      withData: true,
      lockParentWindow: true,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) {
      return;
    }

    final backupFile = await _fileFromPickedBackup(picked.files.single);
    if (!context.mounted) {
      return;
    }

    final confirmed = await _confirmRestore(context, source: '文件');
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final result = await _runWithProgress<BackupRestoreResult>(
        context,
        message: '正在恢复备份...',
        task: () => ref
            .read(backupServiceProvider)
            .restoreFromArchive(backupFile, currentSettings: settings),
      );
      if (result == null || !context.mounted) {
        return;
      }
      await _applyRestoreResult(context, ref, result);
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, _errorMessage(error));
      }
    }
  }

  Future<void> _editWebDavConfig(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final current = settings.webDavBackupConfig;
    final baseUrlController = TextEditingController(
      text: current?.baseUrl ?? '',
    );
    final usernameController = TextEditingController(
      text: current?.username ?? '',
    );
    final passwordController = TextEditingController(
      text: current?.password ?? '',
    );
    final directoryController = TextEditingController(
      text: current?.remoteDirectory ?? 'MintImage/backups',
    );

    final config = await showDialog<WebDavBackupConfig>(
      context: context,
      builder: (context) {
        String? errorText;
        var statusIsSuccess = false;
        var testing = false;
        var passwordVisible = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('WebDAV 设置'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV 地址',
                        hintText: 'https://example.com:5244/',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: '用户名'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: !passwordVisible,
                      decoration: InputDecoration(
                        labelText: '密码',
                        suffixIcon: IconButton(
                          tooltip: passwordVisible ? '隐藏密码' : '显示密码',
                          onPressed: () => setState(() {
                            passwordVisible = !passwordVisible;
                          }),
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: directoryController,
                      decoration: const InputDecoration(
                        labelText: '远端目录',
                        hintText: 'MintImage/backups',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusIsSuccess
                              ? AppThemeTokens.primaryStrong
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: testing
                      ? null
                      : () async {
                          final baseUrl = baseUrlController.text.trim();
                          final remoteDirectory = directoryController.text
                              .trim();
                          final uri = Uri.tryParse(baseUrl);
                          if (uri == null ||
                              !uri.hasScheme ||
                              uri.host.isEmpty ||
                              remoteDirectory.isEmpty) {
                            setState(() {
                              statusIsSuccess = false;
                              errorText = '请填写有效的 WebDAV 地址和远端目录。';
                            });
                            return;
                          }

                          setState(() {
                            testing = true;
                            statusIsSuccess = false;
                            errorText = '正在测试连接...';
                          });
                          try {
                            await ref
                                .read(webDavBackupServiceProvider)
                                .testConnection(
                                  WebDavBackupConfig(
                                    baseUrl: baseUrl,
                                    username: usernameController.text.trim(),
                                    password: passwordController.text,
                                    remoteDirectory: remoteDirectory,
                                  ),
                                );
                            if (!context.mounted) {
                              return;
                            }
                            setState(() {
                              testing = false;
                              statusIsSuccess = true;
                              errorText = '连接成功。';
                            });
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            setState(() {
                              testing = false;
                              statusIsSuccess = false;
                              errorText = _errorMessage(error);
                            });
                          }
                        },
                  child: Text(testing ? '测试中...' : '测试连接'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: testing
                      ? null
                      : () {
                          final baseUrl = baseUrlController.text.trim();
                          final remoteDirectory = directoryController.text
                              .trim();
                          final uri = Uri.tryParse(baseUrl);
                          if (uri == null ||
                              !uri.hasScheme ||
                              uri.host.isEmpty ||
                              remoteDirectory.isEmpty) {
                            setState(() {
                              statusIsSuccess = false;
                              errorText = '请填写有效的 WebDAV 地址和远端目录。';
                            });
                            return;
                          }

                          Navigator.of(context).pop(
                            WebDavBackupConfig(
                              baseUrl: baseUrl,
                              username: usernameController.text.trim(),
                              password: passwordController.text,
                              remoteDirectory: remoteDirectory,
                            ),
                          );
                        },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    baseUrlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    directoryController.dispose();

    if (config == null) {
      return;
    }
    await ref.read(settingsProvider.notifier).setWebDavBackupConfig(config);
  }

  Future<void> _syncBackupToWebDav(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final config = settings.webDavBackupConfig;
    if (config == null || !config.isConfigured) {
      _showSnack(context, '请先配置 WebDAV。');
      await _editWebDavConfig(context, ref, settings);
      return;
    }

    final confirmed = await _confirmSensitiveBackup(
      context,
      title: '同步到 WebDAV',
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    var warnings = const <String>[];
    try {
      await _runWithProgress<void>(
        context,
        message: '正在同步到 WebDAV...',
        task: () async {
          final backup = await ref
              .read(backupServiceProvider)
              .createBackupArchive(settings: settings);
          warnings = backup.warnings;
          await ref
              .read(webDavBackupServiceProvider)
              .uploadLatestBackup(backup.file, config);
        },
      );
      if (!context.mounted) {
        return;
      }
      _showSnack(context, '已同步到 WebDAV。');
      await _showBackupWarnings(context, warnings);
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, _errorMessage(error));
      }
    }
  }

  Future<void> _restoreBackupFromWebDav(
    BuildContext context,
    WidgetRef ref,
    SettingsModel settings,
  ) async {
    final config = settings.webDavBackupConfig;
    if (config == null || !config.isConfigured) {
      _showSnack(context, '请先配置 WebDAV。');
      await _editWebDavConfig(context, ref, settings);
      return;
    }

    final confirmed = await _confirmRestore(context, source: 'WebDAV');
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final result = await _runWithProgress<BackupRestoreResult>(
        context,
        message: '正在从 WebDAV 恢复...',
        task: () async {
          final tempDirectory = await getTemporaryDirectory();
          final backupFile = await ref
              .read(webDavBackupServiceProvider)
              .downloadLatestBackup(config, tempDirectory);
          return ref
              .read(backupServiceProvider)
              .restoreFromArchive(backupFile, currentSettings: settings);
        },
      );
      if (result == null || !context.mounted) {
        return;
      }
      await _applyRestoreResult(context, ref, result);
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, _errorMessage(error));
      }
    }
  }

  Future<File> _fileFromPickedBackup(PlatformFile picked) async {
    final path = picked.path;
    if (path != null) {
      return File(path);
    }

    final bytes = picked.bytes;
    if (bytes == null) {
      throw const BackupException('无法读取备份文件。');
    }

    final tempDirectory = await getTemporaryDirectory();
    final file = File(p.join(tempDirectory.path, picked.name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _applyRestoreResult(
    BuildContext context,
    WidgetRef ref,
    BackupRestoreResult result,
  ) async {
    await ref.read(settingsProvider.notifier).replaceWith(result.settings);
    await ref.read(imageListProvider.notifier).reload();
    await ref.read(favoriteFoldersProvider.notifier).reload();
    if (!context.mounted) {
      return;
    }

    _showSnack(context, '恢复完成。安全快照：${p.basename(result.safetyBackup.path)}');
    await _showBackupWarnings(context, result.warnings);
  }

  Future<bool?> _confirmSensitiveBackup(
    BuildContext context, {
    required String title,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: const Text(
            '备份会包含 API Key、WebDAV 密码等敏感配置。当前版本不会加密备份文件，请确认只保存到可信位置。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmRestore(
    BuildContext context, {
    required String source,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('从$source恢复'),
          content: const Text('恢复会替换当前设置、历史记录、收藏夹和应用内图片文件。恢复前会自动生成一份安全快照。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认恢复'),
            ),
          ],
        );
      },
    );
  }

  Future<T?> _runWithProgress<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() task,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      },
    );

    try {
      return await task();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _showBackupWarnings(
    BuildContext context,
    List<String> warnings,
  ) async {
    if (warnings.isEmpty || !context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('备份提示（${warnings.length}）'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Text(warnings.take(20).join('\n')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is BackupException) {
      return error.message;
    }
    if (error is WebDavBackupException) {
      return error.message;
    }
    return '操作失败：$error';
  }

  Future<void> _openRequestLogs(BuildContext context) async {
    if (_supportsDetachedLogWindow) {
      try {
        await Process.start(Platform.resolvedExecutable, const [
          '--log-window',
        ], mode: ProcessStartMode.detached);
        return;
      } catch (_) {
        // Fall back to in-app viewing when detached launch fails.
      }
    }

    if (!context.mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RequestLogPage()));
  }

  bool get _supportsDetachedLogWindow =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppThemeTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppThemeTokens.primaryStrong),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: AppThemeTokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.addLabel,
    required this.onAdd,
    required this.emptyText,
    required this.children,
  });

  static const _twoColumnMinWidth = 600.0;
  static const _spacing = 12.0;

  final IconData icon;
  final String title;
  final String subtitle;
  final String addLabel;
  final VoidCallback onAdd;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: children.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(addLabel),
                ),
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          _EmptyConfigHint(
            text: emptyText,
            actionLabel: addLabel,
            onAction: onAdd,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= _twoColumnMinWidth
                  ? 2
                  : 1;
              final itemWidth =
                  ((constraints.maxWidth - _spacing * (columns - 1)) / columns)
                      .floorToDouble();
              return Wrap(
                spacing: _spacing,
                runSpacing: _spacing,
                children: [
                  for (final child in children)
                    SizedBox(width: itemWidth, child: child),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _EmptyConfigHint extends StatelessWidget {
  const _EmptyConfigHint({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppThemeTokens.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeTokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    super.key,
    required this.name,
    required this.badge,
    required this.baseUrl,
    required this.model,
    required this.isActive,
    required this.swipeToDelete,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  final String name;
  final String badge;
  final String baseUrl;
  final String model;
  final bool isActive;
  final bool swipeToDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: AppDecorations.softShadow,
      ),
      child: Material(
        color: isActive ? AppThemeTokens.surfaceSoft : AppThemeTokens.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(
            color: isActive ? AppThemeTokens.primary : AppThemeTokens.border,
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    isActive
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isActive
                        ? AppThemeTokens.primary
                        : AppThemeTokens.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppThemeTokens.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  const _ValuePill(
                                    text: '使用中',
                                    color: AppThemeTokens.primary,
                                    textColor: Colors.white,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _CardIconButton(
                            tooltip: '编辑',
                            icon: Icons.edit_rounded,
                            onPressed: onEdit,
                          ),
                          if (!swipeToDelete && onDelete != null) ...[
                            const SizedBox(width: 2),
                            _CardIconButton(
                              tooltip: '删除',
                              icon: Icons.delete_outline_rounded,
                              color: AppThemeTokens.dangerText,
                              onPressed: onDelete!,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: _ValuePill(
                              text: badge,
                              color: isActive
                                  ? Colors.white
                                  : AppThemeTokens.surfaceMuted,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              baseUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppThemeTokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '模型：$model',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );

    if (!swipeToDelete || onDelete == null) {
      return card;
    }

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete!(),
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: '删除',
            borderRadius: BorderRadius.circular(_radius),
          ),
        ],
      ),
      child: card,
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = AppThemeTokens.primaryStrong,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(foregroundColor: color),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  static const _radius = 20.0;

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppThemeTokens.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: AppDecorations.softShadow,
          ),
          child: Material(
            color: AppThemeTokens.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
              side: const BorderSide(color: AppThemeTokens.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 62),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = destructive
        ? AppThemeTokens.dangerText
        : AppThemeTokens.primaryStrong;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: destructive
                    ? AppThemeTokens.dangerSurface
                    : AppThemeTokens.surfaceSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: destructive
                          ? AppThemeTokens.dangerText
                          : AppThemeTokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && showChevron) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppThemeTokens.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.text,
    this.color = AppThemeTokens.surfaceMuted,
    this.textColor = AppThemeTokens.primaryStrong,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
