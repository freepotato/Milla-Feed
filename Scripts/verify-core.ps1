# 在 Windows 上验证 MillaCore（无需 Xcode / iOS 运行时）。
# 用法: powershell -ExecutionPolicy Bypass -File Scripts\verify-core.ps1
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root "Packages\MillaCore")

try {
    Write-Host "==> 1/2 内置自检（milla-cli verify）" -ForegroundColor Cyan
    swift run milla-cli verify
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host ""
    Write-Host "==> 2/2 XCTest 单元测试" -ForegroundColor Cyan
    swift test
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host ""
    Write-Host "也可以运行下面命令，用真实 RSS 样例验证排序：" -ForegroundColor Green
    Write-Host "  swift run milla-cli rank ..\..\Fixtures"
}
finally {
    Pop-Location
}
