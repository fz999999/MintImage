$ErrorActionPreference = 'Stop'

# 定义路径
$releaseDir = "build\windows\x64\runner\Release"
$distDir = "dist"
$appName = "大川生图工具-windows-x64-v3"
$stagingDir = Join-Path $distDir $appName

Write-Host "=== Packaging Release Build ===" -ForegroundColor Cyan

# 清理之前的打包目录
if (Test-Path $stagingDir) {
    Write-Host "Removing old staging directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $stagingDir
}

# 创建打包目录
Write-Host "Creating staging directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# 复制必需的文件
Write-Host "Copying files..." -ForegroundColor Cyan

# 复制主程序
Copy-Item (Join-Path $releaseDir "mint_image.exe") $stagingDir

# 复制 DLL 文件
$dlls = @(
    "flutter_windows.dll",
    "file_selector_windows_plugin.dll",
    "url_launcher_windows_plugin.dll",
    "flutter_local_notifications_windows.dll",
    "sqlite3.dll",
    "dartjni.dll"
)

foreach ($dll in $dlls) {
    $dllPath = Join-Path $releaseDir $dll
    if (Test-Path $dllPath) {
        Copy-Item $dllPath $stagingDir
        Write-Host "  ✓ $dll" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Missing: $dll" -ForegroundColor Red
    }
}

# 复制 data 目录
$dataSource = Join-Path $releaseDir "data"
$dataTarget = Join-Path $stagingDir "data"
Copy-Item -Recurse $dataSource $dataTarget
Write-Host "  ✓ data directory" -ForegroundColor Green

# 创建 README
$readme = @"
大川生图工具 v3 - Windows x64
================================

本版本使用便携式数据存储，所有用户数据都保存在 exe 同级的 data 文件夹中。

使用方法：
1. 解压整个文件夹到任意位置
2. 双击运行 mint_image.exe
3. 在设置页面配置你的 API Key

数据位置：
- 数据库：data\mint_image.sqlite
- 日志：data\mint_image_request_logs.jsonl
- 资源文件：data\flutter_assets

更新日志：
- ✨ 修复了从 ZIP 解压后无法访问 AppData 目录的问题
- ✨ 改用便携式数据存储，支持绿色安装
- ✨ 每个 API 支持多模型配置
- ✨ 主界面支持快速切换模型
- ✨ 应用名称改为"大川生图工具"

"@

$readmePath = Join-Path $distDir "README-$appName.txt"
$readme | Out-File -FilePath $readmePath -Encoding UTF8

# 压缩打包
$zipPath = Join-Path $distDir "$appName.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host "`nCompressing package..." -ForegroundColor Cyan
Compress-Archive -Path $stagingDir -DestinationPath $zipPath -CompressionLevel Optimal

# 显示结果
Write-Host "`n=== Package Complete ===" -ForegroundColor Green
$zipInfo = Get-Item $zipPath
Write-Host "Package: $($zipInfo.FullName)" -ForegroundColor Cyan
Write-Host "Size: $([math]::Round($zipInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan

# 列出包内容
Write-Host "`nPackage contents:" -ForegroundColor Cyan
Get-ChildItem $stagingDir -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
    $relativePath = $_.FullName.Substring($stagingDir.Length + 1)
    Write-Host "  $relativePath" -ForegroundColor Gray
}
