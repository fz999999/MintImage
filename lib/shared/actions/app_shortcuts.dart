import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';

/// 全局快捷键注册表。
///
/// 现状问题：全库只有 `Enter`（发送）和 `Ctrl+V`（粘贴）两处键盘处理，
/// 没有任何 `Shortcuts` / `Actions` 体系。桌面专业工具没有键盘效率。
///
/// 在 `MaterialApp.builder` 中挂 [AppShortcutsScope] 即可全窗口生效。
class AppShortcutMap {
  const AppShortcutMap._();

  /// 聚焦搜索
  static final LogicalKeySet focusSearch = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  );

  /// 新建：聚焦输入栏并清空
  static final LogicalKeySet newTask = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyN,
  );

  /// 打开设置
  static final LogicalKeySet openSettings = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.comma,
  );

  /// 全选图片
  static final LogicalKeySet selectAll = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyA,
  );

  /// 收藏选中
  static final LogicalKeySet favoriteSelected = LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyD,
  );

  /// 刷新列表
  static final LogicalKeySet refresh = LogicalKeySet(
    LogicalKeyboardKey.f5,
  );

  /// 问号：快捷键帮助
  static final LogicalKeySet showHelp = LogicalKeySet(
    LogicalKeyboardKey.slash,
  );

  /// 多选模式
  static final LogicalKeySet toggleMultiSelect = LogicalKeySet(
    LogicalKeyboardKey.keyM,
  );

  /// 删除选中
  static final LogicalKeySet deleteSelected = LogicalKeySet(
    LogicalKeyboardKey.delete,
  );

  /// 上一层
  static final LogicalKeySet escape = LogicalKeySet(
    LogicalKeyboardKey.escape,
  );

  static final Map<ShortcutActivator, AppShortcutAction> bindings =
      <ShortcutActivator, AppShortcutAction>{
        focusSearch: AppShortcutAction.focusSearch,
        newTask: AppShortcutAction.newTask,
        openSettings: AppShortcutAction.openSettings,
        selectAll: AppShortcutAction.selectAll,
        favoriteSelected: AppShortcutAction.favoriteSelected,
        refresh: AppShortcutAction.refresh,
        showHelp: AppShortcutAction.showHelp,
        toggleMultiSelect: AppShortcutAction.toggleMultiSelect,
        deleteSelected: AppShortcutAction.deleteSelected,
      };

  /// 帮助面板里展示的条目
  static const List<(String, String)> helpEntries = <(String, String)>[
    ('Ctrl + F', '聚焦搜索'),
    ('Ctrl + N', '新建：聚焦输入栏并清空'),
    ('Ctrl + ,', '打开设置'),
    ('Ctrl + A', '全选图片'),
    ('Ctrl + D', '收藏选中'),
    ('M', '进入 / 退出多选'),
    ('Delete', '删除选中（需确认）'),
    ('F5', '刷新列表'),
    ('Enter', '发送提示词'),
    ('Shift + Enter', '换行'),
    ('Ctrl + V', '粘贴剪贴板图片'),
    ('← →', '预览页切换上一张 / 下一张'),
    ('空格', '预览页切换信息面板'),
    ('+ / −', '预览页缩放'),
    ('0', '预览页适应窗口'),
    ('Esc', '逐层退出：菜单 → 多选 → 搜索 → 预览回主页'),
    ('?', '打开快捷键面板'),
  ];
}

/// 快捷键触发的语义动作。页面通过回调消费。
enum AppShortcutAction {
  focusSearch,
  newTask,
  openSettings,
  selectAll,
  favoriteSelected,
  refresh,
  showHelp,
  toggleMultiSelect,
  deleteSelected,
}

/// 把快捷键映射到回调。全窗口生效。
class AppShortcutsScope extends StatelessWidget {
  const AppShortcutsScope({
    super.key,
    required this.onAction,
    required this.child,
  });

  final ValueChanged<AppShortcutAction> onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        for (final entry in AppShortcutMap.bindings.entries)
          entry.key: _ActionIntent(entry.value),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ActionIntent: CallbackAction<_ActionIntent>(
            onInvoke: (intent) {
              onAction(intent.action);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _ActionIntent extends Intent {
  const _ActionIntent(this.action);

  final AppShortcutAction action;
}

/// 快捷键帮助对话框。桌面工具的标准配置入口。
Future<void> showShortcutHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('键盘快捷键'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in AppShortcutMap.helpEntries)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpace.xxs,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 132,
                          child: Text(
                            entry.$1,
                            style: TextStyle(
                              fontFamily: 'Cascadia Mono',
                              fontSize: AppFontSize.labelSm,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.$2,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
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
}