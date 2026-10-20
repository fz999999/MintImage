# 仓库工作约定（给 AI 助手 / 协作者）

## 语言

用中文回复。

## 默认动作：改完直接跑，不打包

改完代码就构建 Release 并启动，让用户在**自己的窗口里**验收：

```powershell
pwsh -File scripts/run-windows.ps1
```

- **不要**在没有明确要求时执行 `scripts/package-windows.ps1`（打包）。
- 用户说「打包 / 出个包 / 发给我」时才打包；打完后确认包内没有 `*.sqlite`、`shared_preferences.json`、`*.jsonl`、`generated_images\`。
- 不要指望截图验收界面：本机抓 Flutter 窗口只能拿到上半部分（详见 `docs/WINDOWS-BUILD.md` 坑 9）。

## 只维护 Windows 端

应用显示名、打包、原生资源只改 Windows（`windows/`、Dart 层显示文案）。
**不要**动 `android/`、`ios/`、`macos/`，这是用户的明确要求。

## 常用命令

```powershell
# 回归测试（约 7 秒，可用）
& 'C:\src\flutter\bin\flutter.bat' --no-version-check test

# 增量构建 + 启动
pwsh -File scripts/run-windows.ps1 -NoBuild

# 全量重建（改了 windows/ 下 CMake 或 rc 之后）
pwsh -File scripts/run-windows.ps1 -Clean
```

所有 `flutter` 调用都要带 `--no-version-check`，否则会因联网版本检查挂死。

## 红线（踩过坑，别回头）

1. 运行时数据一律走 `lib/core/services/app_paths.dart`；
   **不要**再用 `getApplicationSupportDirectory()` / `getApplicationDocumentsDirectory()`。
   原因：zip 解压出来的 exe 是低完整性进程，写不了 AppData / 我的文档。
2. `lib/core/database/app_database.dart` 顶部必须是 `part 'app_database.g.dart';`，不能改成 `import`。
3. `lib/core/api/openai_client.dart` 里 `DioExceptionType` 的 switch 收尾必须是 `default:`（dio 5.10 新增了枚举值）。
4. `windows/atl_shim/atlbase.h` 与 `windows/CMakeLists.txt` 里的 ATL 探测不要删——本机 Build Tools 没有 ATL 组件。
5. `lib/features/input/bottom_input_bar.dart`、`lib/features/settings/settings_page.dart`、
   `lib/features/settings/api_profile_edit_page.dart` 不是 format-clean，**不要整体 `dart format`**。
6. `windows/runner/main.cpp` 里写中文必须用 `L"\u5927\u5ddd..."` 转义（编译带 `/WX` 且无 `/utf-8`）。
7. `.gitignore` 已忽略 `dist/`、`build/`、`*.log`：打包产物不进库。
8. Material 图标必须在 `Icon(...)` 里**内联常量**书写，不能从 getter/变量/参数传入
   （release 的图标 tree-shaking 会把它丢掉，测试里看不出来）。
   新加图标后若 release 里仍空白，删掉 `.dart_tool\flutter_build` 再 build。

## 更多

完整的构建/打包手册与全部已知坑：`docs/WINDOWS-BUILD.md`。
