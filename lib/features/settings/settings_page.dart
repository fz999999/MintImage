import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/favorite_folders_provider.dart';
import '../../core/providers/image_list_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/webdav_backup_service.dart';
import '../../core/version/app_version.dart';
import '../../shared/theme.dart';
import 'api_profile_edit_page.dart';
import 'prompt_optimization_profile_edit_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 请求超时允许的最小秒数。
  static const int _minTimeoutSeconds = 5;

  /// 请求超时允许的最大秒数。
  static const int _maxTimeoutSeconds = 3600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final b = Theme.of(context).brightness;
    // 「至少保留 1 个配置」的保护：只剩 1 个时禁用删除按钮。
    final canDeleteImageProfile = settings.profiles.length > 1;
    final canDeleteOptimizationProfile =
        settings.promptOptimizationProfiles.length > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.canvas(b), AppColors.canvasTint(b)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.sm,
            AppSpace.sm,
            AppSpace.xl,
          ),
          children: [
            const _AppInfoCard(),
            const SizedBox(height: AppSpace.sm),
            _RequestTimeoutCard(
              timeoutSeconds: settings.requestTimeoutSeconds,
              minSeconds: _minTimeoutSeconds,
              maxSeconds: _maxTimeoutSeconds,
              onSave: (seconds) => ref
                  .read(settingsProvider.notifier)
                  .setRequestTimeoutSeconds(seconds),
            ),
            const SizedBox(height: AppSpace.sm),
            _DataBackupCard(
              webDavConfig: settings.webDavBackupConfig,
              onExportToFile: () => _exportBackupToFile(context, ref, settings),
              onRestoreFromFile: () =>
                  _restoreBackupFromFile(context, ref, settings),
              onEditWebDav: () => _editWebDavConfig(context, ref, settings),
              onSyncToWebDav: () => _syncBackupToWebDav(context, ref, settings),
              onRestoreFromWebDav: () =>
                  _restoreBackupFromWebDav(context, ref, settings),
            ),
            const SizedBox(height: AppSpace.md),
            _SectionTitle(
              icon: Icon(
                Icons.auto_awesome_motion_rounded,
                size: AppIconSize.sm,
                color: AppColors.primaryStrong(b),
              ),
              title: '生图API',
            ),
            const SizedBox(height: AppSpace.xs),
            for (final profile in settings.profiles)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: _ImageProfileCard(
                  profile: profile,
                  isActive: profile.id == settings.activeProfileId,
                  canDelete: canDeleteImageProfile,
                  onTap: () async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setActiveProfile(profile.id);
                  },
                  onEdit: () => _openImageEditor(context, profile: profile),
                  onDelete: () async {
                    final confirmed = await _confirmDeleteConfig(
                      context,
                      kind: '生图 API',
                      name: profile.name,
                    );
                    if (confirmed != true) {
                      return;
                    }
                    await ref
                        .read(settingsProvider.notifier)
                        .deleteProfile(profile.id);
                  },
                ),
              ),
            _AddConfigButton(
              icon: const Icon(Icons.add_rounded, size: AppIconSize.sm),
              label: '添加生图 API',
              onTap: () => _openImageEditor(context),
            ),
            const SizedBox(height: AppSpace.md),
            const Divider(),
            const SizedBox(height: AppSpace.sm),
            _SectionTitle(
              icon: Icon(
                Icons.auto_fix_high_rounded,
                size: AppIconSize.sm,
                color: AppColors.primaryStrong(b),
              ),
              title: '提示词优化API',
            ),
            const SizedBox(height: AppSpace.xs),
            if (settings.promptOptimizationProfiles.isEmpty) ...[
              _EmptyConfigHint(text: '还没有提示词优化 API。添加后，首页输入框右侧会启用提示词优化。'),
              const SizedBox(height: AppSpace.xs),
            ],
            for (final profile in settings.promptOptimizationProfiles)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: _PromptOptimizationProfileCard(
                  profile: profile,
                  isActive:
                      profile.id == settings.activePromptOptimizationProfileId,
                  canDelete: canDeleteOptimizationProfile,
                  onTap: () async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setActivePromptOptimizationProfile(profile.id);
                  },
                  onEdit: () => _openPromptOptimizationEditor(
                    context,
                    profile: profile,
                  ),
                  onDelete: () async {
                    final confirmed = await _confirmDeleteConfig(
                      context,
                      kind: '提示词优化 API',
                      name: profile.name,
                    );
                    if (confirmed != true) {
                      return;
                    }
                    await ref
                        .read(settingsProvider.notifier)
                        .deletePromptOptimizationProfile(profile.id);
                  },
                ),
              ),
            _AddConfigButton(
              icon: const Icon(Icons.add_rounded, size: AppIconSize.sm),
              label: '添加提示词优化 API',
              onTap: () => _openPromptOptimizationEditor(context),
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton.tonalIcon(
              onPressed: () async {
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('历史记录已清空。')));
              },
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('清除历史记录'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dangerSurface(b),
                foregroundColor: AppColors.dangerText(b),
              ),
            ),
          ],
        ),
      ),
    );
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

  /// 删除配置前的二次确认。返回 true 表示用户确认删除。
  Future<bool?> _confirmDeleteConfig(
    BuildContext context, {
    required String kind,
    required String name,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final b = Theme.of(context).brightness;
        return AlertDialog(
          title: const Text('删除配置'),
          content: Text('删除$kind「$name」？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dangerSurface(b),
                foregroundColor: AppColors.dangerText(b),
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
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
            final b = Theme.of(context).brightness;
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
                              ? AppColors.primaryStrong(b)
                              : AppColors.dangerText(b),
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
}

/// 卡片左侧的方角图标底。
class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft(b),
        borderRadius: AppRadius.smAll,
      ),
      child: child,
    );
  }
}

/// 卡片右上角的小圆角图标按钮（32×32，hover 底色 `surfaceMuted`）。
///
/// 图标由调用方以 `const Icon(Icons.xxx)` 内联传入，避免 release 图标被裁掉。
class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final enabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.xsAll,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: AppRadius.xsAll,
            hoverColor: Colors.transparent,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered && enabled
                    ? AppColors.surfaceMuted(b)
                    : Colors.transparent,
                borderRadius: AppRadius.xsAll,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 配置卡右上角的编辑 / 删除按钮组。
class _ConfigActions extends StatelessWidget {
  const _ConfigActions({
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoverIconButton(
          tooltip: '编辑',
          onPressed: onEdit,
          child: Icon(
            Icons.edit_outlined,
            size: AppIconSize.sm,
            color: AppColors.primaryStrong(b),
          ),
        ),
        const SizedBox(width: AppSpace.xxs),
        _HoverIconButton(
          tooltip: canDelete ? '删除' : '至少保留 1 个配置',
          onPressed: canDelete ? onDelete : null,
          child: Icon(
            Icons.delete_outline,
            size: AppIconSize.sm,
            color: canDelete
                ? AppColors.dangerText(b)
                : AppColors.textTertiary(b),
          ),
        ),
      ],
    );
  }
}

/// 「使用中」徽章。
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs + 2,
        vertical: AppSpace.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(b),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: AppColors.border(b)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: AppIconSize.xs + 2,
            color: AppColors.primary(b),
          ),
          const SizedBox(width: AppSpace.xxs + 2),
          Text('使用中', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// 协议 / 模式的小胶囊。
class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs - 1,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(b),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primaryStrong(b),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

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
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft(b),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(Icons.info_outline_rounded),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  '关于 大川生图工具',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          _InfoRow(
            icon: Icon(
              Icons.sell_outlined,
              size: AppIconSize.sm,
              color: AppColors.primaryStrong(b),
            ),
            label: '版本',
            value: AppVersion.current,
          ),
          const SizedBox(height: AppSpace.xs),
          _InfoRow(
            icon: Icon(
              Icons.code_rounded,
              size: AppIconSize.sm,
              color: AppColors.primaryStrong(b),
            ),
            label: '开源地址',
            value: AppVersion.repositoryUrl,
            onTap: () => _openRepository(context),
          ),
        ],
      ),
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub 地址。')));
    }
  }
}

class _DataBackupCard extends StatelessWidget {
  const _DataBackupCard({
    required this.webDavConfig,
    required this.onExportToFile,
    required this.onRestoreFromFile,
    required this.onEditWebDav,
    required this.onSyncToWebDav,
    required this.onRestoreFromWebDav,
  });

  final WebDavBackupConfig? webDavConfig;
  final VoidCallback onExportToFile;
  final VoidCallback onRestoreFromFile;
  final VoidCallback onEditWebDav;
  final VoidCallback onSyncToWebDav;
  final VoidCallback onRestoreFromWebDav;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final configured = webDavConfig?.isConfigured ?? false;
    final status = configured ? webDavConfig!.remoteDirectory : '未配置';

    return Container(
      decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CardIcon(
                child: Icon(Icons.cloud_sync_rounded, size: AppIconSize.md),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '数据备份与恢复',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'WebDAV：$status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          // 本地备份：导出 / 从文件恢复。
          _BackupGroup(
            title: '本地',
            actions: [
              _BackupActionButton(
                icon: const Icon(
                  Icons.upload_file_rounded,
                  size: AppIconSize.sm,
                ),
                label: '导出本地备份（.mintbackup）',
                onPressed: onExportToFile,
              ),
              _BackupActionButton(
                icon: const Icon(
                  Icons.restore_page_rounded,
                  size: AppIconSize.sm,
                ),
                label: '从文件恢复',
                onPressed: onRestoreFromFile,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          // 云端备份：WebDAV 设置 / 同步 / 恢复。
          _BackupGroup(
            title: '云端（WebDAV）',
            actions: [
              _BackupActionButton(
                icon: const Icon(
                  Icons.settings_input_component_rounded,
                  size: AppIconSize.sm,
                ),
                label: 'WebDAV 设置',
                onPressed: onEditWebDav,
              ),
              _BackupActionButton(
                icon: const Icon(
                  Icons.cloud_upload_rounded,
                  size: AppIconSize.sm,
                ),
                label: '同步到 WebDAV',
                onPressed: onSyncToWebDav,
              ),
              _BackupActionButton(
                icon: const Icon(
                  Icons.cloud_download_rounded,
                  size: AppIconSize.sm,
                ),
                label: '从 WebDAV 恢复',
                onPressed: onRestoreFromWebDav,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 备份动作分组：组标题 + 一行可换行的按钮。
class _BackupGroup extends StatelessWidget {
  const _BackupGroup({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: AppFontSize.label,
            color: AppColors.textTertiary(b),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: actions,
        ),
      ],
    );
  }
}

class _BackupActionButton extends StatelessWidget {
  const _BackupActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final Widget icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final content = Row(
      children: [
        icon,
        const SizedBox(width: AppSpace.xs + 2),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary(b),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onTap == null
                  ? AppColors.textPrimary(b)
                  : AppColors.primaryStrong(b),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: AppSpace.xs),
          Icon(
            Icons.open_in_new_rounded,
            size: AppIconSize.sm,
            color: AppColors.primaryStrong(b),
          ),
        ],
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final Widget icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      children: [
        icon,
        const SizedBox(width: AppSpace.xs),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textPrimary(b),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _AddConfigButton extends StatelessWidget {
  const _AddConfigButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft(b),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.border(b)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: AppSpace.xs - 2),
            Text(
              label,
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
}

class _EmptyConfigHint extends StatelessWidget {
  const _EmptyConfigHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft(b),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border(b)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary(b),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ImageProfileCard extends StatelessWidget {
  const _ImageProfileCard({
    required this.profile,
    required this.isActive,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ApiProfile profile;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final tint = isActive ? AppColors.surfaceSoft(b) : AppColors.surface(b);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          decoration: AppDecorations.card(
            brightness: b,
            radius: AppRadius.md,
            color: tint,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.xs,
            AppSpace.xs,
            AppSpace.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(b),
                      ),
                    ),
                  ),
                  if (isActive) const _ActiveBadge(),
                  const SizedBox(width: AppSpace.xs),
                  _ConfigActions(
                    canDelete: canDelete,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxs),
              Row(
                children: [
                  _MetaPill(label: profile.apiMode.shortLabel),
                  const SizedBox(width: AppSpace.xs - 1),
                  Expanded(
                    child: Text(
                      profile.normalizedBaseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary(b),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                profile.models.length > 1
                    ? '模型：${profile.model} 等 ${profile.models.length} 个模型'
                    : '模型：${profile.model}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptOptimizationProfileCard extends StatelessWidget {
  const _PromptOptimizationProfileCard({
    required this.profile,
    required this.isActive,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final PromptOptimizationProfile profile;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final tint = isActive ? AppColors.surfaceSoft(b) : AppColors.surface(b);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          decoration: AppDecorations.card(
            brightness: b,
            radius: AppRadius.md,
            color: tint,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.xs,
            AppSpace.xs,
            AppSpace.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(b),
                      ),
                    ),
                  ),
                  if (isActive) const _ActiveBadge(),
                  const SizedBox(width: AppSpace.xs),
                  _ConfigActions(
                    canDelete: canDelete,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxs),
              Row(
                children: [
                  _MetaPill(label: profile.protocol.label),
                  const SizedBox(width: AppSpace.xs - 1),
                  Expanded(
                    child: Text(
                      profile.normalizedBaseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(b),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '模型：${profile.model}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 请求超时：卡片内行内输入 + 保存。
class _RequestTimeoutCard extends StatefulWidget {
  const _RequestTimeoutCard({
    required this.timeoutSeconds,
    required this.minSeconds,
    required this.maxSeconds,
    required this.onSave,
  });

  final int timeoutSeconds;
  final int minSeconds;
  final int maxSeconds;
  final ValueChanged<int> onSave;

  @override
  State<_RequestTimeoutCard> createState() => _RequestTimeoutCardState();
}

class _RequestTimeoutCardState extends State<_RequestTimeoutCard> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.timeoutSeconds}');
  }

  @override
  void didUpdateWidget(covariant _RequestTimeoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化（比如从备份恢复）时同步输入框，但不打断正在编辑的用户。
    if (!_focusNode.hasFocus &&
        widget.timeoutSeconds != oldWidget.timeoutSeconds) {
      _controller.text = '${widget.timeoutSeconds}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          const _CardIcon(child: Icon(Icons.timer_outlined, size: AppIconSize.md)),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '请求超时',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '默认 600 秒，可填 ${widget.minSeconds}–${widget.maxSeconds} 秒',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(b),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.end,
              onSubmitted: (_) => _handleSave(),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 's',
                hintText: '600',
              ),
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          FilledButton(onPressed: _handleSave, child: const Text('保存')),
        ],
      ),
    );
  }

  void _handleSave() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = '${widget.timeoutSeconds}';
      _showMessage('请输入整数秒数，已恢复为 ${widget.timeoutSeconds} 秒。');
      return;
    }

    final clamped = parsed < widget.minSeconds
        ? widget.minSeconds
        : (parsed > widget.maxSeconds ? widget.maxSeconds : parsed);

    _controller.text = '$clamped';
    _focusNode.unfocus();

    if (clamped != parsed) {
      _showMessage(
        '请求超时需在 ${widget.minSeconds}–${widget.maxSeconds} 秒之间，已按 $clamped 秒保存。',
      );
    } else if (clamped == widget.timeoutSeconds) {
      _showMessage('请求超时保持 $clamped 秒。');
    } else {
      _showMessage('请求超时已保存：$clamped 秒。');
    }

    widget.onSave(clamped);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
