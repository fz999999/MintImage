# 默认工作流：构建 Release 并直接运行给用户看（不打包）
#
# 用法：
#   pwsh -File scripts/run-windows.ps1              # 增量构建 + 启动
#   pwsh -File scripts/run-windows.ps1 -Clean       # 全量重建 + 启动
#   pwsh -File scripts/run-windows.ps1 -NoBuild     # 只启动已有产物
#
# 这条路径之所以足够：Release 产物就在 build\windows\x64\runner\Release\
# 数据写在同级的 data\ 里，改动 UI 后构建 30~60s 即可看到效果。
# 只有「交付给别人」或用户明确要求时才走 scripts/package-windows.ps1。
[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$exe = Join-Path $repo 'build\windows\x64\runner\Release\mint_image.exe'

if (-not $NoBuild) {
    $buildArgs = @('-File', (Join-Path $PSScriptRoot 'build-windows.ps1'))
    if ($Clean) { $buildArgs += '-Clean' }
    & pwsh -NoProfile @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "构建失败" }
}

if (-not (Test-Path $exe)) {
    throw "找不到 $exe，先执行不带 -NoBuild 的命令"
}

Get-Process -Name mint_image -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru
Start-Sleep -Seconds 6
$proc.Refresh()

Write-Host "`n=== 已启动 ===" -ForegroundColor Green
Write-Host "pid   : $($proc.Id)"
Write-Host "title : $($proc.MainWindowTitle)"
Write-Host "running: $(-not $proc.HasExited)"
Write-Host "data  : $(Join-Path (Split-Path $exe) 'data')"
