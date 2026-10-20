# UI 升级方案（按 `e9a570e` 撤销后的代码重写）

> **版本基准**：`e9a570e revert: 撤销 workbuddy 强制加入的 UI 重构`
> 旧版本文档基于 `fdb6a55`（含 workbuddy 强加的 token 层与暗色主题），已作废。
> 决策依据：`docs/UI-DECISIONS.md`。两份冲突时以决策文件为准。
> 本轮**不改任何代码**，只出调研与方案。

---

## 一、现状梳理

### 1.1 代码体量

`lib/` 共 **64 个 dart 文件 / 20765 行**（撤销前是 68 个 / 21912 行）。

| 文件 | 行数 | 角色 |
| --- | --- | --- |
| `lib/core/database/app_database.g.dart` | 3179 | drift 生成，勿手改 |
| `lib/features/settings/settings_page.dart` | 1587 | 设置页（单列长列表） |
| `lib/features/input/bottom_input_bar.dart` | 1585 | 底部输入栏 |
| `lib/features/image_list/image_cell.dart` | 940 | 图片卡 |
| `lib/features/image_list/image_preview_page.dart` | 828 | 预览页 |
| `lib/core/models/settings_model.dart` | 768 | 设置模型 |
| `lib/core/api/openai_client.dart` | 734 | HTTP 客户端 |
| `lib/core/api/prompt_optimization_api.dart` | 616 | 提示词优化 |
| `lib/features/home/home_page.dart` | 608 | 主界面 |
| `lib/features/input/size_picker_modal.dart` | 607 | 尺寸选择（71 条预设） |
| `lib/core/services/backup_service.dart` | 562 | 备份/WebDAV |
| `lib/features/settings/api_profile_edit_page.dart` | 516 | 生图 API 编辑 |
| `lib/features/favorites/favorite_folder_sheet.dart` | 495 | 收藏夹 |
| `lib/core/providers/generation_provider.dart` | 488 | 生成状态机 |
| `lib/features/image_list/image_list_widget.dart` | 312 | 图墙 |
| `lib/features/logs/request_log_page.dart` | 258 | 日志页 |
| `lib/shared/theme.dart` | 257 | 主题（**无暗色**） |

### 1.2 七个决定性事实（均已实测）

1. **没有路由、没有壳**。`lib/app.dart:59-64` 只有 `MaterialApp(theme: buildAppTheme(), home: widget.home ?? const HomePage())`；页面跳转全靠 `Navigator.push`（设置页 `home_page.dart:141`、预览页 `image_cell.dart:289`）。
2. **没有暗色主题**。`app.dart` 既无 `darkTheme` 也无 `themeMode`；`lib/shared/theme.dart:72` 的 `buildAppTheme()` 是唯一入口，`theme.dart:74` 用 `ColorScheme.fromSeed`，`AppThemeTokens`（`theme.dart:4`）是**一整套写死的亮色常量**，被 **233 处**引用。
3. **没有设计 token**。`AppRadius / AppFontSize / AppSpace / AppShadow / AppMotion` 均不存在。现状：`BorderRadius.circular()` 共 **81 处、13 种取值**（12×19、999×14、18×10、16×10、14×8、8×7、10×3、7×2、22×2、2×2、24×1、20×1、1.8×1）；就地 `fontSize:` **21 处、10 种取值**（10×4、14×3、12×3、11×3、16×2、13×2、30×1、24×1、20×1、10.5×1）；就地 `Color(0x…)` **51 处**。
4. **图片卡没有任何 hover 效果**。`image_cell.dart:17` 是 `class ImageCell extends ConsumerWidget`（无状态），全文件**无 `MouseRegion`、无悬停蒙层、无快捷按钮**；只有 `InkWell`（`:73`/`:91`）+ `onLongPress` 打开 9 项面板（`:325-402`）。
5. **没有滚动条**。`image_list_widget.dart` 与 `app.dart` 均无 `Scrollbar` / `ScrollBehavior`；桌面端滚动条完全消失。
6. **没有快捷键**。`app.dart` 无 `Shortcuts`/`Actions`；`home_page.dart:29` 的 State 是**私有类** `_HomePageState`，外部无法转发任何动作。
7. **图卡尺寸写死**。`image_list_widget.dart:287-310` 的 `_GridMetrics.fromContext`：`imageHeight = isPhone ? 188 : 206`（固定高度，非 16:9）、`footerHeight = 68`、`desktopColumnCount = (availableWidth / 206).floor()`、`columnCount = clamp(2, 10)`、`sidePadding 10/14`、`gap 8/10`、`top 10 / bottom 12`。

### 1.3 页面与入口

| 页面 | 入口 | 备注 |
| --- | --- | --- |
| 主界面 `home_page.dart` | `app.dart:64` | AppBar + 图墙 + 底部输入栏 |
| 设置页 `settings_page.dart` | `home_page.dart:141` | 独立 push，单列长列表 |
| 生图 API 编辑 `api_profile_edit_page.dart` | 设置页内 push | |
| 提示词优化编辑 `prompt_optimization_profile_edit_page.dart` | 设置页内 push | |
| 图片预览 `image_preview_page.dart` | `image_cell.dart:289` | 全屏 push，Hero `image-<id>` |
| 请求日志 `request_log_page.dart` | 设置页内 push（`_openRequestLogs`） | 另一路：`--log-window` 独立进程窗口 |
| 日志窗口 `log_viewer_app.dart` | `lib/main.dart` 的 `args.contains('--log-window')` | 独立 `MaterialApp`，仅亮色 |

### 1.4 现有交互能力

- 有：`onSecondaryTap`/`onLongPress` 打开 9 项操作面板；多选拖拽（`image_list_widget.dart:214`）；`RefreshIndicator` **3 处**（`:78`/`:97`/`:117`，三个空态分支各一个）；输入栏键盘手势（Enter 发送 / Shift+Enter 换行）。
- 无：hover 反馈、右键菜单、拖放收图、键盘快捷键、滚动条、暗色、窗口尺寸持久化。

### 1.5 Stitch 新 UI 概览

`stitch_windows_ui/stitch_windows_ui/` 下 `_1`（工作台）、`_2`（设置）、`_3`（请求日志），各含 `code.html` + `screen.png`；另有 `fluent_pro_ai_workstation/DESIGN.md`。

- 结构：40px 自绘顶栏 + 256px 左导航（主界面/日志/设置）+ 内容区；`_1` 含 6 列图墙与悬浮输入栏；`_2`/`_3` 复用同一壳。
- 样式：`<html class="dark">`，M3 中性灰调色板（`#101416`/`#181c1e`/`#1c2022`/`#272b2c`/`#313537`），`primary #81d1f0`、`primary-container #0E7490`、`accent-teal #06B6D4`；背景 `backdrop-blur-xl` + 半透明层；Manrope 8 个字号角色；图标用 Material **Symbols** web font。
- 交互：纯静态 HTML + 2 段 JS（搜索条展开、附件行显隐）；无路由、无框架。

**Stitch 自身的 3 处矛盾**（已按决策裁决，见 §2.5）：字体/圆角表在 `DESIGN.md` 与 `code.html` 的 tailwind 覆盖之间不一致；主色在 `DESIGN.md` 正文与 YAML 之间不一致；`_3` 的日志内容是臆造数据（ComfyUI / VRAM / Port 7860），与本仓库 OpenAI 生图链路无关。

---

## 二、差异清单

### 2.1 页面级

| 页面 | 变化 | 依据 |
| --- | --- | --- |
| 主界面 | **重构为三 tab 壳的首个 tab**；AppBar 从 5 个动作减为 4 个（去掉「设置」，改由左导航进入）；新增「全部作品 (N)」 | 决策 2/3/4/11 |
| 设置 | 由独立 push 页改为第三个 tab；版本号区改为显示 `AppVersion.current`；删「请求日志」入口卡 | 决策 4/42 |
| 请求日志 | 由「独立窗口 + 设置页入口」改为第二个 tab；只换肤 + 概览卡改版 | 决策 4/26/27/28 |
| 独立日志窗口 | **删除**（`log_viewer_app.dart`、`main.dart` 的 `--log-window` 分支） | 决策 4 |
| 预览页 | 保留 push 全屏；不加键盘快捷键 | 决策 5 / 重定 5 |
| 空态 | 保留 `EmptyState` 结构，换肤 + 去硬编码 | 决策 12 |
| 收藏夹、尺寸选择器 | 仅换肤，结构不动 | — |

### 2.2 组件对应关系

| 现状组件 / 位置 | Stitch 对应 | 处理 |
| --- | --- | --- |
| `home_page.dart` 的 `Scaffold` + `AppBar` | 40px 顶栏 + 左导航 | **替换**：新建 `app_shell.dart` + `app_nav_sidebar.dart`；顶栏只保留内容顶栏，窗口标题栏用系统的（决策 1） |
| `image_list_widget.dart` 的 `GridView` | `grid-cols-6` 图墙 | 改：16:9 + 列数 `clamp(3,8)` + 最小卡宽 200 |
| `image_cell.dart`（`ConsumerWidget`） | 卡片（图上 + 两行文字） | 重写样式层：hover 用 `MouseRegion` 自写（180ms，上移 4px + 图 1.05 + 蒙层） |
| `image_cell.dart` 的 `_MetaOverlay` chips | 图上角标 + 状态徽章 | 重组：角标用 `caption 10`；文字区改 `16:9 • 高 • WEBP`（+`• 单图`） |
| `image_cell.dart:325-402` 的 9 项面板 | 无（Stitch 只有 ⋯） | **保留**（仓库能力更全） |
| 现状无 | hover 3 个圆钮（预览/保存/复制） | **待新增**（决策 9） |
| `request_log_page.dart` 的 `_LogOverviewCard` | 概览卡 + GPU VRAM 卡 | 改版：只留总条数 + 路径 + 复制 |
| `request_log_page.dart` 的 `_LogLevelChip` | 级别筛选 chips | **不采纳**（决策 27） |
| `settings_page.dart` 的 `SlidableAction`（左滑删） | 卡内 edit/delete 图标 | **替换**（决策 23） |
| `empty_state.dart` | 空态插画 + 按钮 | 保留结构，参数化 3 个 chip 与图标 |
| 现状无 | 左导航 | **待新增**（决策 2） |
| 现状无 | 余额显示 | **待新增占位**（决策 18，无数据源） |

### 2.3 样式差异（含现状量化）

| 维度 | 现状 | 目标 | 工作量 |
| --- | --- | --- | --- |
| 色彩 | `AppThemeTokens` 写死亮色 ×233 + `Color(0x)` ×51，**无暗色** | 亮/暗双套语义色 + `brightness` 求值 | **最大**：233 + 51 处 |
| 圆角 | 81 处、13 种取值 | 5 档：**6 / 12 / 16 / 22 / 999** | 81 处归并（重定 3） |
| 字号 | 21 处、10 种取值 | 8 档：**10 / 11 / 12 / 13 / 14 / 16 / 20 / 28** | 21 处归并（重定 4） |
| 字体 | Manrope 正文 + **Inter 的 label 三级**（`theme.dart:127/133/139`，tooltip `:174`） | 全部 Manrope | 4 处 |
| 阴影 | `AppDecorations.softShadow/floatingShadow` 青色软阴影（`theme.dart:26/38`），`card(radius: 24)`（`:45`） | 亮色保留青色软阴影；暗色改黑投影 | 中 |
| 玻璃 | 输入栏 `ClipRRect(22)` + `glass(radius:22)` + blur 16（`bottom_input_bar.dart:258-266`） | 保持 22；暗色 blur 提到 24 | 小 |
| 图标 | `Icons.*` 内联常量 | 同（Stitch 的 Material Symbols 需映射） | 14 处映射 |

### 2.4 交互差异

| 交互 | 现状 | Stitch | 处理 |
| --- | --- | --- | --- |
| 卡片 hover | **无** | 上移 + 放大 + 蒙层 + 2 圆钮 | 新增（3 圆钮、180ms） |
| 左侧导航 | 无 | 3 项 + 当前项实底高亮 | 新增 |
| 搜索条 | AppBar 下方展开（致位移 52px） | 内容顶栏下方折叠、高度动画 | 改 |
| 参数选择 | 7 个胶囊挤一行 + `FittedBox(scaleDown)`（`bottom_input_bar.dart:411`） | 一行 7 胶囊，溢出横向滚动 | 改：`Wrap` 两行 |
| 附件行 | 有附件即显示（现状已如此） | 常驻折叠 | 保持（决策 20） |
| 请求日志展开 | `ExpansionTile` | accordion + 复制代码 | 保持现状（决策 27） |
| 快捷键 | 无 | 无 | 不新增（重定 5） |

### 2.5 冲突点（已裁决）

| # | 冲突 | 裁决 |
| --- | --- | --- |
| 1 | Stitch 圆角：`DESIGN.md` 写 lg=8/xl=12，html 覆盖实际是 lg=4/xl=8/full=12 | 以截图/html 为准（决策 38），但最终映射到我们的 5 档（重定 3） |
| 2 | Stitch 主色：`DESIGN.md` 正文写 `#0E7490`，YAML 里 `primary` 是 `#81d1f0` | 以 YAML role 为准：`#0E7490` 做实底、`#81d1f0` 做文字描边（决策 39/31） |
| 3 | Stitch 的 `rounded-full` 被覆盖成 12px（不是圆） | 按设计意图做真圆（决策 40） |
| 4 | Stitch 日志页内容是臆造（ComfyUI/VRAM/Port 7860） | 全部改真实语义（决策 42） |
| 5 | Stitch 有 40px 自绘顶栏（含最小化/关闭） | **不做**，用系统标题栏（决策 1）——避免引入 `window_manager` 或改 `WM_NCCALCSIZE` |
| 6 | Stitch 左导航 256px / 三栏方案曾规划 216 + 右上下文面板 320 | 两栏、左导航 256（决策 43） |
| 7 | Stitch 深色 vs 现状无暗色 | 做双模态（重定 1） |

---

## 三、升级方案

### 3.1 总体思路

三条主线，顺序不能颠倒：

1. **先建基座**：色层（亮/暗可求值）+ token 层（半径/字号/间距/图标/阴影/动效）。没有它，后面每一步都会新增魔法数字。
2. **再换骨架**：三 tab 壳 + 左导航，主界面 AppBar 减到 4 个动作，日志从独立窗口收进 tab。
3. **最后逐屏换皮**：图墙/图卡 → 输入栏 → 设置页 → 日志页。每屏一个可验收的交付，不做「一次性大爆改」。

**节奏约定**：色引用（233+51 处）不单独开一轮，而是**打开哪个文件就在那个文件里改干净**（重定 2）；没碰过的文件留到下一轮。

### 3.2 分阶段

| 阶段 | 目标 | 产出 | 验收 |
| --- | --- | --- | --- |
| **P0 设计基座** | 建立可复用的色与尺度 | 新建 `lib/shared/design/app_colors.dart`（亮/暗语义色 + `xxx(Brightness)` 取值函数 + 状态层）、`lib/shared/design/tokens.dart`（`AppSpace/AppRadius/AppFontSize/AppIconSize/AppShadow/AppOpacity/AppMotion`）；`theme.dart` 改为 `_buildBase(Brightness)` 生成 `buildAppTheme()/buildAppDarkTheme()`；`app.dart` 加 `darkTheme` + `themeMode: ThemeMode.system`；label 去 Inter | 亮/暗切换后主界面无「白块」；`flutter test` 全绿 |
| **P1 壳与导航** | 三 tab + 左导航替代 AppBar 设置入口 | 新建 `lib/features/shell/app_shell.dart`、`app_nav_sidebar.dart`；`home_page.dart` 退化为第一个 tab 的内容；设置页与日志页挂成 tab；删 `log_viewer_app.dart`、`main.dart` 的 `--log-window` 分支、设置页日志入口卡 | 三个 tab 可切换且保持状态；窗口标题栏正常；无 `--log-window` 残留 |
| **P2 图墙与图卡** | 16:9 + 自适应列 + hover + 新元信息 | 改 `image_list_widget.dart`（列数、`_GridMetrics`：**最小卡宽 180**、**`footerHeight` 68→76**、删 3 处 `RefreshIndicator`）、`image_cell.dart`（hover、3 圆钮、角标 `caption 10`、元信息行、状态徽章换肤） | 600/1280/1600 三档宽度不溢出；hover 与 3 钮均可用；多选拖拽坐标正确 |
| **P3 输入栏** | 参数换行 + 按钮 40 + 图标胶囊 | 改 `bottom_input_bar.dart`：`FittedBox`→`Wrap`、`+` 移到框外左侧、优化钮 28→40、胶囊加图标去前缀、`BalanceLabel` 占位、附件上限 8；图墙底部留白 12→24 | 900px 宽下参数两行不遮挡图墙；输入框仍 40px 高；`bottom_input_bar_test.dart` 同步通过 |
| **P4 设置页** | 卡内操作 + 超时 inline + 备份分组 | 改 `settings_page.dart`：`SlidableAction`→卡内 edit/delete + 二次确认（并给优化 API 补「至少留 1 个」保护）、超时 inline、备份 5 动作分本地/云端、删守护徽章、显示 `AppVersion.current` | 删除有二次确认；超时保存生效；备份 5 个动作都可达 |
| **P5 日志页** | 只换肤 + 概览卡改版 | 改 `request_log_page.dart`：概览卡留总条数/路径/复制；颜色走新色层 | 与 P1 的 tab 挂载一致；展开折叠与刷新不变 |
| **P6 收尾** | 残留魔法数字与一致性 | 剩余 `BorderRadius.circular`/`fontSize` 归并；`empty_state.dart` 参数化；暗色逐屏核对 | 全局 grep 无残留；两侧主题各走一遍 |

### 3.3 文件级改动清单

| 动作 | 文件 | 说明 |
| --- | --- | --- |
| **新建** | `lib/shared/design/app_colors.dart` | 亮/暗语义色 + `Brightness` 求值 |
| **新建** | `lib/shared/design/tokens.dart` | 6 个 token 类 |
| **新建** | `lib/features/shell/app_shell.dart` | 左导航 + 内容区 + tab 切换 |
| **新建** | `lib/features/shell/app_nav_sidebar.dart` | 三 tab 导航项 |
| **新建** | `lib/features/shell/balance_label.dart` | 余额占位（无数据时不渲染） |
| 替换 | `lib/shared/theme.dart` | 257 行 → `_buildBase(Brightness)` 双主题；`AppThemeTokens` 保留为过渡（逐步清空） |
| 修改 | `lib/app.dart` | 加 `darkTheme` / `themeMode`；`home:` 指向 `AppShell` |
| 修改 | `lib/main.dart` | 删 `--log-window` 分支 |
| **删除** | `lib/features/logs/log_viewer_app.dart` | 随日志窗口废弃 |
| **删除** | `lib/features/input/selector_button.dart` | 84 行、**0 调用** |
| 修改 | `lib/features/home/home_page.dart` | 去掉 AppBar 的设置按钮；body 改为主 tab 内容；接「全部作品 (N)」 |
| 修改 | `lib/features/image_list/image_list_widget.dart` | 列数 16:9、删 3 处 `RefreshIndicator`、底部留白 |
| 修改 | `lib/features/image_list/image_cell.dart` | hover（`MouseRegion`）、3 圆钮、角标、元信息行 |
| 修改 | `lib/features/input/bottom_input_bar.dart` | `Wrap`、按钮尺寸、图标胶囊、余额槽、8 张上限 |
| 修改 | `lib/features/input/{size,quality,image_format,background,quantity}_selector.dart` | 胶囊文案去前缀 + 图标（决策 17） |
| 修改 | `lib/features/settings/settings_page.dart` | 卡内操作、二次确认、超时 inline、备份分组、删日志入口 |
| 修改 | `lib/features/logs/request_log_page.dart` | 概览卡改版 + 换肤 |
| 修改 | `lib/shared/widgets/empty_state.dart` | 参数化 3 个 chip 与图标 |
| 保留 | `lib/features/favorites/favorite_folder_sheet.dart` | 仅换肤 |
| 保留 | `lib/features/image_list/image_preview_page.dart` | 不加快捷键 |
| 不动 | `stitch_windows_ui/` | 设计输入，非运行代码 |
| 不动 | `docs/UI-LAYOUT-SPEC-WINDOWS.md`、`docs/UI-SPEC-APPENDIX.md` | 用户自己的文档 |

### 3.4 无法直接复用的部分

| Stitch 元素 | 原因 | 处理 |
| --- | --- | --- |
| 40px 自绘顶栏 + 最小化/关闭钮 | `pubspec.yaml` 无 `window_manager`；改原生需 `WM_NCCALCSIZE` | 用系统标题栏（决策 1） |
| Material Symbols 图标 + `FILL` 变体 | 是 web 字体，Flutter 用 `Icons.*`；且 AGENTS.md 要求图标内联常量（release 会 tree-shake 变量传入的图标） | 映射到 `Icons.*`（决策 37） |
| GPU VRAM / 守护进程 / Port 7860 / 余额 1,420 元 | 数据层无此概念（`ImageRecord` 也无进度百分比、渠道余额字段） | 删或改真实语义（决策 42）；余额只留占位槽 |
| 日志页级别筛选 / 搜索 / 分页 / 复制代码 | 仓库无对应数据字段（`RequestLogEntry` 只有时间/级别/标题/详情） | 不做（决策 26/27） |
| 6 列固定网格 | 1280 窗口下单卡仅 149px、图高 84px，文字挤爆 | 改自适应 `clamp(3,8)`（决策 6） |
| 横向滚动参数行 | 桌面上横向滚动不可发现 | 改 `Wrap` 两行（决策 16） |
| 左导航中的头像 / 版本号 | 无用户体系 | 换成本地固定文案 + `AppVersion.current` |

### 3.5 红线（来自 AGENTS.md，改造时必须遵守）

1. 图标必须 `Icon(Icons.xxx)` **内联常量**，不能从变量/getter 传入。
2. `lib/core/database/app_database.dart` 顶部必须是 `part '...g.dart';`。
3. `lib/core/api/openai_client.dart` 的 `DioExceptionType` switch 收尾必须是 `default:`。
4. 运行时数据只走 `lib/core/services/app_paths.dart`，**不要**用 `getApplicationSupportDirectory()`。
5. 只改 Windows 相关；**不动 `android/`、`ios/`、`macos/`**。
6. `bottom_input_bar.dart`、`settings_page.dart`、`api_profile_edit_page.dart` **不是 format-clean，不要整体 `dart format`**。
7. 改完跑 `pwsh -File scripts/run-windows.ps1`，不打包。

---

## 四、风险与验证

### 4.1 风险

| # | 风险 | 触发点 | 处置 |
| --- | --- | --- | --- |
| R1 | 暗色只改一半，出现「深底 + 白卡」 | P0 改色层但未清完 233 处 | P0 结束时用 grep 列剩余 `AppThemeTokens` 的文件清单，作为 P1–P5 的收尾项，不允许跨阶段遗留 |
| R2 | 图卡从写死 206 高改 16:9 后，多选拖拽坐标错位 | `image_list_widget.dart:214-262` 用 `cellHeight` 反算行列 | `_GridMetrics` 与新布局同改；`cellHeight = imageHeight + footerHeight` 必须一起重算 |
| R3 | 3 列下限在 600px 窄窗溢出 | `clamp(3,8)` + 最小卡宽 200 → 3×200+2×10=620 | **已定**：最小卡宽降为 **180**（3×180+2×10=560），列数逻辑不变、1280/1600 不受影响 |
| R4 | 输入栏 96→130 遮挡图墙 | P3 参数换行 | 图墙 `bottomPadding` 12→24 同步改（`_GridMetrics` 内） |
| R5 | 按钮放大到 40 但测试断言输入框 40 | `bottom_input_bar_test.dart` 精确断言 | 输入框本体保持 `_primaryInputHeight = 40`（`bottom_input_bar.dart:31`） |
| R6 | 日志迁 tab 后轮询语义变化 | 现在独立窗口 `pollFileChanges: true` 每 2s 轮询 | tab 内改为「可见时轮询」，切走即停 |
| R7 | 删 `--log-window` 影响设置页 | `settings_page.dart:_openRequestLogs`、`_supportsDetachedLogWindow` | 两处一并删/改，避免留死代码 |
| R8 | 81 处半径归并到 5 档产生可见变化 | 12→12（不变）、18→16、14→16 或 12、8→6 或 12 | 先做映射表再批量改；逐屏对比截图 |
| R9 | 测试契约被打断 | `bottom_input_bar_test.dart`（5 个 Key + 文案 + 40px）、`image_cell_test.dart`（状态文案、长按面板）、`app_exit_confirmation_test.dart`（退出确认 4 段文案） | 契约里明确列出的不做改动；决策 17 要求的文案改动必须同步改测试 |
| R10 | 图标在 release 里消失 | 新加图标用变量传入 | 全部内联常量；若空白则删 `.dart_tool/flutter_build` 重编 |

### 4.2 回滚方式

- 每个阶段一个独立 commit，信息前缀 `P0:` … `P6:`。
- `P0` 只新增文件 + 切主题，不改页面结构，可单独 revert。
- 已有锚点：`git tag backup-pre-revert`（指向撤销前的 `fdb6a55`）；如需彻底回到那个状态：`git revert e9a570e`。
- 任阶段出问题：`git revert <该阶段 commit>`，不影响其它阶段。

### 4.3 验证与验收

| 层级 | 手段 | 通过标准 |
| --- | --- | --- |
| 单元/Widget | `& 'C:\src\flutter\bin\flutter.bat' --no-version-check test` | 现有 84 通过 / 5 跳过不下降 |
| 静态 | `flutter analyze` | 无新增 error |
| 实机 | `pwsh -File scripts/run-windows.ps1` | 亮/暗两套各走一遍：图墙 hover、3 圆钮、多选拖拽、参数两行、设置删卡确认、日志 tab、退出确认 |
| 尺寸 | 手动改窗口宽度 | 600 / 1280 / 1600 三档不溢出、不遮挡 |
| 视觉 | 对照 `stitch_windows_ui/stitch_windows_ui/_1|_2|_3/screen.png` | 布局层级、间距节奏、圆角与色阶一致；文案为真实语义 |

---

## 五、待确认项（已全部关闭）

| # | 原待确认 | 结论 | 影响 |
| --- | --- | --- | --- |
| 1 | 图卡文字区固定高度 | **76**（现 68）。新卡片要放 prompt 两行 + 元信息一行 + 时间/星标/⋯ 一行，68 装不下 | P2：`_GridMetrics.footerHeight = 76` |
| 2 | 600px 窄窗列数溢出 | **最小卡宽 180，列数下限仍为 3**（3×180+2×10=560 放得进 600） | P2：只改一个常量，列数逻辑不动 |
| 3 | 设置页是否加「关于」块 | **不需要新增**：`settings_page.dart:916` 已显示 `AppVersion.current`，`:922/:933` 已有 GitHub 链接，`url_launcher ^6.3.2` 已在依赖 | P4：只换肤 |
| 4 | 用户两份规范文档与本方案谁优先 | **不冲突**：`UI-LAYOUT-SPEC-WINDOWS.md` 是现状布局交接稿，`UI-SPEC-APPENDIX.md` 是现状像素参数补全（其 A8 圆角分布、A7 就地字号正是本方案要收敛的 81/21 处） | 换皮后按该附录 A11「复刻验收清单」逐项打勾 |
| 5 | 余额接什么数据 | **本期只留占位槽，不接数据**（仓库无任何 balance/billing/额度代码，`ImageRecord` 也无费用字段） | P3：`BalanceLabel` 接 `null` 时不渲染；以后改一个传值处即可 |
