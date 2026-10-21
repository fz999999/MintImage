import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/balance_query_api.dart';
import '../../core/models/balance_query.dart';
import '../../core/models/settings_model.dart';
import '../../core/providers/balance_provider.dart';
import '../../shared/theme.dart';

/// 「中转站 API 设置」里的余额查询卡片。
///
/// 负责收集查询余额需要的东西：开关、查询方式、账户访问令牌，
/// 以及自定义接口的地址/字段路径/换算倍数；改动即时回调给编辑页保存。
class BalanceQuerySettingsCard extends ConsumerStatefulWidget {
  const BalanceQuerySettingsCard({
    super.key,
    required this.config,
    required this.baseUrlController,
    required this.apiKeyController,
    required this.onChanged,
  });

  final BalanceQueryConfig config;
  final TextEditingController baseUrlController;
  final TextEditingController apiKeyController;
  final ValueChanged<BalanceQueryConfig> onChanged;

  @override
  ConsumerState<BalanceQuerySettingsCard> createState() =>
      _BalanceQuerySettingsCardState();
}

class _BalanceQuerySettingsCardState
    extends ConsumerState<BalanceQuerySettingsCard> {
  late final TextEditingController _accessTokenController;
  late final TextEditingController _customUrlController;
  late final TextEditingController _customPathController;
  late final TextEditingController _customDivisorController;
  late final TextEditingController _customPrefixController;

  late bool _enabled;
  late BalanceQueryMode _mode;
  bool _obscureToken = true;
  bool _testing = false;
  String? _testText;
  String? _testDetail;
  bool _testFailed = false;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _enabled = config.enabled;
    _mode = config.mode;
    _accessTokenController = TextEditingController(text: config.accessToken);
    _customUrlController = TextEditingController(text: config.customUrl);
    _customPathController = TextEditingController(text: config.customPath);
    _customDivisorController = TextEditingController(
      text: _trimNumber(config.customDivisor),
    );
    _customPrefixController = TextEditingController(text: config.customPrefix);
    for (final controller in [
      _accessTokenController,
      _customUrlController,
      _customPathController,
      _customDivisorController,
      _customPrefixController,
    ]) {
      controller.addListener(_notify);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _accessTokenController,
      _customUrlController,
      _customPathController,
      _customDivisorController,
      _customPrefixController,
    ]) {
      controller.removeListener(_notify);
      controller.dispose();
    }
    super.dispose();
  }

  BalanceQueryConfig _currentConfig() {
    final divisor = double.tryParse(_customDivisorController.text.trim());
    return BalanceQueryConfig(
      enabled: _enabled,
      mode: _mode,
      accessToken: _accessTokenController.text.trim(),
      customUrl: _customUrlController.text.trim(),
      customPath: _customPathController.text.trim(),
      customDivisor: divisor == null || divisor <= 0 ? 1 : divisor,
      customPrefix: _customPrefixController.text,
    );
  }

  void _notify() {
    // 测试结果和输入内容不再对应时先清掉，避免误读。
    if (_testText != null) {
      setState(() {
        _testText = null;
        _testDetail = null;
        _testFailed = false;
      });
    } else {
      setState(() {});
    }
    widget.onChanged(_currentConfig());
  }

  Future<void> _test() async {
    final baseUrl = widget.baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() {
        _testText = '先填写上面的 API 地址';
        _testDetail = null;
        _testFailed = true;
      });
      return;
    }
    final config = _currentConfig();
    final profile = ApiProfile(
      id: 'balance-query-test',
      name: '余额测试',
      baseUrl: baseUrl,
      apiKey: widget.apiKeyController.text.trim(),
      balanceQuery: config,
    );
    setState(() {
      _testing = true;
      _testText = null;
      _testDetail = null;
      _testFailed = false;
    });
    try {
      final result = await ref
          .read(balanceQueryApiProvider)
          .query(profile: profile, config: config);
      if (!mounted) {
        return;
      }
      setState(() {
        _testing = false;
        _testText = result.text;
        _testDetail = [
          '来源 ${result.source}',
          if (result.detail != null && result.detail!.isNotEmpty) result.detail!,
        ].join(' · ');
        _testFailed = false;
      });
    } on BalanceQueryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _testing = false;
        _testText = '查询失败';
        _testDetail = error.message;
        _testFailed = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _testing = false;
        _testText = '查询失败';
        _testDetail = '$error';
        _testFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final theme = Theme.of(context);
    final needsToken =
        _mode == BalanceQueryMode.auto || _mode == BalanceQueryMode.account;

    return Container(
      decoration: AppDecorations.card(brightness: b, radius: AppRadius.lg),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('余额查询', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpace.xxs),
          Text(
            '主页右下角显示当前中转站的余额，切到哪个中转站就查哪个。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(b),
            ),
          ),
          const SizedBox(height: AppSpace.xxs),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示余额'),
              subtitle: const Text('关掉后主页右下角不再查询和显示余额。'),
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
                widget.onChanged(_currentConfig());
              },
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          DropdownButtonFormField<BalanceQueryMode>(
            initialValue: _mode,
            isExpanded: true,
            isDense: true,
            itemHeight: 48,
            decoration: _fieldDecoration('查询方式'),
            items: [
              for (final mode in BalanceQueryMode.values)
                DropdownMenuItem(value: mode, child: Text(mode.label)),
            ],
            onChanged: (mode) {
              if (mode == null) {
                return;
              }
              setState(() {
                _mode = mode;
              });
              widget.onChanged(_currentConfig());
            },
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            _mode.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(b),
            ),
          ),
          if (needsToken) ...[
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _accessTokenController,
              obscureText: _obscureToken,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _fieldDecoration(
                '访问令牌（选填）',
                hint: '中转站面板「个人设置 → 系统访问令牌」生成后粘贴',
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscureToken ? '显示令牌' : '隐藏令牌',
                  onPressed: () {
                    setState(() {
                      _obscureToken = !_obscureToken;
                    });
                  },
                  icon: _obscureToken
                      ? const Icon(Icons.visibility_rounded)
                      : const Icon(Icons.visibility_off_rounded),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              '填了才能读到整账户的余额；不填就只能读这个 API Key 自己的额度。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary(b),
              ),
            ),
          ],
          if (_mode == BalanceQueryMode.custom) ...[
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _customUrlController,
              keyboardType: TextInputType.url,
              decoration: _fieldDecoration(
                '查询地址',
                hint: 'https://api.example.com/v1/balance 或 {base}/api/balance',
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customPathController,
                    decoration: _fieldDecoration(
                      '余额字段路径（选填）',
                      hint: 'data.quota',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _customDivisorController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _fieldDecoration('换算倍数', hint: '500000'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    controller: _customPrefixController,
                    decoration: _fieldDecoration('货币符号'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              '留空字段路径时会自动找 balance / quota / remaining 这类常见字段；'
              '换算倍数用于「接口给的是额度而不是钱」的情况，例如 500000 额度 = 1 美元就填 500000。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary(b),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_testing ? '查询中…' : '测试余额查询'),
              ),
              if (_testText != null)
                Text(
                  _testFailed ? _testText! : '余额 $_testText',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _testFailed
                        ? AppColors.dangerText(b)
                        : AppColors.primary(b),
                  ),
                ),
            ],
          ),
          if (_testDetail != null) ...[
            const SizedBox(height: AppSpace.xxs),
            Text(
              _testDetail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _testFailed
                    ? AppColors.dangerText(b)
                    : AppColors.textSecondary(b),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(
              color: AppColors.infoSurface(b),
              borderRadius: AppRadius.smAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '怎么填',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.infoText(b),
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  '查询方式选「自动识别」就行，会依次试几种接口，挑第一个能读到数字的。\n'
                  '· Aihub：走 /v1/usage，用现在这个 API Key，什么都不用再填。\n'
                  '· 万川 / one-api / new-api：想显示账户余额，需要在面板「个人设置 → 系统访问令牌」'
                  '生成令牌后填到上面；不填时只能显示这个 Key 自己的额度（不限额度会显示「不限」）。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.infoText(b),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  String _trimNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
