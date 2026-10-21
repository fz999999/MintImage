# Windows 选择器与弹窗改造计划

状态：P0–P6实施与自动验证已完成，Windows Release已构建并启动；实际逐屏交互视觉验收待用户窗口确认。只维护 Windows，不改原生其他平台，不打包。工作区已有修改已保留，未重置、未自动提交。

## 已确认决定（12项）
1. 保留尺寸业务约束、7分类71项预设。预设绕过校验的问题另列后续。
2. 尺寸/数量非法或空输入就地报错并禁用确定；不静默回退；数量允许1–16，超过16报错。
3. 单图删除增加确认，默认聚焦取消。
4. 批量选择隐藏单张更多，禁用右键/键盘单图菜单，点击只选中。
5. 警告/优化测试完整显示，可滚动、复制全部。
6. 切换API并发送保留持久切换；发送按钮补显式箭头。
7. 缺Key普通API可选，切换并发送禁用且说明原因。
8. 收藏多选即时提交，逐项busy/错误；完成关闭，无取消回滚。
9. 数量用锚定编辑浮层，输入/快捷项/确认取消；外部点击和Esc放弃草稿。
10. 尺寸先快捷浮层，再更多尺寸打开完整Dialog。
11. 快捷尺寸：自动/当前/现有1:1、3:2、2:3、16:9、9:16的1K档，按宽高去重，即选即用。
12. 执行动作左、安全取消/关闭右，危险确认默认安全焦点，Esc取消。

## 通用规范
菜单180–280宽、单行32–36高；说明列表320–400宽、双行48起；数量280宽；确认400–440；表单520–600；尺寸760–860。按内容收缩，不制造留白。最大高度随可用视口收缩，Popover常规上限420，Dialog距客户区24。4/8/12/16/24 spacing，复用AppColors与AppRadius。不引入依赖。
锚点边距8、间隔4–8，底部入口优先上弹，边界翻转；鼠标位置context menu，按钮位置menu。窗口resize/锚点销毁关闭或重定位。外部点击关闭且不穿透。Tab/Enter/Space/方向键/Esc，右键菜单补Shift+F10。关闭返回触发器，不抢提示词；Enter不能冒泡发送；尊重IME组合输入。
长列表超过8项提供搜索，列表独立滚动，选中跨搜索保留。多选即时提交、编辑草稿、命令执行三种语义不得混用。

## 阶段与文件所有权
P0 公共组件：lib/shared/widgets/desktop/{desktop_popup_tokens,desktop_popover,desktop_menu,desktop_choice_list,desktop_dialog}.dart。API见实施委派约定。负责人公共组件agent。
P1 简单参数：lib/features/input/{selector_chip_label,quality_selector,image_format_selector,background_selector,quantity_selector}.dart。与P3尺寸同一agent避免入口冲突。
P2 输入栏：lib/features/input/bottom_input_bar.dart，仅输入栏agent所有；四个sheet替换，发送箭头，缺Key差异，保留质量回退/持久化/优化取消/附件限制。
P3 尺寸：lib/features/input/{size_selector,size_picker_modal}.dart，仅参数agent所有；保留公开返回协议，完整71预设；非法输入修正。模型多选由设置agent负责。
P4 收藏图卡：lib/features/favorites/favorite_folder_sheet.dart、lib/features/image_list/image_cell.dart、lib/features/home/home_page.dart，仅收藏图卡agent所有。稳定锚点，多选即时保存，单图确认及批选隔离。
P5 设置与全局Dialog：lib/features/settings/{settings_page,api_profile_edit_page,prompt_optimization_profile_edit_page,model_name_field,image_api_section}.dart及lib/app.dart，仅设置agent所有。上下文原生文件窗口保留；全部模型只读Popover，WebDAV/多选Dialog，警告/结果完整复制，退出防重入保留。
P6 主agent集成，analyze/test，Windows Release构建启动，不打包。

## 场景级交付与保留行为

| 原入口 | 新形式 | 实施文件 | 业务保留与验收 |
|---|---|---|---|
| 质量/格式两个sheet | 紧凑单选菜单 | quality_selector.dart / image_format_selector.dart | 模型可选质量、当前勾选、立即回调 |
| 背景sheet | 说明单选列表 | background_selector.dart | JPEG与透明禁用原因、父层格式联动 |
| 普通API/模型sheet | 带搜索单选Popover | bottom_input_bar.dart | 持久切换、同值不写入、质量回退 |
| 长按发送sheet | 显式箭头命令菜单 | bottom_input_bar.dart | 先持久切换再发送，缺Key禁用 |
| 优化方向sheet | 说明命令菜单 | bottom_input_bar.dart | 五方向描述、点击启动、优化中停止 |
| 数量Dialog | 280宽草稿Popover | quantity_selector.dart | 快捷1/2/4/8/16，输入1–16，取消不写入 |
| 尺寸sheet | 快捷菜单→完整Dialog | size_selector.dart / size_picker_modal.dart | 自动/预设/自定义；完整71项与既有约束 |
| 收藏浏览/收藏多选sheet | 锚定Popover | favorite_folder_sheet.dart | 单选返回ID/多选即时保存，新建错误提示 |
| 图卡操作sheet | 指针/按钮Context Menu | image_cell.dart | 原9项按状态可用、错误详情、单图确认 |
| 模型候选showMenu | 可搜索Popover | model_name_field.dart | 仍可自由输入，不吞编辑提交 |
| 全部模型Dialog | 只读Popover | image_api_section.dart | 展示全部已配置模型 |
| 批量添加模型Dialog | 受限宽高编辑Dialog | api_profile_edit_page.dart | 现有模型锁定、搜索不丢勾选、确定追加 |
| 模式/协议下拉 | 紧凑原生Flutter下拉 | 两个API编辑页 | 保留切换时默认模型/URL联动 |
| WebDAV Dialog | 520–600表单Dialog | settings_page.dart | 四字段、密码显隐、连接测试、取消草稿 |
| 单图/批量图片/收藏夹/配置删除、清空历史 | 统一危险确认 | image_cell.dart / home_page.dart / favorite_folder_sheet.dart / settings_page.dart | 左执行右取消、默认取消，确认后调用原业务 |
| 敏感备份/恢复 | 阻断确认Dialog | settings_page.dart | 保留全部敏感说明、恢复替换数据语义 |
| 退出确认 | 专门退出流程+统一容器 | app.dart | 生成中拦截、四句原文、重复确认防护 |
| 备份进度 | 不可轻关闭Dialog | settings_page.dart | barrier禁用与PopScope保留 |
| 错误/警告/优化测试结果 | 可滚动信息Dialog | image_cell.dart / settings_page.dart / prompt_optimization_profile_edit_page.dart | 完整正文，不截20条/8行，复制全部 |
| 附件/图片保存/备份文件 | 系统文件窗口 | 既有service与settings_page.dart | 保留系统行为 |
| 图片预览/日志 | 独立页面/既有列表 | 本阶段无改造 | 不改成Dialog |

此表文件名均相对其上列阶段所给目录；阶段表是文件所有权与实施依赖的准绳。旧sheet调用可作为非Windows分支保留，验收Windows执行路径。

## 验收与回滚
逐场景核对11个sheet的Windows替代；其他平台不主动变更。测试窗口/缩放/暗亮、长短列表、长文本、输入法、键盘、焦点、外部点击、异步卸载、防重复、取消无写入、收藏即时、模型多选追加锁定。
命令flutter一律--no-version-check。最终scripts/run-windows.ps1构建启动；不得全文件format三个非format-clean文件。不动数据库/协议/运行数据。当前已有修改不reset、不自动commit；分阶段可用精确diff回退本轮改动，不能覆盖旧修改。

## 实施结果与验证记录

- 六个智能体分工：公共组件、参数/尺寸、输入栏、收藏/图卡、设置/全局Dialog、交互测试；主agent集成修复及构建。
- P0–P5上述场景均已接入。Windows保留的sheet源码属于其他平台分支。
- 新增测试：test/shared/desktop_popup_test.dart（7例），test/features/input/desktop_selectors_test.dart（8例），test/features/image_list/desktop_image_actions_test.dart（3例）。原输入栏长按测试仅更新已确认的新文案，仍断言切换持久化并发送。
- flutter --no-version-check analyze：No issues found。
- flutter --no-version-check test：104通过，5跳过，0失败。跳过为需显式环境与密钥的真实API测试。
- 自动覆盖：菜单选中/禁用/搜索、方向键/Enter/Esc、外部关闭不穿透、默认安全焦点、440×320及1.5倍文本长菜单/确认框、数量边界/取消无写入、尺寸非法值不回退/修正提交、批选右键与ShiftF10隔离、正常右键命令。
- 集成修正：Popover外层普通Focus抢焦点导致菜单方向键失效，改FocusScope；局部Shortcuts恢复Enter/Space激活且不冒泡；任务进度使用独立DialogRoute并仅移除自身，避免误关上层退出确认。
- scripts/run-windows.ps1：Release构建成功（约57秒），启动PID1636，标题“大川生图工具”，running=True；进程另核实Responding=True。未打包。
- 未声称完成实际逐屏鼠标/IME/暗亮主题/系统DPI切换验收。原生Flutter窗口缺乏本轮可用自动交互通道，以上运行结论限构建和进程状态。

## 业务后续/运行待验
预设和自定义像素约束冲突本轮不改；实际最小窗口和缩放须验证。保留预览整页、系统文件窗口。实现中公共API冲突由主agent协调，不擅改业务决定。
