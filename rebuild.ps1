$ErrorActionPreference = 'Continue'

# 清理之前的构建
if (Test-Path 'build\windows') {
    Remove-Item -Recurse -Force 'build\windows' -ErrorAction SilentlyContinue
}

# 设置环境变量
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:CI = 'true'

# 重新获取依赖
Write-Host "=== Getting dependencies ===" -ForegroundColor Cyan
& 'C:\src\flutter\bin\flutter.bat' --no-version-check pub get --offline

if ($LASTEXITCODE -ne 0) {
    Write-Host "Pub get failed, trying online..." -ForegroundColor Yellow
    & 'C:\src\flutter\bin\flutter.bat' --no-version-check pub get
}

# 构建
Write-Host "`n=== Building Windows Release ===" -ForegroundColor Cyan
& 'C:\src\flutter\bin\flutter.bat' --no-version-check build windows --release

exit $LASTEXITCODE
