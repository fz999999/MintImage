# Windows 分发包打包（仅在明确要求交付时才用）
#
# 用法：
#   pwsh -File scripts/package-windows.ps1           # 用已有 Release 产物打包
#   pwsh -File scripts/package-windows.ps1 -Build    # 先构建再打包
#
# 产出：
#   dist\大川生图工具-windows-x64-v<版本>.zip
#   dist\README-大川生图工具-windows-x64-v<版本>.txt
#
# 关键规则：包里只带运行必需文件，**绝不带用户的 data 数据**
#   data\ 里只放 flutter_assets\、app.so、icudtl.dat
#   排除 mint_image.sqlite / shared_preferences.json / *.jsonl / generated_images\
[CmdletBinding()]
param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if ($Build) {
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'build-windows.ps1')
    if ($LASTEXITCODE -ne 0) { throw "构建失败" }
}

$releaseDir = Join-Path $repo 'build\windows\x64\runner\Release'
$exe = Join-Path $releaseDir 'mint_image.exe'
if (-not (Test-Path $exe)) {
    throw "找不到 $exe，先运行 scripts\build-windows.ps1"
}

# 版本号取自 pubspec.yaml（形如 1.0.0+1 → 1.0.0）
$versionLine = Select-String -Path (Join-Path $repo 'pubspec.yaml') -Pattern '^version:\s*(\S+)' |
    Select-Object -First 1
$version = if ($versionLine) { $versionLine.Matches[0].Groups[1].Value.Split('+')[0] } else { '0.0.0' }

$appName = "大川生图工具-windows-x64-v$version"
$distDir = Join-Path $repo 'dist'
$staging = Join-Path $distDir $appName

Write-Host "=== 打包 $appName ===" -ForegroundColor Cyan

# 增量重建时 body 可能被占用，先关掉实例，避免复制到半写文件
Get-Process -Name mint_image -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

# ---- exe + 所有 DLL（自动探测，避免漏掉新增插件）----------------------------
Copy-Item $exe $staging
Get-ChildItem $releaseDir -Filter *.dll -File | ForEach-Object {
    Copy-Item $_.FullName $staging
    Write-Host "  + $($_.Name)" -ForegroundColor DarkGray
}

# ---- data：只带运行必需的三项 ----------------------------------------------
$dataSrc = Join-Path $releaseDir 'data'
$dataDst = Join-Path $staging 'data'
New-Item -ItemType Directory -Path $dataDst -Force | Out-Null

foreach ($item in @('flutter_assets', 'app.so', 'icudtl.dat')) {
    $src = Join-Path $dataSrc $item
    if (Test-Path $src) {
        Copy-Item $src $dataDst -Recurse
        Write-Host "  + data\$item" -ForegroundColor DarkGray
    } else {
        throw "data\$item 缺失，构建产物不完整"
    }
}

# ---- README -----------------------------------------------------------------
$readme = @"
大川生图工具 v$version - Windows x64
================================================

便携版：所有运行时数据都保存在 exe 同级的 data 目录里，不写注册表、不写 AppData。

使用方法
--------
1. 解压整个文件夹到任意位置（路径随便，含中文也没问题）
2. 双击 mint_image.exe
3. 首次启动会自动创建 data 目录，进入设置页填写 Base URL 与 API Key

数据位置（都在 data\ 下）
------------------------
- 数据库      data\mint_image.sqlite
- 生成图片    data\generated_images\
- 设置        data\shared_preferences.json
- 请求日志    data\mint_image_request_logs.jsonl

整包备份/换机器：直接把整个文件夹复制走即可。
从旧版本升级：把旧包的 data 目录覆盖到新包同位置即可保留历史记录。

说明
----
- 每个 API 配置可绑定多个模型，主界面「渠道」「模型」两个按钮可随时切换
- 旧版（%APPDATA%\com.aiqin\MintImage）的数据会在首次启动时自动迁移
"@

$readmePath = Join-Path $distDir "README-$appName.txt"
$readme | Out-File -FilePath $readmePath -Encoding UTF8

# ---- 压缩 -------------------------------------------------------------------
$zipPath = Join-Path $distDir "$appName.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "`n压缩中..." -ForegroundColor Cyan
Compress-Archive -Path $staging -DestinationPath $zipPath -CompressionLevel Optimal

$zipInfo = Get-Item $zipPath
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash

Write-Host "`n=== 打包完成 ===" -ForegroundColor Green
Write-Host "zip  : $($zipInfo.FullName)"
Write-Host "size : $([math]::Round($zipInfo.Length / 1MB, 2)) MB"
Write-Host "sha256: $hash"

# ---- 自检：确认没有把用户数据打进去 ------------------------------------------
$leaked = Get-ChildItem $staging -Recurse -File | Where-Object {
    $_.Name -match '\.sqlite$|shared_preferences\.json$|\.jsonl$'
}
if ($leaked) {
    Write-Host "`n[警告] 包内出现用户数据文件：" -ForegroundColor Red
    $leaked | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Red }
    throw "打包内容不干净，终止"
}
Write-Host "自检通过：包内无用户数据" -ForegroundColor Green
