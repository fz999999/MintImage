# Windows 构建与打包手册

本文件记录「大川生图工具」Windows 端从改代码到交付的完整路径，以及一路踩过的坑。
新开对话或换机器时先读这一页，不要重新试错。

---

## 0. 两种流程，别搞混

| 场景 | 命令 | 耗时 |
| --- | --- | --- |
| **日常改完看效果（默认）** | `pwsh -File scripts/run-windows.ps1` | 30~60s + 启动 |
| 交付给别人 | `pwsh -File scripts/package-windows.ps1 -Build` | 构建 + 打包约 1~2min |

**默认不打包。** 除非用户明确说「打包 / 发我个包 / 出安装包」，一律只构建 Release 并直接启动，
让用户在自己屏幕上验收。原因见坑 6、坑 11：打包会引入 zip 解压后的完整性标签问题，
而截图又抓不到 Flutter 窗口下半部分，所以「直接跑给用户看」是唯一可靠的验收方式。

---

## 1. 环境

| 项 | 值 |
| --- | --- |
| Flutter | 3.47.5 stable，`C:\src\flutter\bin\flutter.bat` |
| Dart | 3.13.4，`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe` |
| 编译工具 | VS 2022 Build Tools，`C:\BuildTools`（**没有 ATL 组件**） |
| Windows SDK | 10.0.26100.0 |
| 依赖镜像 | `PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` |
| 代理 | `127.0.0.1:10808`（可选，镜像基本够用） |

脚本里已写好这些环境变量，手工执行时记得补上。

---

## 2. 构建（不打包）

```powershell
pwsh -File scripts/run-windows.ps1              # 增量构建 + 启动
pwsh -File scripts/run-windows.ps1 -Clean       # 全量重建（改了 windows/ 下的 CMake 或 rc 后）
pwsh -File scripts/run-windows.ps1 -NoBuild     # 只重启已有产物
pwsh -File scripts/build-windows.ps1            # 只构建不启动
```

产物：`build\windows\x64\runner\Release\mint_image.exe`（同目录还有 6 个 DLL 和 `data\`）。

数据目录就在 exe 旁边：`build\windows\x64\runner\Release\data\`
（`mint_image.sqlite`、`generated_images\`、`shared_preferences.json`、`mint_image_request_logs.jsonl`）。

Debug 与 Release 各自有独立的 data 目录，互不影响。

---

## 3. 打包

```powershell
pwsh -File scripts/package-windows.ps1 -Build
```

产出：

- `dist\大川生图工具-windows-x64-v<版本>.zip`（版本号取自 `pubspec.yaml` 的 `version:`，去掉 `+build`）
- `dist\README-大川生图工具-windows-x64-v<版本>.txt`

包内容规则（脚本已实现，改脚本时不要破坏）：

1. `mint_image.exe`
2. Release 目录下**所有** `*.dll`（自动探测，别写死清单，加插件时会漏）
3. `data\` 里**只放** `flutter_assets\`、`app.so`、`icudtl.dat`

**绝对不要**把 `mint_image.sqlite`、`shared_preferences.json`、`*.jsonl`、`generated_images\` 打进包。
脚本末尾有自检：一旦发现用户数据文件会直接抛错终止。

---

## 4. 踩过的坑

### 坑 1：`flutter` / `dart` 命令挂死
症状：`flutter --version` 长时间无输出、CPU 空转。
原因：联网做版本检查 / 走不通的代理。
解法：**所有 flutter 调用都加 `--no-version-check`**；`dart` 直接用
`C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe`，不要用 `dart.bat`。

### 坑 2：`pub get` 会改写 `pubspec.lock`
症状：跑完 pub get，`pubspec.lock` 显示 dio 从 5.9.2 升到 5.11.1、riverpod 升到 3.4.x。
原因：仓库里那份 lock 对当前 SDK 无效，pub 必然重新解析。
处置：这是**已知且可接受**的副作用；想保持工作区干净就 `git checkout -- pubspec.lock`，
但下次 pub get 还会再改，别指望锁死。

### 坑 3：`DioExceptionType` 穷尽性失配
症状：`openai_client.dart(413,19): The type 'DioExceptionType' is not exhaustively matched ... 'DioExceptionType.transformTimeout'`
原因：dio 5.10 新增了 `transformTimeout`，代码里 `case DioExceptionType.unknown:` 收尾。
解法：已改成 `default:`（见 `lib/core/api/openai_client.dart`），对 5.9 / 5.11 都成立。不要改回去。

### 坑 4：缺 `atlbase.h`
症状：`flutter_local_notifications_windows\src\plugin.cpp(5,10): error C1083: 无法打开包括文件: "atlbase.h"`
原因：本机 Build Tools 没装 ATL 组件（全盘搜不到 `atlbase.h`）。
解法：`windows/atl_shim/atlbase.h` 提供了插件唯一需要的 `CW2A`；`windows/CMakeLists.txt`
里用 `check_include_file_cxx("atlbase.h" MINTIMAGE_HAS_ATL)` 探测，**只有没真 ATL 时才**加 shim 目录。
装了完整 ATL 的机器不会受影响。

### 坑 5：`LNK1104: 无法打开文件 ...\mint_image.exe`
原因：上一个实例还在跑，exe 被占用。
解法：构建前 `Get-Process mint_image | Stop-Process -Force`（脚本已做）。

### 坑 6：从 zip 解压出来的 exe 写不了 `%APPDATA%` / 我的文档
症状：启动即 `PathAccessException: Creation failed, path = 'C:\Users\...\AppData\Roaming\com.aiqin\...'`；
或出图时 `Cannot open file, path = 'D:\...\Documents\generated_images\xxx.png'`。
原因：zip 解压 / 下载来的 exe 会带 `Mandatory Label\Low Mandatory Level:(I)(NW)`，
低完整性进程写不了中完整性的目录；而直接 `flutter build` 出来的 exe 没有这个标签，所以本地一直正常。
试过且**无效**的方案：`icacls /setintegritylevel`、`schtasks /rl highest`、换目录、explorer 启动、删除旧配置文件。
**最终方案**：便携化——所有运行时数据落在 exe 同级的 `data\`，
统一入口 `lib/core/services/app_paths.dart`（`executableDirectory` 用 `Platform.resolvedExecutable` 推导，
`dataRoot()` → `<exeDir>\data`，`subDirectory(name)`）。数据库、日志、图片、备份恢复、Settings 全部走它。
`Settings` 走的是自定义的 `lib/core/services/portable_preferences_store.dart`
（继承 `SharedPreferencesStorePlatform`，写 `data\shared_preferences.json`，首次运行从旧 `%APPDATA%` 迁移一次）。
改这些文件时不要退回 `getApplicationSupportDirectory()` / `getApplicationDocumentsDirectory()`。

### 坑 7：`part` 写成 `import` 会炸掉 drift
症状：`'$composableBuilder' isn't defined`、`'Value' isn't a type`、`Method not found: 'PrefetchHooks'`（全在 `app_database.g.dart`）。
原因：把 `lib/core/database/app_database.dart` 顶部的 `part 'app_database.g.dart';` 改成了 `import`。
解法：必须是 `part`。生成文件不参与独立编译。

### 坑 8：`flutter run` 在本机不可用
症状：`RPCError ... DevFS ... PathAccessException: Creation of temporary directory failed, path = 'D:\Personal\Temp' (OS Error: 拒绝访问)`。
原因：工具进程建临时目录被环境挡住。
解法：不要依赖热重载。改代码后走「build + 启动」；纯逻辑/UI 断言用 `flutter test`（这个能用，全量约 7 秒）。

### 坑 9：抓 Flutter 窗口截图只能拿到上半部分
症状：`PrintWindow` / `CopyFromScreen` 只截窗口区域时，内容只填充上方约 460px，底部输入栏区域是空白。
已用改造前的旧包做对照：旧包同样截不到 → 是截图管线的限制，不是界面 bug。
**可行的替代**：把窗口置顶（`SetWindowPos(hwnd, HWND_TOPMOST(-1), ...)` + `BringWindowToTop`），
然后整屏 `CopyFromScreen(0,0,屏幕宽,屏幕高)` 存 PNG —— 整屏截图里底部输入栏是完整的；
选项行大约在 `y≈850-900`，裁 `Rectangle(20, 850, 760, 50)` 再放大 3 倍即可读清 chip 文案。
注意 `SetWindowPos` 改窗口高度**不会**触发布局重排（内容按原尺寸绘制后裁切），别指望缩小窗口让底栏露出来。

### 坑 10：部分大文件不是 format-clean
`lib/features/input/bottom_input_bar.dart`、`lib/features/settings/settings_page.dart`、
`lib/features/settings/api_profile_edit_page.dart` 在当前 SDK 下整体 `dart format` 会产生上千处无关重排。
只对新文件、以及本来就干净的文件跑 format；改大文件时手写遵守 80 列。

### 坑 11：`windows/runner/` 里的中文
- `Runner.rc` 第 3 行已有 `#pragma code_page(65001)`，可直接写中文（UTF-8 无 BOM）。
- `main.cpp` 编译选项是 `/W4 /WX` 且没有 `/utf-8`，写中文字面量会触发 C4819 直接失败 →
  必须用转义 `L"\u5927\u5ddd\u751f\u56fe\u5de5\u5177"`。
- 修改后建议用 `rc.exe` 单独编译一次 `Runner.rc` 快速验证，不必等整个 build。

### 坑 12：release 里图标显示为空白
症状：代码里明明写了 `Icon(Icons.wallpaper_rounded)`，widget test 里 `find.byIcon` 也过，
但 release 里 chip 上什么都没有（13px 的位置还留着，就是空的）。两个原因，都要注意：
1. **图标必须是内联常量**：`const Icon(Icons.xxx, size: 13, ...)`。
   写成 `IconData get _icon => Icons.wallpaper_rounded;` 再 `Icon(_icon)` ——
   release 的图标 tree-shaking 只保留出现在 `Icon(常量)` 位置的图标，
   通过变量/getter/参数传进来的会被丢掉，而 debug 和 widget test 完全看不出来。
2. **图标字体子集有增量缓存**：新增图标后只做增量 build，`data\flutter_assets\fonts\MaterialIcons-Regular.otf`
   可能还是旧的子集（正常约 11.8KB），新图标依旧空白。判据：字体文件大小没变。
   解法：删掉 `.dart_tool\flutter_build` 再 build，字体子集才会重新生成。
   （`--no-tree-shake-icons` 能立刻显示，但字体变回 1.6MB，只适合用来定位问题。）
3. 验证办法：整屏截图裁选项行放大看，或对比字体文件大小有没有变化。

---

## 5. 交付前验证清单

```powershell
# 1. 回归测试
pwsh -Command "& 'C:\src\flutter\bin\flutter.bat' --no-version-check test"

# 2. 构建并启动
pwsh -File scripts/run-windows.ps1
```

启动后确认：

- [ ] 窗口标题是「大川生图工具」
- [ ] `data\` 下生成了 `mint_image.sqlite`、`shared_preferences.json`、`mint_image_request_logs.jsonl`
- [ ] 历史记录还在（老用户升级场景）
- [ ] 生成一张图，确认 `data\generated_images\` 有文件落地
- [ ] 打包产物解压到别的目录再启动一次，行为一致（坑 6 的回归验证）
