import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import '../home/home_page.dart';
import '../logs/request_log_page.dart';
import '../settings/settings_page.dart';
import 'app_nav_sidebar.dart';

/// 应用外壳：左侧导航 + 右侧内容区。
///
/// 只用 `int` 索引 + [IndexedStack]（决策 2）：不引 go_router、不做转场动画、
/// 不拆路由表、不做右上下文面板。切换 tab 时各页状态保留。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 0 主界面 / 1 日志 / 2 设置。
  int _index = 0;

  void _selectTab(int index) {
    if (index == _index) {
      return;
    }
    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.canvas(b),
      body: Row(
        children: [
          AppNavSidebar(selectedIndex: _index, onSelected: _selectTab),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                HomePage(onOpenSettings: () => _selectTab(2)),
                const RequestLogPage(),
                const SettingsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
