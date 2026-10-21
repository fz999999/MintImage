# UI 升级落地记录（P0–P6）

> 配套文档：`docs/UI-UPGRADE-PLAN.md`（方案）、`docs/UI-DECISIONS.md`（49 条拍板）。
> 本文件记录**实际落地结果**：提交、落点、偏离方案的地方、验证证据、尚未验证的项。

## 1. 提交

| 提交 | 内容 |
| --- | --- |
| `8f8a6d0` | P0 设计基座：`AppColors` 亮暗语义色 + 设计 token + 双主题 |
| `1c4917f` | 方案与拍板文档 |
| `cff3862` | P1 应用外壳（左导航 256 + IndexedStack 三 tab），废弃独立日志窗口 |
| `49cf147` | P2 图墙 16:9 自适应列 + 图卡 hover 与三圆钮 |
| `9bed71b` | P3 输入栏参数行 Wrap + 图标胶囊 + 附件上限 8 + 余额占位槽 |
| `6638d17` | P4 设置页卡内编辑/删除 + 超时行内编辑 + 备份分组，删除日志入口 |
| `ebc4245` | P5 日志页概览卡精简与换肤 |
| `b07174e` | P6 收藏夹/预览页/加载占位换肤，补语义色 |

回滚锚点：`backup-pre-revert` = `fdb6a55`（撤销 workbuddy 改动前的原始状态）。
单阶段回滚：`git revert <P0..P6 中对应提交>`，六个提交按目录切分，互不牵连。

## 2. 决策 → 落点

| 决策 | 落点 |
| --- | --- |
| 深色换中性灰、实底用 `#0E7490` | `lib/shared/design/app_colors.dart`（`primaryContainer` 恒 `#0E7490`，`primary` 深色 `#81D1F0` 只做文字/描边） |
| 圆角 6/12/16/22/999、字号 10–28 八档 | `lib/shared/design/tokens.dart` |
| label 也走 Manrope | `lib/shared/theme.dart` `_textTheme(Brightness)` |
| 175 处 `AppThemeTokens` → `AppColors(b)` | 21 个业务文件全部清零，只剩 `theme.dart` 的兼容定义 |
| 双模态（决策 49 重定） | `lib/app.dart` `darkTheme` + `themeMode: ThemeMode.system` |
| 2 不做 40px 自绘标题栏 | 系统标题栏保留，内容顶栏独立 |
| 3/4 左导航三 tab、日志迁入 | `lib/features/shell/app_shell.dart`、`app_nav_sidebar.dart`；删 `log_viewer_app.dart` 与 `--log-window` 分支 |
| 6 图卡 16:9、列数自适应 | `image_list_widget.dart` `_GridMetrics`（见 §3 偏差 1） |
| 9/10 hover 三圆钮、180ms 上移 4px | `image_cell.dart` `_HoverCircleButton`、`AnimatedContainer` |
| 16 参数行 `Wrap` | `bottom_input_bar.dart` `Row(Expanded(Wrap), BalanceLabel)` |
| 17 胶囊去前缀加图标 | 七个 selector 各自图标 + 真实值；`SelectorChipShell` 统一外壳 |
| 18 余额 | `lib/features/input/balance_label.dart`（纯展示）+ `channel_balance.dart`（取数），右上角随当前中转站切换；数据源见决策 18 更新 |
| 19 附件上限 8 | `appendImageFromRecord` / `_handlePasteShortcut` / `_pickAttachments` 三入口 + `_prefillAttachments` 兜底 |
| 21 备份分两组 | `settings_page.dart` `_DataBackupCard` + `_BackupGroup` |
| 22 超时行内编辑 | `_RequestTimeoutCard`，clamp 5–3600，默认仍 600 |
| 23 卡内 edit/delete + 二次确认 | `_ConfigActions`、`_confirmDeleteConfig`；两个列表都补「至少留 1 个」保护（provider 侧也加了兜底） |
| 27 日志不做筛选/搜索/分页 | 保持 `ExpansionTile` + 刷新 |
| 28 概览卡只留三样 | 总条数 / 文件路径 / 复制按钮 |

## 3. 偏离方案的地方（有意为之）

1. **图墙列数：`_minCardWidth` 180 → 220、上限 8 → 6。**
   180 时 1280 宽窗口排到 6 列，单卡图高只剩 112px；220 + 上限 6 后 1280 为 5 列（图高 136）、1600 封顶 6 列（图高 146），与 Stitch 稿 1600/6 列一致。窄窗仍由 `columnCount.clamp(3, …)` 保 3 列。
2. **导出扩展名是 `.mintbackup` 而不是方案里写的 `.json`。** `FilePicker.saveFile(allowedExtensions: ['mintbackup'])` 存的就是这个后缀，文案按实现写，避免误导。
3. **日志概览文案「共 N 条」**（原「最近 N 条请求日志」）。
4. **超时 clamp 只落在 UI 层**：`settings_model._normalizeRequestTimeoutSeconds` 仍只处理「非正数回退默认」，从备份恢复仍可能写入超出 5–3600 的值。
5. **`_PreviewChip` 底色改 `primaryContainer` + `onPrimaryContainer` 文字**：原 `primaryStrong` 在深色下是浅色，压白字对比度仅约 1.4:1。

## 4. 验证证据

| 项 | 结果 |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | **85 通过 / 5 跳过 / 0 失败**（含新增 hover 用例） |
| `flutter build windows --release` | 成功，44s |
| `scripts/run-windows.ps1` | 启动成功，pid 31352，窗口标题「大川生图工具」 |
| `AppThemeTokens` 残留 | 21 个业务文件 → 0；仅 `theme.dart` 兼容定义 |
| `Color(0x…)` 残留 | 51 处 → 仅 `app_colors.dart`/`theme.dart` 的定义、`main.dart` 启动闪屏 3 处、棋盘格默认值 2 处 |

## 5. 尚未验证 / 已知差异

1. **暗色未逐屏目视**：颜色走 token 求值，逻辑上无白块；需切系统深色模式逐屏过一遍。
2. **字体放大 >1.25 时图卡文字区（76px）可能 RenderFlex overflow**，未加 `withClampedTextScaling`。
3. **Release 图标 tree-shaking**：`EmptyState` 的 `icon`/`actionIcon` 是 `IconData` 入参（调用点仍是 `Icons.xxx` 内联字面量）。若 release 里「前往设置」图标空白，删 `.dart_tool\flutter_build` 重建；仍空白就把 `actionIcon` 改回内联常量。
4. **手机布局**：`shortestSide < 600` 走 2 列，图高从 188 变为 16:9 的约 93；本仓库只维护 Windows，未验收。
5. **空态已无下拉刷新**（决策 13）：桌面端列表靠 provider 实时更新，无手动刷新入口；如需保留入口应另加按钮。
6. **`main.dart` 启动闪屏**保留 `Color(0xFFF8FAFF)`/`Color(0xFF0B1C30)`：它在 Theme 之前渲染，读不到 brightness。
7. **图卡时间标签只在重建时刷新**（`刚刚/N 分钟前`），不会每分钟自走。
