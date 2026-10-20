# 附录 A：像素级参数补全（设计交接 · 第二部分）

> 配合 `docs/UI-LAYOUT-SPEC-WINDOWS.md` 使用：主文档讲**布局与位置**，本附录补**颜色 / 阴影 / 图标 / 文案 / 动效 / 二级弹层**。
> 本文件由三段拼合而成：手写段 A0–A3、脚本生成段 A1+A4–A8、手写段 A9–A13。
> 参数一律取自源码，行号可直接核对。**标【自动】的段由脚本扫描生成，未人工改写过，可信度最高**。

## 0 覆盖度说明

| 标记 | 含义 | 涉及段 |
|---|---|---|
| 【自动】 | 脚本直接抽取（`scripts/gen_ui_appendix.py`） | A1、A4、A5、A6、A7、A8 |
| 【核对】 | 已逐条对照源码 | A0、A0.5、A2、A3、A9、A10 |
| 【推断】 | 由代码结构推出，未实测 | 少数弹层高度、系统默认值 |

**仍然无法从代码还原的东西**（想在设计稿里对齐，必须实测）：

1. 字体实际渲染：`GoogleFonts.manropeTextTheme()` 运行时联网下载 Manrope，失败时回落系统字体，中文字形完全由系统决定（Windows 上是微软雅黑）。同一份字号在两种字体下字面高度差 1–2px。
2. 系统 DPI 缩放：全库无 `MediaQuery.textScaler` 处理，125% / 150% 缩放下所有 px 值等比例放大，但 `SizedBox` 固定值不会重排，会出现文字溢出。
3. `BackdropFilter` 的模糊在不同显卡驱动下结果不一致。
4. 图标 tree-shaking：release 构建会删除未被 `Icon(常量)` 引用的图标，代码里以变量传入的图标在 release 下可能显示空白（这是已知红线，不在设计范围）。

---

## A0 主题颜色 token（15 个，`lib/shared/theme.dart:4-30`）【核对】

| token | 值 | 建议用途 | 定义位置 |
|---|---|---|---|
| `canvas` | `#F8FAFF` | 页面底色（渐变起点） | theme.dart:5 |
| `canvasTint` | `#EFF7FF` | 页面底色（渐变终点） | theme.dart:6 |
| `surface` | `#FFFFFF` | 卡片 / 输入框底 | theme.dart:7 |
| `surfaceSoft` | `#F0F9FF` | 参数 chip、次级按钮底 | theme.dart:8 |
| `surfaceMuted` | `#E5F2FF` | 分隔、更浅的底 | theme.dart:9 |
| `primary` | `#0E7490` | 主色（按钮、选中、聚焦边） | theme.dart:10 |
| `primaryStrong` | `#005A71` | 主色深（图标、chip 文字） | theme.dart:11 |
| `primarySoft` | `#B9EAFF` | 主色浅（渐变、进度底） | theme.dart:12 |
| `textPrimary` | `#0B1C30` | 正文 | theme.dart:13 |
| `textSecondary` | `#5C7386` | 次要文字 / 时间 | theme.dart:14 |
| `border` | `#D7E7F7` | 描边 | theme.dart:15 |
| `warningSurface` | `#FFF3D9` | 警告底 | theme.dart:16 |
| `warningText` | `#9A6400` | 警告字 | theme.dart:17 |
| `dangerSurface` | `#FFE7E7` | 错误底 | theme.dart:18 |
| `dangerText` | `#AA2E2E` | 错误字 | theme.dart:19 |

> 另有 `colorScheme.error = #BA1A1A`（theme.dart:86），未进入 token 体系，属于重复定义。

## A0.5 语义色（未走 token 的硬编码）【核对】

| 场景 | 背景 | 前景 | 位置 |
|---|---|---|---|
| 状态 pill · 排队/生成中 | `#FFFFFF` @0.92 | `primaryStrong` | image_cell.dart:807-810 |
| 状态 pill · 完成 | `#E4F6EE` @0.94 | `#177245` | image_cell.dart:812-814 |
| 状态 pill · 失败 | `dangerSurface` @0.96 | `dangerText` | image_cell.dart:816-818 |
| 状态 pill · 已取消 | `#FFF0D8` @0.96 | `#935E00` | image_cell.dart:820-822 |
| 状态 pill 投影 | — | `#22000000` blur 10 / offset (0,4) | image_cell.dart:824-831 |
| 日志 chip · 信息 | `surfaceSoft` | `primaryStrong` | request_log_page.dart:227-230 |
| 日志 chip · 请求 | `#E8F3FF` | `#1667C5` | request_log_page.dart:230-231 |
| 日志 chip · 响应 | `#E4F6EE` | `#177245` | request_log_page.dart:234-235 |
| 日志 chip · 错误 | `dangerSurface` | `dangerText` | request_log_page.dart:238-240 |
| 发送按钮禁用 | `#B9C7D4` 双段 | 白 | bottom_input_bar.dart:1553 |
| 空状态图标底色 | `#E0F7FF → #C6EEFF` 对角渐变 | `primary` | empty_state.dart:37-39 |
| 空状态图标投影 | — | `#223EA1D8` blur 30 / offset (0,12) | empty_state.dart:41-46 |

## A2 阴影 / 玻璃 / 渐变 / 模糊【核对】

| 名称 | 类型 | 参数 | 位置 |
|---|---|---|---|
| `softShadow` | BoxShadow | 色 `#140E7490`（主色 8% 透明）、blur **24**、spread **-6**、offset (0,**12**) | theme.dart:26-34 |
| `floatingShadow` | BoxShadow | 色 `#140E7490`、blur **28**、spread **-8**、offset (0,**14**) | theme.dart:35-43 |
| `AppDecorations.card` | 卡片缺省 | 底色 `surface`、描边 `Colors.white` @**0.92** 1px、`softShadow`、缺省圆角 24 | theme.dart:45-57 |
| `AppDecorations.glass` | 玻璃缺省 | 线性渐变 `white @0.88 → white @0.72`（左上→右下）、描边 `white @0.82`、`floatingShadow`、缺省圆角 28 | theme.dart:59-73 |
| 页面背景 | 线性渐变 | `canvas → canvasTint`，topCenter → bottomCenter | home_page.dart:196-198 |
| 背景光斑 ×3 | RadialGradient 圆形 | ①220 @ (top −60, right −40)：`#444FC3F7 → #114FC3F7`<br>②180 @ (top 120, left −70)：`#2281D1F0 → #0081D1F0`<br>③200 @ (bottom 90, right −50)：同 ② | home_page.dart:200-224 |
| 输入栏模糊 | BackdropFilter | `sigmaX = sigmaY = **16**`，外层 ClipRRect 圆角 22，容器尺寸变化动画 **220ms** / `Curves.easeOut` | bottom_input_bar.dart:254-262 |
| 发送按钮 | 线性渐变 | 可用：`primary → primaryStrong`；禁用：`#B9C7D4 → #B9C7D4`；方向默认（水平） | bottom_input_bar.dart:1546-1554 |
| 优化按钮图标 | 三段线性渐变着色 | `#FFC857 → #FF6B6B → #3B82F6`，左上→右下，图标白色 20 | bottom_input_bar.dart:1336-1340 |
| 加载骨架 | 线性渐变 | `surfaceSoft → primarySoft` + 居中 24×24 转圈（线宽 2.4） | image_cell.dart:906-922 |

## A3 字体【核对】

| 项 | 现状 |
|---|---|
| 字体族 | `GoogleFonts.manropeTextTheme()`（theme.dart:90），**运行时联网下载** |
| 中文 | 未指定，全部回落系统（Windows：微软雅黑 / Android：思源黑体） |
| 兜底 | 下载失败时 Manrope 失效，西文也回落到系统字体 |
| 字号体系 | 主文档 §1.3 的 11 档 textTheme + 本附录 A7 的 22 处就地覆盖 |
| 字重 | 400 正文 / 600 label / 700 标题与强调 / 800 两处（AppBar「New」角标、状态 pill） |
| 字距 | headlineLarge −0.6；labelLarge 0.1；labelMedium 0.3；labelSmall 0.4；其余默认 |

> 复刻提示：设计师如果换字体，需要同时给出中英混排的基线，否则中文字面高度会让所有 12–14px 的行高偏移。

---

## A1 / A4–A8 自动抽取段（原样输出，未改写）
> 本附录由 `scripts/gen_ui_appendix.py` 扫描 `lib/**/*.dart` 自动生成，行号可直接定位；重建命令：`python scripts/gen_ui_appendix.py > docs/_appendix_generated.md`。

<!-- GENERATED:START -->

## A1 颜色

### A1.1 全库硬编码色值（不含主题 token）

| 色值 | 出现次数 | 位置（前 6 处） |
|---|---|---|
| `#FF177245` | 3 | lib/features/home/home_page.dart:577、lib/features/image_list/image_cell.dart:814、lib/features/logs/request_log_page.dart:235 |
| `#FFE4F6EE` | 3 | lib/features/home/home_page.dart:570、lib/features/image_list/image_cell.dart:813、lib/features/logs/request_log_page.dart:234 |
| `#FFF8FAFF` | 3 | lib/main.dart:133、lib/main.dart:156、lib/shared/theme.dart:5 |
| `#0081D1F0` | 2 | lib/features/home/home_page.dart:214、lib/features/home/home_page.dart:222 |
| `#140E7490` | 2 | lib/shared/theme.dart:27、lib/shared/theme.dart:36 |
| `#22000000` | 2 | lib/features/image_list/image_cell.dart:624、lib/features/image_list/image_cell.dart:829 |
| `#2281D1F0` | 2 | lib/features/home/home_page.dart:214、lib/features/home/home_page.dart:222 |
| `#FF0B1C30` | 2 | lib/main.dart:164、lib/shared/theme.dart:13 |
| `#FFB9C7D4` | 2 | lib/features/input/bottom_input_bar.dart:1553、lib/features/input/bottom_input_bar.dart:1553 |
| `#114FC3F7` | 1 | lib/features/home/home_page.dart:206 |
| `#223EA1D8` | 1 | lib/shared/widgets/empty_state.dart:42 |
| `#444FC3F7` | 1 | lib/features/home/home_page.dart:206 |
| `#FF005A71` | 1 | lib/shared/theme.dart:11 |
| `#FF0E7490` | 1 | lib/shared/theme.dart:10 |
| `#FF1667C5` | 1 | lib/features/logs/request_log_page.dart:231 |
| `#FF3B82F6` | 1 | lib/features/input/bottom_input_bar.dart:1337 |
| `#FF5C7386` | 1 | lib/shared/theme.dart:14 |
| `#FF935E00` | 1 | lib/features/image_list/image_cell.dart:820 |
| `#FF93D7B5` | 1 | lib/features/home/home_page.dart:572 |
| `#FF9A6400` | 1 | lib/shared/theme.dart:17 |
| `#FFAA2E2E` | 1 | lib/shared/theme.dart:19 |
| `#FFB9EAFF` | 1 | lib/shared/theme.dart:12 |
| `#FFBA1A1A` | 1 | lib/shared/theme.dart:86 |
| `#FFC6EEFF` | 1 | lib/shared/widgets/empty_state.dart:38 |
| `#FFD7E7F7` | 1 | lib/shared/theme.dart:15 |
| `#FFE0F7FF` | 1 | lib/shared/widgets/empty_state.dart:38 |
| `#FFE5F2FF` | 1 | lib/shared/theme.dart:9 |
| `#FFE8F3FF` | 1 | lib/features/logs/request_log_page.dart:230 |
| `#FFEFF7FF` | 1 | lib/shared/theme.dart:6 |
| `#FFF0F9FF` | 1 | lib/shared/theme.dart:8 |
| `#FFFF6B6B` | 1 | lib/features/input/bottom_input_bar.dart:1337 |
| `#FFFFC857` | 1 | lib/features/input/bottom_input_bar.dart:1337 |
| `#FFFFE7E7` | 1 | lib/shared/theme.dart:18 |
| `#FFFFF0D8` | 1 | lib/features/image_list/image_cell.dart:819 |
| `#FFFFF3D9` | 1 | lib/shared/theme.dart:16 |

### A1.2 透明度使用矩阵（`withValues(alpha:)`）

| 基色表达式 | alpha | 次数 | 位置（前 5 处） |
|---|---|---|---|
| `AppThemeTokens.border` | 0.7 | 9 | lib/features/image_list/image_cell.dart:80、lib/features/input/background_selector.dart:80、lib/features/input/bottom_input_bar.dart:1464、lib/features/input/bottom_input_bar.dart:1513、lib/features/input/image_format_selector.dart:28 |
| `Colors.black` | 0.72 | 4 | lib/features/image_list/image_preview_page.dart:325、lib/features/image_list/image_preview_page.dart:347、lib/features/image_list/image_preview_page.dart:804、lib/features/input/attachment_preview_strip.dart:104 |
| `AppThemeTokens.primary` | 0.08 | 3 | lib/features/input/size_picker_modal.dart:279、lib/features/input/size_picker_modal.dart:425、lib/features/input/size_picker_modal.dart:462 |
| `Colors.white` | 0.08 | 3 | lib/features/image_list/image_preview_page.dart:335、lib/features/image_list/image_preview_page.dart:349、lib/features/image_list/image_preview_page.dart:806 |
| `AppThemeTokens.border` | 0.5 | 2 | lib/features/input/size_picker_modal.dart:428、lib/features/input/size_picker_modal.dart:465 |
| `Colors.black` | 0.06 | 2 | lib/features/image_list/image_cell.dart:586、lib/features/input/size_picker_modal.dart:327 |
| `Colors.white` | 0.72 | 2 | lib/features/settings/settings_page.dart:1219、lib/shared/theme.dart:63 |
| `Colors.white` | 0.92 | 2 | lib/features/image_list/image_cell.dart:810、lib/shared/theme.dart:50 |
| `AppThemeTokens.dangerSurface` | 0.96 | 1 | lib/features/image_list/image_cell.dart:816 |
| `AppThemeTokens.primary` | 0.18 | 1 | lib/features/image_list/image_cell.dart:585 |
| `AppThemeTokens.primary` | 0.55 | 1 | lib/features/input/background_selector.dart:79 |
| `AppThemeTokens.primary` | 0.6 | 1 | lib/features/input/size_picker_modal.dart:348 |
| `AppThemeTokens.primarySoft` | 0.55 | 1 | lib/features/input/background_selector.dart:74 |
| `AppThemeTokens.primaryStrong` | 0.88 | 1 | lib/features/image_list/image_preview_page.dart:702 |
| `AppThemeTokens.surface` | 0.86 | 1 | lib/features/image_list/image_cell.dart:877 |
| `AppThemeTokens.surfaceSoft` | 0.72 | 1 | lib/features/favorites/favorite_folder_sheet.dart:314 |
| `AppThemeTokens.textSecondary` | 0.9 | 1 | lib/shared/theme.dart:187 |
| `Colors.black` | 0 | 1 | lib/features/image_list/image_cell.dart:559 |
| `Colors.black` | 0.58 | 1 | lib/features/image_list/image_cell.dart:560 |
| `Colors.black` | 0.62 | 1 | lib/features/image_list/image_preview_page.dart:744 |
| `Colors.white` | 0.7 | 1 | lib/shared/theme.dart:246 |
| `Colors.white` | 0.82 | 1 | lib/shared/theme.dart:66 |
| `Colors.white` | 0.86 | 1 | lib/features/image_list/image_cell.dart:769 |
| `Colors.white` | 0.88 | 1 | lib/shared/theme.dart:62 |
| `colorScheme.primary` | 0.1 | 1 | lib/features/input/quantity_selector.dart:158 |

## A4 图标清单

共 **67** 个不同图标（Material Rounded 家族为主），codepoint 取自 Flutter SDK 的 `icons.dart`。

| # | 图标名 | codepoint | 次数 | 位置（前 4 处） |
|---|---|---|---|---|
| 1 | `Icons.check_circle_rounded` | `0xf635` | 9 | lib/features/favorites/favorite_folder_sheet.dart:336、lib/features/input/background_selector.dart:129、lib/features/input/background_selector.dart:142、lib/features/input/background_selector.dart:160 |
| 2 | `Icons.auto_awesome_rounded` | `0xf596` | 6 | lib/features/image_list/image_cell.dart:129、lib/features/input/bottom_input_bar.dart:1168、lib/features/input/bottom_input_bar.dart:1342、lib/features/input/quality_selector.dart:40 |
| 3 | `Icons.circle_outlined` | `0xef53` | 6 | lib/features/input/background_selector.dart:130、lib/features/input/background_selector.dart:142、lib/features/input/background_selector.dart:161、lib/features/input/bottom_input_bar.dart:911 |
| 4 | `Icons.close_rounded` | `0xf647` | 6 | lib/features/favorites/favorite_folder_sheet.dart:198、lib/features/home/home_page.dart:106、lib/features/home/home_page.dart:172、lib/features/image_list/image_cell.dart:380 |
| 5 | `Icons.add_rounded` | `0xf537` | 4 | lib/features/favorites/favorite_folder_sheet.dart:153、lib/features/settings/api_profile_edit_page.dart:246、lib/features/settings/settings_page.dart:111、lib/features/settings/settings_page.dart:163 |
| 6 | `Icons.broken_image_rounded` | `0xf5ec` | 4 | lib/features/favorites/favorite_folder_sheet.dart:461、lib/features/image_list/image_cell.dart:267、lib/features/image_list/image_preview_page.dart:488、lib/features/image_list/image_preview_page.dart:507 |
| 7 | `Icons.check_rounded` | `0xf636` | 4 | lib/features/favorites/favorite_folder_sheet.dart:191、lib/features/image_list/image_cell.dart:631、lib/features/input/bottom_input_bar.dart:1016、lib/features/input/selector_button.dart:38 |
| 8 | `Icons.delete_rounded` | `0xf697` | 4 | lib/features/home/home_page.dart:98、lib/features/image_list/image_cell.dart:398、lib/features/settings/settings_page.dart:91、lib/features/settings/settings_page.dart:138 |
| 9 | `Icons.phone_iphone` | `0xe4aa` | 4 | lib/features/input/size_picker_modal.dart:90、lib/features/input/size_picker_modal.dart:91、lib/features/input/size_picker_modal.dart:92、lib/features/input/size_picker_modal.dart:93 |
| 10 | `Icons.refresh_rounded` | `0xf00e9` | 4 | lib/features/image_list/image_cell.dart:323、lib/features/image_list/image_cell.dart:332、lib/features/image_list/image_cell.dart:390、lib/features/logs/request_log_page.dart:50 |
| 11 | `Icons.aspect_ratio_rounded` | `0xf581` | 3 | lib/features/image_list/image_cell.dart:125、lib/features/input/size_picker_modal.dart:9、lib/features/input/size_selector.dart:54 |
| 12 | `Icons.edit_rounded` | `0xf6fb` | 3 | lib/features/image_list/image_cell.dart:341、lib/features/settings/settings_page.dart:1302、lib/features/settings/settings_page.dart:1430 |
| 13 | `Icons.tablet_mac` | `0xe63f` | 3 | lib/features/input/size_picker_modal.dart:94、lib/features/input/size_picker_modal.dart:95、lib/features/input/size_picker_modal.dart:96 |
| 14 | `Icons.timer_outlined` | `0xf44a` | 3 | lib/features/image_list/image_cell.dart:660、lib/features/image_list/image_cell.dart:673、lib/features/settings/settings_page.dart:1511 |
| 15 | `Icons.arrow_upward_rounded` | `0xf57e` | 2 | lib/features/input/bottom_input_bar.dart:841、lib/features/input/bottom_input_bar.dart:1574 |
| 16 | `Icons.cloud_download_rounded` | `0xf64d` | 2 | lib/features/settings/api_profile_edit_page.dart:261、lib/features/settings/settings_page.dart:1037 |
| 17 | `Icons.hub_rounded` | `0xf0335` | 2 | lib/features/input/bottom_input_bar.dart:807、lib/features/input/bottom_input_bar.dart:1471 |
| 18 | `Icons.image_not_supported_rounded` | `0xf80c` | 2 | lib/features/favorites/favorite_folder_sheet.dart:455、lib/features/image_list/image_cell.dart:263 |
| 19 | `Icons.info_outline_rounded` | `0xf815` | 2 | lib/features/image_list/image_preview_page.dart:337、lib/features/settings/settings_page.dart:901 |
| 20 | `Icons.key_off_rounded` | `0xf0342` | 2 | lib/features/input/bottom_input_bar.dart:840、lib/features/input/bottom_input_bar.dart:923 |
| 21 | `Icons.phone_android` | `0xe4a3` | 2 | lib/features/input/size_picker_modal.dart:97、lib/features/input/size_picker_modal.dart:98 |
| 22 | `Icons.receipt_long_rounded` | `0xf00e1` | 2 | lib/features/logs/request_log_page.dart:125、lib/features/settings/settings_page.dart:52 |
| 23 | `Icons.search_rounded` | `0xf013d` | 2 | lib/features/home/home_page.dart:134、lib/features/home/home_page.dart:166 |
| 24 | `Icons.settings_rounded` | `0xf0164` | 2 | lib/features/home/home_page.dart:142、lib/shared/widgets/empty_state.dart:86 |
| 25 | `Icons.smart_toy_outlined` | `0xf3a8` | 2 | lib/features/input/bottom_input_bar.dart:1003、lib/features/input/bottom_input_bar.dart:1520 |
| 26 | `Icons.star_border_rounded` | `0xf01cf` | 2 | lib/features/home/home_page.dart:124、lib/features/image_list/image_cell.dart:368 |
| 27 | `Icons.star_rounded` | `0xf01d4` | 2 | lib/features/home/home_page.dart:123、lib/features/image_list/image_cell.dart:194 |
| 28 | `Icons.visibility_off_rounded` | `0xf0292` | 2 | lib/features/settings/api_profile_edit_page.dart:161、lib/features/settings/prompt_optimization_profile_edit_page.dart:191 |
| 29 | `Icons.visibility_rounded` | `0xf0293` | 2 | lib/features/settings/api_profile_edit_page.dart:160、lib/features/settings/prompt_optimization_profile_edit_page.dart:190 |
| 30 | `Icons.add_photo_alternate_rounded` | `0xf534` | 1 | lib/features/image_list/image_cell.dart:350 |
| 31 | `Icons.api_rounded` | `0xf568` | 1 | lib/features/image_list/image_cell.dart:133 |
| 32 | `Icons.arrow_drop_down_rounded` | `0xf577` | 1 | lib/features/settings/model_name_field.dart:58 |
| 33 | `Icons.attach_file_rounded` | `0xf58e` | 1 | lib/features/input/bottom_input_bar.dart:1426 |
| 34 | `Icons.auto_awesome_motion_rounded` | `0xf595` | 1 | lib/features/settings/settings_page.dart:71 |
| 35 | `Icons.auto_fix_high_rounded` | `0xf598` | 1 | lib/features/settings/settings_page.dart:118 |
| 36 | `Icons.brush_rounded` | `0xf5ef` | 1 | lib/features/input/size_picker_modal.dart:15 |
| 37 | `Icons.chevron_left_rounded` | `—` | 1 | lib/features/image_list/image_preview_page.dart:136 |
| 38 | `Icons.chevron_right_rounded` | `—` | 1 | lib/features/image_list/image_preview_page.dart:149 |
| 39 | `Icons.close_fullscreen_rounded` | `0xf646` | 1 | lib/features/image_list/image_preview_page.dart:385 |
| 40 | `Icons.cloud_download_outlined` | `0xef60` | 1 | lib/features/settings/model_name_field.dart:52 |
| 41 | `Icons.cloud_sync_rounded` | `0xf02e8` | 1 | lib/features/settings/settings_page.dart:986 |
| 42 | `Icons.cloud_upload_rounded` | `0xf651` | 1 | lib/features/settings/settings_page.dart:1032 |
| 43 | `Icons.code_rounded` | `0xf653` | 1 | lib/features/settings/settings_page.dart:920 |
| 44 | `Icons.copy_rounded` | `0xf66c` | 1 | lib/features/image_list/image_cell.dart:359 |
| 45 | `Icons.delete_sweep_rounded` | `0xf698` | 1 | lib/features/settings/settings_page.dart:202 |
| 46 | `Icons.description_rounded` | `0xf69b` | 1 | lib/features/input/size_picker_modal.dart:14 |
| 47 | `Icons.download_rounded` | `0xf6df` | 1 | lib/features/image_list/image_preview_page.dart:119 |
| 48 | `Icons.filter_1_rounded` | `0xf74b` | 1 | lib/features/image_list/image_cell.dart:143 |
| 49 | `Icons.image_not_supported_outlined` | `—` | 1 | lib/features/input/attachment_preview_strip.dart:88 |
| 50 | `Icons.image_rounded` | `0xf80d` | 1 | lib/features/input/image_format_selector.dart:35 |
| 51 | `Icons.keyboard_arrow_down_rounded` | `0xf82b` | 1 | lib/features/input/selector_button.dart:74 |
| 52 | `Icons.layers_rounded` | `0xf847` | 1 | lib/features/input/quantity_selector.dart:35 |
| 53 | `Icons.monitor_rounded` | `0xf8d3` | 1 | lib/features/input/size_picker_modal.dart:12 |
| 54 | `Icons.more_horiz_rounded` | `0xf8d9` | 1 | lib/features/image_list/image_cell.dart:532 |
| 55 | `Icons.network_check_rounded` | `0xf8fc` | 1 | lib/features/settings/prompt_optimization_profile_edit_page.dart:222 |
| 56 | `Icons.open_in_new_rounded` | `—` | 1 | lib/features/settings/settings_page.dart:1118 |
| 57 | `Icons.phone_iphone_rounded` | `0xf007f` | 1 | lib/features/input/size_picker_modal.dart:13 |
| 58 | `Icons.photo_camera_rounded` | `0xf008d` | 1 | lib/features/input/size_picker_modal.dart:10 |
| 59 | `Icons.photo_size_select_actual_rounded` | `—` | 1 | lib/features/image_list/image_cell.dart:690 |
| 60 | `Icons.restore_page_rounded` | `0xf010a` | 1 | lib/features/settings/settings_page.dart:1022 |
| 61 | `Icons.sell_outlined` | `0xf353` | 1 | lib/features/settings/settings_page.dart:914 |
| 62 | `Icons.settings_input_component_rounded` | `—` | 1 | lib/features/settings/settings_page.dart:1027 |
| 63 | `Icons.tv_rounded` | `0xf025d` | 1 | lib/features/input/size_picker_modal.dart:11 |
| 64 | `Icons.upload_file_rounded` | `0xf026a` | 1 | lib/features/settings/settings_page.dart:1017 |
| 65 | `Icons.visibility_off_outlined` | `0xf4a0` | 1 | lib/features/settings/settings_page.dart:461 |
| 66 | `Icons.visibility_outlined` | `0xf4a1` | 1 | lib/features/settings/settings_page.dart:462 |
| 67 | `Icons.wallpaper_rounded` | `0xf029f` | 1 | lib/features/input/background_selector.dart:88 |

## A5 文案清单（含中文的字符串字面量）

共 **524** 处中文文案，去重后 **408** 条。按文件分组，行号可定位。

### lib/app.dart（5 条）

| 行 | 文案 |
|---|---|
| 61 | 大川生图工具 |
| 115 | 确认退出？ |
| 116 | 当前仍有图片正在生成，退出会中断这些任务。 |
| 120 | 继续生成 |
| 124 | 退出 |

### lib/core/api/image_edit_api.dart（6 条）

| 行 | 文案 |
|---|---|
| 25 | 图生图请求缺少附件。 |
| 178 | RightAPI 异步提交未返回 task_id。 |
| 193 | RightAPI 任务失败：${error[ |
| 195 | RightAPI 任务失败。 |
| 198 | RightAPI 异步任务轮询超时。 |
| 204 | 接口响应缺少图片数据。 |

### lib/core/api/image_generation_api.dart（5 条）

| 行 | 文案 |
|---|---|
| 210 | RightAPI 异步提交未返回 task_id。 |
| 232 | RightAPI 异步任务轮询超时。 |
| 244 | RightAPI 任务失败：${error[ |
| 246 | RightAPI 任务失败。 |
| 252 | 接口响应缺少图片数据。 |

### lib/core/api/model_list_api.dart（10 条）

| 行 | 文案 |
|---|---|
| 22 | API Key 为空，无法获取模型列表。 |
| 103 | 请求地址: $url\n |
| 104 | 超时: $timeoutSeconds 秒 |
| 124 | 耗时: ${stopwatch.elapsedMilliseconds} ms\n |
| 125 | 状态码: ${response.statusCode ?? |
| 126 | 响应体:\n${_summarizeData(normalized)} |
| 137 | 错误: $message\n |
| 138 | 响应体:\n${_summarizeData(error.response?.data)} |
| 166 | 模型列表为空。 |
| 258 | (空) |

### lib/core/api/openai_client.dart（23 条）

| 行 | 文案 |
|---|---|
| 50 | 请求地址: ${_dio.options.baseUrl}$path\n |
| 51 | 超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n |
| 52 | 请求体:\n${_prettyJson(body)} |
| 67 | 耗时: ${stopwatch.elapsedMilliseconds} ms\n |
| 68 | 状态码: ${response.statusCode ?? |
| 69 | 响应体:\n${_summarizeData(response.data)} |
| 80 | 错误: $message\n |
| 81 | 响应体:\n${_summarizeData(error.response?.data)} |
| 134 | 请求体:\n${_prettyJson(streamBody)} |
| 164 | 流式响应，Images API，收到最终图片: $receivedImage |
| 175 | 流式响应，Responses API，收到 $outputCount 个图片结果 |
| 215 | 表单字段:\n${_prettyJson(_fieldsMap(formData))}\n |
| 216 | 上传文件:\n${_fileSummary(formData)} |
| 338 | 接口返回了空响应。 |
| 339 | 接口返回了无法解析的内容：${_truncate(preview, 300)} |
| 495 | 请求超时，请检查超时设置或稍后重试。 |
| 497 | 网络连接失败，请检查网络或 Base URL。 |
| 499 | 证书校验失败，请检查 HTTPS 配置。 |
| 501 | 请求失败，请检查接口返回。 |
| 503 | 请求已取消。 |
| 507 | 请求失败，请稍后重试。 |
| 527 | (无) |
| 532 | (空) |

### lib/core/api/prompt_optimization_api.dart（36 条）

| 行 | 文案 |
|---|---|
| 11 | 强化 |
| 11 | 补足主体、构图、光影、材质和细节，让提示词更稳定。 |
| 12 | 探索边界 |
| 12 | 识别当前方向，在合规范围内增强冲击力和张力。 |
| 13 | 强化后转为英文 |
| 13 | 先强化画面表达，再转写为自然英文提示词。 |
| 14 | 转为文言文 |
| 14 | 保留画面意图，转为凝练的文言风格表达。 |
| 15 | 诗意强化 |
| 15 | 强化画面感，并加入更具诗性的氛围与意象。 |
| 37 | 提示词优化 API Key 为空。 |
| 55 | 提示词优化接口没有返回有效文本。 |
| 233 | 请求地址: $url\n |
| 234 | 超时: $timeoutSeconds 秒\n |
| 235 | 请求体:\n${_prettyJson(body)} |
| 269 | 耗时: ${stopwatch.elapsedMilliseconds} ms\n |
| 270 | 状态码: ${response.statusCode ?? |
| 271 | 响应体:\n${_summarizeData(responseData)} |
| 283 | 错误: $message\n |
| 424 | OpenAI Chat 响应缺少文本内容。 |
| 454 | OpenAI Responses 响应缺少文本内容。 |
| 463 | Claude 响应缺少文本内容。 |
| 480 | Gemini 响应缺少文本内容。 |
| 524 | 强化主体、构图、镜头语言、光影、色彩、材质、环境和细节。 |
| 526 | 识别原提示词的创作方向，在合法合规、安全表达范围内提升戏剧张力、风格辨识度和视觉冲击力。 |
| 528 | 先强化画面表达，再转写为自然、专业、可直接用于图像生成模型的英文提示词。 |
| 530 | 保持原始画面意图，转写为凝练、古雅、可读性好的文言风格中文提示词。 |
| 531 | 强化画面细节，同时加入诗意意象、氛围层次和更细腻的审美描述。 |
| 534 | 你是专业的图像生成提示词优化器。 |
| 535 | 你的任务是根据用户的原始提示词输出一段更适合图像生成的提示词。 |
| 537 | 不要添加违法、露骨色情、仇恨、暴力伤害或规避安全规则的内容。 |
| 538 | 只输出优化后的提示词正文，不要解释、不要标题、不要 Markdown。 |
| 545 | 优化方向：${direction.label}\n |
| 546 | 原始提示词：\n$prompt\n\n |
| 547 | 请直接返回优化后的提示词。 |
| 583 | (空) |

### lib/core/api/responses_image_api.dart（2 条）

| 行 | 文案 |
|---|---|
| 55 | Responses API 没有返回 output 图片结果。 |
| 78 | Responses API 返回成功，但没有找到 image_generation_call 图片结果。 |

### lib/core/models/favorite_folder.dart（1 条）

| 行 | 文案 |
|---|---|
| 4 | 默认 |

### lib/core/models/generation_request.dart（19 条）

| 行 | 文案 |
|---|---|
| 2 | 自动 |
| 3 | 方形成图 1K |
| 4 | 竖版海报 |
| 5 | 横版海报 |
| 6 | 竖屏故事 9:16 |
| 7 | 视频封面 16:9 |
| 8 | 宽屏展示 2K |
| 9 | 高清竖图 2K |
| 10 | 高清方图 2K |
| 11 | 高清竖图 4K |
| 12 | 宽屏展示 4K |
| 13 | 自定义 |
| 32 | 低 |
| 33 | 中 |
| 34 | 高 |
| 38 | 超高 |
| 39 | 最高 |
| 80 | 透明 |
| 81 | 不透明 |

### lib/core/models/image_record.dart（6 条）

| 行 | 文案 |
|---|---|
| 4 | 排队中 |
| 5 | 生成中 |
| 6 | 已完成 |
| 7 | 失败 |
| 8 | 已取消 |
| 105 | 自动 |

### lib/core/models/settings_model.dart（2 条）

| 行 | 文案 |
|---|---|
| 98 | 默认 |
| 257 | 提示词优化 |

### lib/core/providers/generation_provider.dart（2 条）

| 行 | 文案 |
|---|---|
| 71 | 当前 API 配置不存在，请重新选择。 |
| 230 | 接口已返回成功，但没有可展示的图片数据。 |

### lib/core/providers/settings_provider.dart（2 条）

| 行 | 文案 |
|---|---|
| 58 | 配置 $nextIndex |
| 157 | 优化配置 $nextIndex |

### lib/core/services/background_generation_service.dart（2 条）

| 行 | 文案 |
|---|---|
| 41 | 大川生图工具 |
| 42 | 生成任务运行中 |

### lib/core/services/backup_service.dart（9 条）

| 行 | 文案 |
|---|---|
| 97 | $warningLabel 文件不存在：${source.path} |
| 117 | 生成结果 ${record.id} |
| 138 | 源附件 ${record.id} #${index + 1} |
| 214 | 备份文件不存在。 |
| 220 | 这不是 大川生图工具 的备份文件。 |
| 223 | 备份格式版本不支持。 |
| 378 | 备份文件缺少 $path。 |
| 383 | 无法读取 $path。 |
| 388 | $path 格式不正确。 |

### lib/core/services/image_clipboard_service.dart（3 条）

| 行 | 文案 |
|---|---|
| 20 | 当前平台不支持复制图片。 |
| 43 | 读取剪贴板图片失败。 |
| 70 | 这条记录没有可复制的图片。 |

### lib/core/services/image_save_service.dart（3 条）

| 行 | 文案 |
|---|---|
| 26 | 没有可保存的图片文件。 |
| 41 | 保存图片 |
| 68 | 下载图片失败，状态码 ${response.statusCode}。 |

### lib/core/services/notification_service.dart（6 条）

| 行 | 文案 |
|---|---|
| 13 | 大川生图工具 生成结果 |
| 14 | 生成任务完成后的本地通知 |
| 111 | 生成完成 |
| 111 | 生成失败 |
| 114 | 请求失败，请稍后重试。 |
| 119 | $body · 已自动退化为单图 |

### lib/core/services/webdav_backup_service.dart（10 条）

| 行 | 文案 |
|---|---|
| 37 | WebDAV 认证失败，请检查用户名和密码。 |
| 40 | WebDAV 地址不存在，请检查地址。 |
| 45 | WebDAV 连接测试失败，状态码 ${status ?? |
| 54 | 备份文件不存在。 |
| 71 | 上传 WebDAV 失败，状态码 ${response.statusCode ?? |
| 92 | WebDAV 上还没有备份文件。 |
| 96 | 下载 WebDAV 备份失败，状态码 ${response.statusCode ?? |
| 102 | WebDAV 备份文件为空。 |
| 133 | 创建 WebDAV 目录失败，状态码 ${status ?? |
| 162 | 请先配置 WebDAV 地址和远端目录。 |

### lib/features/favorites/favorite_folder_sheet.dart（12 条）

| 行 | 文案 |
|---|---|
| 82 | 收藏到 |
| 82 | 收藏夹 |
| 91 | 将结果收藏到： |
| 156 | 新建收藏夹 |
| 183 | 收藏夹名称 |
| 190 | 创建 |
| 197 | 取消 |
| 239 | 名称不能为空，也不能和已有收藏夹重复。 |
| 265 | 删除收藏夹 |
| 266 | 确认删除“${folder.title}”？其中的生成结果不会被删除。 |
| 274 | 删除 |
| 370 | 暂无收藏 |

### lib/features/home/home_page.dart（25 条）

| 行 | 文案 |
|---|---|
| 78 | 大川生图工具 |
| 88 | 生成与改图工作台 |
| 88 | 先完成 API 配置即可开始使用 |
| 96 | 删除选中图像 |
| 104 | 取消选择 |
| 110 | 选择 |
| 116 | 显示全部 |
| 116 | 选择收藏夹 |
| 131 | 关闭搜索 |
| 131 | 搜索提示词 |
| 140 | 设置 |
| 165 | 搜索 Prompt |
| 170 | 清空搜索 |
| 272 | 请先设置 API Key |
| 274 | 先在设置页补充 Base URL、模型名和 Key，然后就可以从底部输入框直接开始生成。 |
| 275 | 前往设置 |
| 472 | 删除图像 |
| 473 | 确认删除这 $selectedCount 个图像？ |
| 477 | 取消 |
| 481 | 删除 |
| 525 | 发现新版本 |
| 527 | 有新的版本 ${updateState.latestVersion ?? |
| 527 | }，请前往 ${AppVersion.repositoryUrl} 下载。 |
| 532 | 知道了 |
| 551 | 无法打开下载页：${updateState.releaseUrl} |

### lib/features/image_list/image_cell.dart（19 条）

| 行 | 文案 |
|---|---|
| 144 | 单图 |
| 277 | 查看失败原因 |
| 324 | 复用提示词 |
| 333 | 再生成一张 |
| 342 | 以此改图 |
| 351 | 将此图添加到附件${currentAttachmentCount + 1} |
| 360 | 复制图片到剪贴板 |
| 371 | 收藏到... |
| 381 | 取消当前请求 |
| 391 | 重试本次请求 |
| 399 | 删除这条记录 |
| 446 | 已复制图片到剪贴板。 |
| 460 | 复制图片失败：$error |
| 468 | 没有记录到具体失败原因。 |
| 475 | 失败原因 |
| 480 | 关闭 |
| 507 | 未知 |
| 530 | 更多操作 |
| 892 | 正在生成 |

### lib/features/image_list/image_list_widget.dart（6 条）

| 行 | 文案 |
|---|---|
| 86 | 还没有生成记录 |
| 87 | 输入提示词并点击发送后，新的生成任务会立即出现在这里。 |
| 106 | 没有匹配结果 |
| 107 | $activeFavoriteFolderTitle 没有内容 |
| 109 | 换一个提示词关键词再试试。 |
| 110 | 从生成结果菜单添加收藏，或在这个收藏夹中直接生成新图片。 |

### lib/features/image_list/image_preview_page.dart（9 条）

| 行 | 文案 |
|---|---|
| 117 | 保存到本地 |
| 135 | 上一张 |
| 148 | 下一张 |
| 381 | 收起 |
| 523 | 实际尺寸${width}x$height |
| 650 | 已取消保存。 |
| 656 | 图片已保存到：$savedPath |
| 663 | 保存失败：$error |
| 770 | 实际尺寸-- |

### lib/features/input/background_selector.dart（13 条）

| 行 | 文案 |
|---|---|
| 48 | 当前模型不支持透明背景 |
| 50 | JPEG 没有透明通道，请改用 PNG 或 WEBP |
| 57 | 背景：自动由模型决定，透明需要 PNG / WEBP，不透明是纯实底 |
| 66 | $_tooltip（当前模型为预览支持） |
| 93 | 背景 |
| 119 | 选择背景 |
| 135 | 自动 |
| 136 | 不指定背景，由模型自己决定（通常是实底） |
| 147 | 透明 |
| 150 | 背景镂空，只保留主体（需 PNG / WEBP） |
| 151 | 不可用：$_unsupportedReason |
| 166 | 不透明 |
| 167 | 明确要求纯实底背景 |

### lib/features/input/bottom_input_bar.dart（28 条）

| 行 | 文案 |
|---|---|
| 132 | 这条记录没有可加入附件的本地图片。 |
| 141 | 图片文件不存在，无法加入附件。 |
| 344 | 描述你想生成的画面 |
| 345 | 描述你想如何修改这些图片 |
| 505 | 当前配置缺少 API Key，发送按钮已禁用。 |
| 506 | 当前配置缺少 API Key，可长按发送切换其他配置。 |
| 623 | 剪贴板图片文件不存在，无法加入附件。 |
| 627 | 已忽略 1 张超过 25MB 的剪贴板图片。 |
| 675 | 已忽略 ${oversized.length} 张超过 25MB 的图片。 |
| 696 | 当前 API 配置不存在，请重新选择。 |
| 701 | 请先在设置中填写 API Key。 |
| 706 | 提示词不能为空。 |
| 761 | 没有其他生图 API 配置。 |
| 781 | 切换到API配置并发送 |
| 899 | 切换生图 API |
| 958 | 当前生图 API 未配置模型。 |
| 982 | 切换模型 |
| 1012 | 当前使用 |
| 1028 | 当前 API 只配置了一个模型，可在设置里添加更多。 |
| 1065 | 「${previous.label}」画质仅 gpt-image-2.5 支持，已回退到「${coerced.label}」。 |
| 1105 | 当前提示词优化配置缺少 API Key。 |
| 1142 | 优化方向 |
| 1226 | 提示词优化配置已不存在。 |
| 1382 | 停止优化 |
| 1382 | 优化提示词 |
| 1412 | 添加图片 |
| 1478 | 渠道 |
| 1526 | 模型 |

### lib/features/input/image_format_selector.dart（1 条）

| 行 | 文案 |
|---|---|
| 40 | 格式 |

### lib/features/input/quality_selector.dart（2 条）

| 行 | 文案 |
|---|---|
| 45 | 质量 |
| 79 | 仅 gpt-image-2.5 支持 |

### lib/features/input/quantity_selector.dart（4 条）

| 行 | 文案 |
|---|---|
| 40 | 数量 |
| 102 | 生成数量 |
| 126 | 取消 |
| 130 | 确定 |

### lib/features/input/size_picker_modal.dart（46 条）

| 行 | 文案 |
|---|---|
| 9 | 通用比例 |
| 10 | 照片 |
| 11 | 屏幕/视频 |
| 13 | 移动设备 |
| 14 | 打印 |
| 15 | 图稿与插画 |
| 60 | 横向 3:2 |
| 61 | 纵向 2:3 |
| 62 | 横向 7:5 |
| 63 | 纵向 5:7 |
| 64 | 横向 10:8 |
| 65 | 纵向 8:10 |
| 66 | 横向 3:2 高清 |
| 67 | 纵向 2:3 高清 |
| 74 | 竖屏 9:16 |
| 75 | 竖屏 2K |
| 76 | 竖屏 4K |
| 97 | Android 常见 |
| 98 | Android 大屏 |
| 101 | 名片 |
| 102 | 明信片 4×6" |
| 106 | 海报 18×24" |
| 109 | 方形 1K |
| 110 | 方形 2K |
| 111 | 方形 Max |
| 112 | Instagram 方形 |
| 113 | Instagram 竖版 |
| 114 | 社交封面 3:1 |
| 115 | 横幅 2:1 |
| 116 | 竖幅 1:2 |
| 213 | 宽高须为 16 的倍数 |
| 214 | 单边最大 3840px |
| 216 | 总像素不能少于 655,360 |
| 217 | 总像素不能超过 8,294,400 |
| 219 | 长短边比例不能超过 3:1 |
| 270 | 设置图像尺寸 |
| 283 | 自动 |
| 306 | 预设 |
| 309 | 自定义 |
| 351 | 由模型自动决定尺寸 |
| 358 | 不传递尺寸参数，由模型根据内容自行选择 |
| 528 | 宽度 |
| 544 | 高度 |
| 564 | 宽高须为16的倍数 · 单边≤3840 · 总像素≤8,294,400 · 比例≤3:1 |
| 585 | 取消 |
| 600 | 确定 |

### lib/features/input/size_selector.dart（2 条）

| 行 | 文案 |
|---|---|
| 60 | 尺寸 |
| 61 | 自动 |

### lib/features/logs/log_viewer_app.dart（1 条）

| 行 | 文案 |
|---|---|
| 49 | 请求日志 |

### lib/features/logs/request_log_page.dart（9 条）

| 行 | 文案 |
|---|---|
| 45 | 请求日志 |
| 48 | 刷新 |
| 72 | 暂无请求日志 |
| 73 | 发起一次生成或改图请求后，这里会显示详细的请求与响应记录。 |
| 130 | 最近 $count 条请求日志 |
| 228 | 信息 |
| 232 | 请求 |
| 236 | 响应 |
| 240 | 错误 |

### lib/features/settings/api_profile_edit_page.dart（34 条）

| 行 | 文案 |
|---|---|
| 43 | 配置 ${settings.profiles.length + 1} |
| 81 | 新增配置 |
| 81 | 编辑配置 |
| 101 | 连接信息 |
| 104 | 这里维护 Base URL、多个模型、API Key 与生图 API。保存后可在主页底部切换 API 与模型。 |
| 112 | 名称 |
| 115 | 请输入名称 |
| 126 | 请输入 Base URL |
| 140 | 最终生成接口：$finalUrl |
| 169 | 生图 API |
| 195 | 流式请求 |
| 197 | 启用后发送 stream: true，可降低超时风险 |
| 204 | 模型名（可多选，主页可在其中切换） |
| 209 | 至少保留一个模型。主页底部展示的模型都来自这里。 |
| 236 | 模型名 |
| 237 | 输入模型名后点添加 |
| 247 | 添加 |
| 262 | 获取中… |
| 262 | 获取模型列表 |
| 268 | 保存 |
| 281 | 请至少添加一个模型。 |
| 325 | 请输入 Base URL 后再获取模型列表。 |
| 329 | 请输入 API Key 后再获取模型列表。 |
| 346 | 配置 |
| 365 | 已获取 ${models.length} 个模型。 |
| 369 | 获取模型列表失败：${error.message} |
| 373 | 获取模型列表失败：$error |
| 392 | 模型 $value 已在列表中。 |
| 404 | 至少保留一个模型 |
| 418 | 请先获取模型列表。 |
| 429 | 选择模型 |
| 443 | 全选 |
| 479 | 取消 |
| 483 | 确定 |

### lib/features/settings/model_name_field.dart（4 条）

| 行 | 文案 |
|---|---|
| 37 | 模型名 |
| 44 | 正在获取模型列表 |
| 44 | 获取模型列表 |
| 55 | 展开模型列表 |

### lib/features/settings/prompt_optimization_profile_edit_page.dart（26 条）

| 行 | 文案 |
|---|---|
| 49 | 优化配置 ${settings.promptOptimizationProfiles.length + 1} |
| 77 | 新增提示词优化 API |
| 77 | 编辑提示词优化 API |
| 98 | 连接信息 |
| 101 | 这里维护提示词优化专用的协议、Base URL、模型名与 API Key。 |
| 109 | 协议类型 |
| 142 | 名称 |
| 145 | 请输入名称 |
| 156 | 请输入 Base URL |
| 170 | 最终请求接口：$finalUrl |
| 204 | 请输入模型名 |
| 213 | 保存 |
| 223 | 测试中... |
| 223 | 测试连通性 |
| 318 | 请输入 Base URL 后再获取模型列表。 |
| 322 | 请输入 API Key 后再获取模型列表。 |
| 339 | 提示词优化 |
| 361 | 已获取 ${models.length} 个模型。 |
| 364 | 获取模型列表失败：${error.message} |
| 368 | 获取模型列表失败：$error |
| 387 | 请输入 API Key 后再测试。 |
| 409 | 一只白猫坐在雨后的窗边 |
| 423 | 连通性测试成功 |
| 428 | 知道了 |
| 438 | 连通性测试失败：${error.message} |
| 443 | 连通性测试失败：$error |

### lib/features/settings/settings_page.dart（70 条）

| 行 | 文案 |
|---|---|
| 32 | 设置 |
| 53 | 请求日志 |
| 54 | 查看当前进程记录的请求、响应和错误详情。 |
| 55 | 查看日志 |
| 72 | 生图API |
| 92 | 删除 |
| 112 | 添加生图 API |
| 118 | 提示词优化API |
| 121 | 还没有提示词优化 API。添加后，首页输入框右侧会启用提示词优化。 |
| 164 | 添加提示词优化 API |
| 174 | 清除历史记录 |
| 175 | 这会删除所有生成记录，但不会清除 API 配置。 |
| 179 | 取消 |
| 183 | 确认清除 |
| 200 | 历史记录已清空。 |
| 254 | 请求超时（秒） |
| 264 | 超时时间 |
| 265 | 秒 |
| 271 | 默认 600 秒。生成较慢时可以适当调高。 |
| 286 | 请输入大于 0 的整数 |
| 293 | 保存 |
| 318 | 导出备份 |
| 326 | 正在生成备份... |
| 347 | 备份已导出：${p.basename(savedPath)} |
| 362 | 选择备份文件 |
| 377 | 文件 |
| 385 | 正在恢复备份... |
| 431 | WebDAV 设置 |
| 439 | WebDAV 地址 |
| 446 | 用户名 |
| 453 | 密码 |
| 455 | 隐藏密码 |
| 455 | 显示密码 |
| 471 | 远端目录 |
| 505 | 请填写有效的 WebDAV 地址和远端目录。 |
| 513 | 正在测试连接... |
| 532 | 连接成功。 |
| 545 | 测试中... |
| 545 | 测试连接 |
| 606 | 请先配置 WebDAV。 |
| 613 | 同步到 WebDAV |
| 623 | 正在同步到 WebDAV... |
| 637 | 已同步到 WebDAV。 |
| 666 | 正在从 WebDAV 恢复... |
| 696 | 无法读取备份文件。 |
| 717 | 恢复完成。安全快照：${p.basename(result.safetyBackup.path)} |
| 731 | 备份会包含 API Key、WebDAV 密码等敏感配置。当前版本不会加密备份文件，请确认只保存到可信位置。 |
| 740 | 继续 |
| 756 | 从$source恢复 |
| 757 | 恢复会替换当前设置、历史记录、收藏夹和应用内图片文件。恢复前会自动生成一份安全快照。 |
| 765 | 确认恢复 |
| 822 | 备份提示（${warnings.length}） |
| 832 | 知道了 |
| 853 | 操作失败：$error |
| 906 | 关于 大川生图工具 |
| 915 | 版本 |
| 921 | 开源地址 |
| 944 | 无法打开 GitHub 地址。 |
| 969 | 未配置 |
| 994 | 数据备份与恢复 |
| 1018 | 导出到文件 |
| 1023 | 从文件恢复 |
| 1038 | 从 WebDAV 恢复 |
| 1292 | 使用中 |
| 1300 | 编辑 |
| 1348 | 模型：${profile.model} 等 ${profile.models.length} 个模型 |
| 1349 | 模型：${profile.model} |
| 1518 | 请求超时 |
| 1525 | $timeoutSeconds 秒 |
| 1535 | 修改 |

### lib/main.dart（1 条）

| 行 | 文案 |
|---|---|
| 161 | 大川生图工具 启动失败\n$error |

### lib/shared/widgets/empty_state.dart（2 条）

| 行 | 文案 |
|---|---|
| 77 | 支持文生图 |
| 78 | 支持多图改图 |

## A6 动画时长与曲线

| 时长（ms） | 次数 |
|---|---|
| 180 | 4 |
| 120 | 2 |
| 220 | 2 |
| 240 | 1 |
| 900 | 1 |

| 曲线 | 次数 |
|---|---|
| `Curves.easeOut` | 2 |
| `Curves.easeOutBack` | 1 |
| `Curves.easeInCubic` | 1 |
| `Curves.easeOutCubic` | 1 |

## A7 就地字号覆盖（`fontSize:`）

| 字号 | 次数 | 位置（前 6 处） |
|---|---|---|
| 10 | 4 | lib/features/home/home_page.dart:578、lib/features/image_list/image_cell.dart:784、lib/features/image_list/image_cell.dart:841、lib/features/input/size_picker_modal.dart:508 |
| 11 | 3 | lib/features/input/size_picker_modal.dart:501、lib/features/input/size_picker_modal.dart:567、lib/shared/theme.dart:140 |
| 14 | 3 | lib/main.dart:165、lib/shared/theme.dart:118、lib/shared/theme.dart:128 |
| 12 | 3 | lib/shared/theme.dart:123、lib/shared/theme.dart:134、lib/shared/theme.dart:175 |
| 13 | 2 | lib/features/input/bottom_input_bar.dart:323、lib/features/input/bottom_input_bar.dart:351 |
| 16 | 2 | lib/shared/theme.dart:108、lib/shared/theme.dart:113 |
| 10.5 | 1 | lib/features/image_list/image_cell.dart:894 |
| 30 | 1 | lib/shared/theme.dart:92 |
| 24 | 1 | lib/shared/theme.dart:98 |
| 20 | 1 | lib/shared/theme.dart:103 |

## A8 圆角与内边距取值分布

### 圆角

| 半径 | 次数 |
|---|---|
| 12 | 19 |
| 999 | 14 |
| 18 | 10 |
| 16 | 10 |
| 14 | 8 |
| 8 | 7 |
| 10 | 3 |
| 7 | 2 |
| 22 | 2 |
| 2 | 2 |
| 24 | 1 |
| 1.8 | 1 |
| 15 | 1 |
| 20 | 1 |

### EdgeInsets（前 30 种）

| 写法 | 次数 |
|---|---|
| `symmetric(horizontal: 7, vertical: 4)` | 9 |
| `only(bottom: 8)` | 4 |
| `symmetric(horizontal: 12, vertical: 10)` | 3 |
| `fromLTRB(16, 0, 16, 8)` | 3 |
| `all(16)` | 3 |
| `only(right: 2)` | 2 |
| `only(right: 8)` | 2 |
| `symmetric(horizontal: 7, vertical: 3)` | 2 |
| `fromLTRB(12, 24, 12, 24)` | 2 |
| `all(12)` | 2 |
| `fromLTRB(16, 0, 16, 16)` | 2 |
| `symmetric(vertical: 8)` | 2 |
| `symmetric(horizontal: 12, vertical: 12)` | 2 |
| `symmetric(vertical: 14)` | 2 |
| `all(18)` | 2 |
| `fromLTRB(14, 10, 10, 10)` | 2 |
| `symmetric(horizontal: 14, vertical: 10)` | 2 |
| `symmetric(horizontal: 18, vertical: 14)` | 2 |
| `symmetric(horizontal: 12, vertical: 11)` | 1 |
| `only(right: 4)` | 1 |
| `fromLTRB(12, 0, 12, _searchExpanded ? 8 : 0)` | 1 |
| `fromLTRB(8, 7, 8, 8)` | 1 |
| `fromLTRB(5, 14, 5, 5)` | 1 |
| `all(7)` | 1 |
| `symmetric(horizontal: 6, vertical: 3)` | 1 |
| `fromLTRB(14, 8, 8, 14)` | 1 |
| `only(top: 6)` | 1 |
| `symmetric(horizontal: 10, vertical: 6)` | 1 |
| `only(top: 12, right: 12)` | 1 |
| `symmetric(horizontal: 12, vertical: 8)` | 1 |

<!-- GENERATED:END -->

## A9 二级弹层与对话框（主文档没展开的部分）【核对】

### A9.1 生成数量（`lib/features/input/quantity_selector.dart:66-186`）

| 项 | 参数 |
|---|---|
| 形态 | AlertDialog |
| 标题 | 「生成数量」 |
| 输入 | TextField，`keyboardType: number`，hint「1 - 16」，只允许数字（`_MaxValueFormatter`） |
| 快捷值 | 输入框下 **12** 间距，Wrap：每个按钮内边距 `vertical 8`、圆角 **8**、右间距 8（最后一项 0） |
| 动作 | 取消（TextButton）/ 确定（FilledButton） |

### A9.2 请求超时（`lib/features/settings/settings_page.dart:246-290`）

| 项 | 参数 |
|---|---|
| 标题 | 「请求超时（秒）」 |
| 输入 | TextField，数字键盘 |
| 说明 | 输入框下 10 间距，12px 灰字 |
| 动作 | 取消 / 保存（FilledButton） |

### A9.3 WebDAV 设置（`lib/features/settings/settings_page.dart:420-500`）

| 顺序 | 字段 | 参数 |
|---|---|---|
| 1 | WebDAV 地址 | labelText「WebDAV 地址」，hint `https://example.com:5244/` |
| 2 | 用户名 | 间距 10 |
| 3 | 密码 | 间距 10，`obscureText` + 眼睛后缀按钮 |
| 4 | 远端目录 | 间距 10，hint `MintImage/backups` |
| 5 | 说明文字 | 间距 10，12px |
| 动作 | 测试连接 / 取消 / 保存 | 整体包在 `SingleChildScrollView` 里（窗口矮时可滚） |

### A9.4 模型勾选（`lib/features/settings/api_profile_edit_page.dart:400-490`）

| 项 | 参数 |
|---|---|
| 标题 | 「选择模型」，右上角「全选」TextButton |
| 列表 | ListView + CheckboxListTile，`contentPadding: EdgeInsets.zero` |
| 动作 | 取消 / 确定（TextButton ×2） |

### A9.5 其余对话框一览【核对】

| 对话框 | 标题 | 内容 | 动作 |
|---|---|---|---|
| 清除历史 | 「清除历史记录」 | 「这会删除所有生成记录，但不会清除 API 配置。」 | 取消 / 清除 |
| 敏感操作确认 | 动态（「导出备份」/「从文件恢复」） | 说明文本 | 取消 / 继续 |
| 恢复确认 | 「从{来源}恢复」 | 「恢复会替换当前设置、历史记录、收藏夹和应用内图片文件。恢复前会自动生成一份安全快照。」 | 取消 / 恢复 |
| 备份提示 | 「备份提示（{N}）」 | 固定宽 **420**，可滚动，最多 20 条换行拼接 | 知道了 |
| 进度提示 | 无标题 | Row[22×22 转圈 + 14 间距 + 文案]，`barrierDismissible: false` + `PopScope(canPop: false)` | 无（自动关闭） |
| 失败原因 | 「失败原因」 | `SelectableText`（可复制） | FilledButton「关闭」 |
| 删除收藏夹 | 「删除收藏夹」 | 「确认删除"{名称}"？其中的生成结果不会被删除。」 | 取消 / 删除 |
| 退出确认 | 「确认退出？」 | 「当前仍有图片正在生成，退出会中断这些任务。」 | TextButton「继续生成」/ FilledButton「退出」 |
| SnackBar | — | 默认样式、无 action、4s | 「已复制图片到剪贴板。」「历史记录已清空。」「无法打开 GitHub 地址。」等 |

### A9.6 新版本角标（`lib/features/home/home_page.dart:120-132`）【核对】

| 项 | 参数 |
|---|---|
| 位置 | 标题文字右侧 +8，与标题基线对齐 |
| 尺寸 | 高度约 17（`labelSmall` + 内边距），横向内边距 7，圆角 999 |
| 文字 | 「New」10px / 800 |
| 行为 | 点击外部浏览器打开 GitHub Releases |

---

## A10 状态矩阵【核对】

### A10.1 图卡五种状态

| 状态 | 视觉 | 位置 |
|---|---|---|
| 排队 / 生成中（无过程图） | `surfaceSoft → primarySoft` 渐变底 + 居中 24×24 转圈（线宽 2.4） | image_cell.dart:906-922 |
| 生成中（有流式过程图） | 过程图 cover 铺满 + 左下「正在生成」角标：底 `surface` @0.86、圆角 10、内边距 (7,3)、10×10 转圈 + 5 间距 + 10.5px/w700 文字 | image_cell.dart:866-899 |
| 完成 | 原图 cover + 右上状态 pill + 底部元信息 chips | image_cell.dart:797-850 |
| 失败 | `_FallbackThumb` + 可点击的「失败」pill（点开失败原因对话框） | image_cell.dart:925+ / 471-485 |
| 已取消 | 同失败，pill 底色 `#FFF0D8` / 字 `#935E00` | image_cell.dart:820-822 |

### A10.2 按钮状态

| 控件 | 可用 | 禁用 |
|---|---|---|
| 发送按钮 | 渐变 `primary → primaryStrong`，不透明度 1 | 灰 `#B9C7D4`，不透明度 **0.7** |
| 附件按钮 / 优化按钮 | 不透明度 1，可点 | 不透明度 **0.38**，`onTap: null` |
| 优化中 | 22×22 转圈（value 0.72，线宽 2.4）+ 中心 8×8 方块（圆角 1.8），提示文案改为「停止优化」 | — |
| 参数 chip | `surfaceSoft` 底 + `border` @0.7 描边 + 文字 `primaryStrong` | 无禁用态（能力不支持时直接不出现选项） |

### A10.3 输入框

| 状态 | 描边 |
|---|---|
| 默认 | `border` 1px |
| 聚焦 | `primary` **1.4px** |
| 过渡 | `AnimatedBuilder` 跟随 FocusNode，无额外动画时长（即时） |

### A10.4 多选态

| 项 | 参数 |
|---|---|
| 卡片描边 | 3px（选中） |
| 左上角标 | 22×22 圆形，内边距 7，未选中为 2px 空心圆，选中为白底 + 15px 勾 |
| 顶部 | AppBar 左侧出现「已选 N 项」+ 删除按钮 |

### A10.5 缺失状态（设计必须补）

hover / pressed / focus-visible / drag-over / 右键 / 滚动条 / 空搜索结果 / 网络断开 / 任务队列积压 —— 代码里**全部没有**，需要设计师从零定义。

---

## A11 复刻验收清单（可逐项打勾）

- [ ] 窗口 1280×720，标题栏「大川生图工具」，可拖到任意小不崩（当前实际会挤坏）
- [ ] 背景：`#F8FAFF → #EFF7FF` 纵向渐变 + 三个径向光斑，位置尺寸同 A2
- [ ] AppBar 56 高、透明、标题 20/700、副标题 12、右侧四个 48×48 按钮
- [ ] 图墙：左右 14、间距 10、格高 274（图 206 + 文字 68）、列数公式一致
- [ ] 图卡：圆角 8、cover、右上 2 枚 chip、底部 5 枚 chip、提示词两行、时间 11px、行内菜单 24×22
- [ ] 状态 pill 四种配色与 10/800 字号
- [ ] 输入栏：外距 (10,6,10,6)、圆角 22、模糊 16、玻璃渐变 0.88→0.72
- [ ] 输入框：最小高 40、字号 13/1.25、聚焦描边 primary 1.4
- [ ] 附件 28×28、优化 28×28、发送 40×40 三处尺寸
- [ ] 七个参数 chip：最小高 28、内边距 (7,4)、圆角 12、图标 13、文字 11、间距 6
- [ ] 无 Key 时发送可用（弹配置选择）、参数行下方红字提示
- [ ] 图卡长按面板 9 项（条件出现项正确）
- [ ] 收藏夹面板最大高 72%、行内边距 (12,10)
- [ ] 尺寸面板：拖拽条 36×4、网格示意、自定义输入、双按钮内边距 14
- [ ] 预览页：黑底、箭头 58×58 @24、缩放徽标右上 16/16、信息面板圆角 24 内边距 (14,8,8,14)、提示词最高 84
- [ ] 设置页：卡片圆角 18/24/28、内边距 14/18、区块标题 16/700
- [ ] 两个配置编辑页：卡片圆角 30/24、字段间距 18/14/10、保存按钮全宽
- [ ] 日志页：ExpansionTile 内边距 (14,4)、级别 chip (8,5)
- [ ] 全部 9 个对话框的标题/文案/动作（A9.5）
- [ ] 文案逐字一致（见 A5，共 466 行可对照）
- [ ] 图标与 codepoint 一致（见 A4，67 个）
- [ ] 动效时长：180/220/120/240/900 五档（见 A6）

---

## A12 复刻精度声明

| 能达到 | 达不到 |
|---|---|
| 结构、位置、间距、字号、圆角、颜色、图标、文案、动效时长 | 字体实际渲染（Manrope 联网下载，中文回落系统） |
| 静态视觉可比对到 1px 级 | DPI 125%/150% 下的重排（代码无 textScaler 处理） |
| 五种图卡状态、四种 pill、九种对话框 | hover/pressed/右键/滚动条（代码里不存在） |
| 九处 Tooltip 文案 | 拖拽框选、任务队列、断网重连等动态行为 |
| 动画时长与曲线 | 模糊（BackdropFilter）跨显卡差异 |

---

## A13 维护方式

```powershell
# 1) 重新抽取 A1 / A4–A8 片段
python scripts/gen_ui_appendix.py > docs/_appendix_generated.md
# 2) 按 <!-- GENERATED:START/END --> 标记替换进本文件
python scripts/splice_appendix.py
```

标记区之外（A0–A3、A9–A13）是手写内容，脚本不会覆盖。

- 脚本只扫描 `lib/**/*.dart`，跳过 `*.g.dart`（drift 生成文件无 UI）。
- 颜色/图标/文案改动会自动反映；手写段 A0–A3、A9–A12 需要人工同步。
