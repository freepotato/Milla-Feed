#!/usr/bin/env bash
# 在 macOS / Linux 上验证 MillaCore（无需 Xcode 或模拟器）。
# 用法: Scripts/verify-core.sh
set -euo pipefail

cd "$(dirname "$0")/../Packages/MillaCore"

echo "==> 1/2 内置自检（milla-cli verify，零第三方依赖）"
swift run milla-cli verify

echo ""
echo "==> 2/2 XCTest 单元测试"
if swift test; then
  echo "✅ swift test 通过"
else
  echo "⚠️  swift test 失败（若机器只装了 Command Line Tools，XCTest 随完整 Xcode 提供；"
  echo "   此时上一步 milla-cli verify 已覆盖核心逻辑，Windows/Linux OSS 工具链同样可跑 swift test）"
  exit 1
fi
