# Windows Release 构建（不打包）
#
# 用法：
#   pwsh -File scripts/build-windows.ps1            # 增量构建
#   pwsh -File scripts/build-windows.ps1 -Clean      # 先删 build\windows 再构建（改 native 配置后用）
#   pwsh -File scripts/build-windows.ps1 -SkipPubGet # 依赖没变时跳过 pub get
#
# 产物：build\windows\x64\runner\Release\mint_image.exe
# 数据目录：与 exe 同级的 data\（便携模式，见 lib/core/services/app_paths.dart）
[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# ---- 工具链定位 -------------------------------------------------------------
# flutter.bat 必须带 --no-version-check，否则会因联网做版本检查而长时间挂死。
$flutter = 'C:\src\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) {
    $cmd = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($cmd) { $flutter = $cmd.Source }
}
if (-not (Test-Path $flutter)) {
    throw "找不到 flutter.bat，请确认 Flutter SDK 路径"
}

# 国内镜像：直连 pub.dev 会 SSL 失败；走代理也不稳，镜像最可靠。
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:CI = 'true'

Write-Host "flutter : $flutter"
Write-Host "repo    : $repo"

# ---- 依赖 -------------------------------------------------------------------
if (-not $SkipPubGet) {
    Write-Host "`n=== dart pub get ===" -ForegroundColor Cyan
    if ($Clean) {
        # 清理后必须重新解析依赖
        & $flutter --no-version-check pub get
    } else {
        & $flutter --no-version-check pub get
    }
    if ($LASTEXITCODE -ne 0) {
        throw "pub get 失败（退出码 $LASTEXITCODE）。检查网络/镜像或 pubspec.yaml。"
    }
}

# ---- 清理 -------------------------------------------------------------------
if ($Clean) {
    Write-Host "`n=== 清理 build\windows ===" -ForegroundColor Cyan
    if (Test-Path 'build\windows') {
        Remove-Item -Recurse -Force 'build\windows'
    }
}

# ---- 构建 -------------------------------------------------------------------
# 注意：构建前先关掉正在运行的 mint_image.exe，否则链接阶段会报
#       LNK1104: 无法打开文件 ...\mint_image.exe
$running = Get-Process -Name mint_image -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "`n=== 关闭正在运行的实例 ===" -ForegroundColor Yellow
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

Write-Host "`n=== flutter build windows --release ===" -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()
# Windows Release 保留完整 Material 图标字体，防止增量构建的裁剪字体遗漏新增图标。
# 该问题不会被 widget test / analyze 捕获，必须校验最终字体产物。
& $flutter --no-version-check build windows --release --no-tree-shake-icons
$exit = $LASTEXITCODE
$sw.Stop()

if ($exit -ne 0) {
    throw "构建失败（退出码 $exit）"
}

$exe = Join-Path $repo 'build\windows\x64\runner\Release\mint_image.exe'
Write-Host "`n构建成功，用时 $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
Write-Host "exe : $exe"
Write-Host "data: $(Join-Path (Split-Path $exe) 'data')"
