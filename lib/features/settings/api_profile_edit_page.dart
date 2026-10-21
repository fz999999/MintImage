import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/openai_client.dart';
import '../../core/models/balance_query.dart';
import '../../core/models/settings_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/desktop/desktop_dialog.dart';
import 'balance_query_settings_card.dart';
import 'settings_content_width.dart';

class ApiProfileEditPage extends ConsumerStatefulWidget {
  const ApiProfileEditPage({super.key, this.profile});

  final ApiProfile? profile;

  @override
  ConsumerState<ApiProfileEditPage> createState() => _ApiProfileEditPageState();
}

class _ApiProfileEditPageState extends ConsumerState<ApiProfileEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelInputController = TextEditingController();
  bool _obscureApiKey = true;
  bool _fetchingModels = false;
  bool _useStreaming = false;
  CancelToken? _modelListCancelToken;
  List<String> _modelOptions = const [];
  List<String> _models = const [];
  late ImageGenerationApiMode _apiMode;
  late BalanceQueryConfig _balanceQuery;

  ApiProfile? get _editingProfile => widget.profile;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final profile = _editingProfile;

    _nameController.text =
        profile?.name ?? '配置 ${settings.profiles.length + 1}';
    _apiMode = profile?.apiMode ?? ImageGenerationApiMode.images;
    _useStreaming = profile?.useStreaming ?? false;
    _balanceQuery = profile?.balanceQuery ?? const BalanceQueryConfig();
    _baseUrlController.text = profile?.baseUrl ?? 'https://api.openai.com';
    _apiKeyController.text = profile?.apiKey ?? '';
    _models = List<String>.from(
      profile?.models ?? [profile?.model ?? _apiMode.defaultModel],
    );

    _nameController.addListener(_refresh);
    _baseUrlController.addListener(_refresh);
    _modelInputController.addListener(_refresh);
  }

  @override
  void dispose() {
    _modelListCancelToken?.cancel();
    _nameController.removeListener(_refresh);
    _baseUrlController.removeListener(_refresh);
    _modelInputController.removeListener(_refresh);
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final previewBaseUrl = _baseUrlController.text.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final finalUrl = previewBaseUrl.isEmpty
        ? 'https://example.com${_apiMode.generationPath}'
        : '$previewBaseUrl${_apiMode.generationPath}';

    return Scaffold(
      appBar: AppBar(title: Text(_editingProfile == null ? '添加服务商' : '编辑服务商')),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.surface(b),
          border: Border(top: BorderSide(color: AppColors.border(b)))),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
          children: [SettingsContentWidth(
          child: LayoutBuilder(builder: (context, constraints) {
            final actions = Wrap(spacing: AppSpace.sm, children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(88, 44)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                onPressed: _save,
                child: Text(_editingProfile == null ? '添加并使用' : '保存修改')),
            ]);
            final hint = Text(_editingProfile == null
                ? '添加后自动设为当前服务商' : '保存后在主页切换服务商和模型',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(b)));
            if (constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) < 560) {
              return Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [hint, const SizedBox(height: AppSpace.xs), actions]);
            }
            return Row(children: [Expanded(child: hint), actions]);
          }),
        )])),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.canvas(b), AppColors.canvasTint(b)],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              Container(
                decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('连接信息', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpace.xxs),
                    Text('填写服务商提供的地址和密钥。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(b))),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      controller: _nameController,
                      decoration: _fieldDecoration('服务商名称', hint: '例如：Aihub、万川'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: _fieldDecoration('API 地址（Base URL）',
                        hint: 'https://api.example.com'),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入 Base URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: _fieldDecoration('API Key', hint: '粘贴服务商提供的密钥').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscureApiKey ? '显示密钥' : '隐藏密钥',
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                          icon: _obscureApiKey
                              ? const Icon(Icons.visibility_rounded)
                              : const Icon(Icons.visibility_off_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ImageGenerationApiMode>(
                      initialValue: _apiMode,
                      isExpanded: true,
                      isDense: true,
                      itemHeight: 48,
                      menuMaxHeight: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? 280 : null,
                      decoration: _fieldDecoration('接口类型'),
                      items: [
                        for (final mode in ImageGenerationApiMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(mode.label),
                          ),
                      ],
                      onChanged: (mode) {
                        if (mode == null) {
                          return;
                        }
                        setState(() {
                          final previousMode = _apiMode;
                          _apiMode = mode;
                          if (_models.length == 1 &&
                              _models.first == previousMode.defaultModel) {
                            _models = <String>[mode.defaultModel];
                          }
                          _modelOptions = const [];
                        });
                      },
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft(b),
                        borderRadius: AppRadius.smAll),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('请求地址预览',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary(b))),
                          const SizedBox(height: AppSpace.xxs),
                          SelectableText(finalUrl,
                            style: Theme.of(context).textTheme.bodySmall),
                        ]),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('流式请求'),
                        subtitle: const Text(
                          '服务商支持时开启，可降低长时间生成的超时风险。',
                        ),
                        value: _useStreaming,
                        onChanged: (v) => setState(() => _useStreaming = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Container(
                decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('模型管理', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpace.xxs),
                    Text('从服务商获取，或手动添加模型名称。保存后可在主页切换。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(b))),
                    const SizedBox(height: AppSpace.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _fetchingModels ? null : _fetchModels,
                      icon: _fetchingModels
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_download_rounded, size: 18),
                      label: Text(_fetchingModels ? '获取中…' : '获取模型列表')),
                    const SizedBox(height: AppSpace.md),
                    Text('已添加 ${_models.length} 个 · 至少保留一个',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary(b))),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final model in _models)
                          InputChip(
                            label: Text(model),
                            onDeleted: () => _removeModel(model),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _modelInputController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addModelFromInput(),
                            decoration: _fieldDecoration('手动添加模型',
                              hint: '输入完整模型名，按 Enter 添加'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: _modelInputController.text.trim().isEmpty
                              ? null : _addModelFromInput,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),

                  ],
                ),
              ),

              const SizedBox(height: AppSpace.md),
              BalanceQuerySettingsCard(
                config: _balanceQuery,
                baseUrlController: _baseUrlController,
                apiKeyController: _apiKeyController,
                onChanged: (config) => setState(() => _balanceQuery = config),
              ),

            ].map((child) => SettingsContentWidth(child: child)).toList(),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_models.isEmpty) {
      _showMessage('请至少添加一个模型。');
      return;
    }

    final notifier = ref.read(settingsProvider.notifier);
    final existing = _editingProfile;

    if (existing == null) {
      final created = await notifier.addProfile(
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        models: _models,
        apiMode: _apiMode,
        useStreaming: _useStreaming,
        balanceQuery: _balanceQuery,
      );
      await notifier.setActiveProfile(created.id);
    } else {
      await notifier.updateProfile(
        existing.copyWith(
          name: _nameController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          models: _models,
          apiMode: _apiMode,
          useStreaming: _useStreaming,
          balanceQuery: _balanceQuery,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _fetchModels() async {
    if (_fetchingModels) {
      return;
    }

    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (baseUrl.isEmpty) {
      _showMessage('请输入 Base URL 后再获取模型列表。');
      return;
    }
    if (apiKey.isEmpty) {
      _showMessage('请输入 API Key 后再获取模型列表。');
      return;
    }

    final cancelToken = CancelToken();
    _modelListCancelToken = cancelToken;
    setState(() {
      _fetchingModels = true;
    });

    try {
      final models = await ref
          .read(modelListApiProvider)
          .fetchImageGenerationModels(
            profile: ApiProfile(
              id: _editingProfile?.id ?? 'model-list-preview',
              name: _nameController.text.trim().isEmpty
                  ? '配置'
                  : _nameController.text.trim(),
              baseUrl: baseUrl,
              apiKey: apiKey,
              models: _models,
              apiMode: _apiMode,
            ),
            timeoutSeconds: ref.read(settingsProvider).requestTimeoutSeconds,
            cancelToken: cancelToken,
          );
      if (!mounted || cancelToken.isCancelled) {
        return;
      }

      setState(() {
        _modelOptions = models;
        _fetchingModels = false;
        _modelListCancelToken = null;
      });
      _showMessage('已获取 ${models.length} 个模型。');
      await _openModelPicker();
    } on ApiException catch (error) {
      if (mounted && !cancelToken.isCancelled) {
        _showMessage('获取模型列表失败：${error.message}');
      }
    } catch (error) {
      if (mounted && !cancelToken.isCancelled) {
        _showMessage('获取模型列表失败：$error');
      }
    } finally {
      if (mounted && identical(_modelListCancelToken, cancelToken)) {
        setState(() {
          _fetchingModels = false;
          _modelListCancelToken = null;
        });
      }
    }
  }

  void _addModelFromInput() {
    final value = _modelInputController.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (_models.contains(value)) {
      _modelInputController.clear();
      _showMessage('模型 $value 已在列表中。');
      return;
    }

    setState(() {
      _models = [..._models, value];
    });
    _modelInputController.clear();
  }

  void _removeModel(String model) {
    if (_models.length <= 1) {
      _showMessage('至少保留一个模型');
      return;
    }

    setState(() {
      _models = [
        for (final item in _models)
          if (item != model) item,
      ];
    });
  }

  Future<void> _openModelPicker() async {
    if (_modelOptions.isEmpty) {
      _showMessage('请先获取模型列表。');
      return;
    }

    final selected = <String>{..._models};
    final windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    var query = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final content = SizedBox(
                height: windows ? (MediaQuery.sizeOf(context).height * 0.5).clamp(160.0, 360.0).toDouble() : null,
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (windows) ...[
                      Align(alignment: Alignment.centerLeft,
                        child: Text('已选 ${selected.length} 个 · 已有 ${_models.length} 个锁定')),
                      if (_modelOptions.length > 8) ...[
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: '搜索模型', prefixIcon: Icon(Icons.search_rounded)),
                          onChanged: (value) => setDialogState(() => query = value.trim().toLowerCase()),
                        ),
                      ],
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setDialogState(() {
                            selected.addAll(_modelOptions);
                          });
                        },
                        child: const Text('全选'),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (windows && !_modelOptions.any((model) => model.toLowerCase().contains(query)))
                            const Padding(padding: EdgeInsets.all(16), child: Text('没有匹配的模型')),
                          for (final model in _modelOptions.where(
                              (model) => model.toLowerCase().contains(query)))
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              value: selected.contains(model),
                              title: Text(model),
                              secondary: windows && _models.contains(model)
                                  ? const Icon(Icons.lock_outline_rounded, size: 16) : null,
                              onChanged: _models.contains(model)
                                  ? null
                                  : (checked) {
                                      setDialogState(() {
                                        if (checked ?? false) {
                                          selected.add(model);
                                        } else {
                                          selected.remove(model);
                                        }
                                      });
                                    },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            final cancel = TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            );
            final confirm = FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            );
            if (windows) {
              return DesktopDialog(title: '选择模型', width: 560,
                content: content, actions: [confirm, cancel]);
            }
            return AlertDialog(title: const Text('选择模型'),
              content: content, actions: [cancel, confirm]);
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _models = [
        ..._models,
        for (final model in selected)
          if (!_models.contains(model)) model,
      ];
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showMessage(String message) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows &&
        (message.contains('失败') || message.startsWith('请输入') ||
         message.startsWith('请至少') || message.startsWith('至少保留'))) {
      showDesktopInfo(context: context, title: '提示', text: message);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
