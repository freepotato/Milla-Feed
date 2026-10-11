#!/usr/bin/env bash
# release-please 合入并打出 Git tag 后，在 Mac 上执行本脚本：
# 读取最新 vX.Y.Z tag -> 写入 project.yml -> 重新生成 Xcode 工程。
# 用法: Scripts/sync-version.sh
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
if [[ -z "${TAG}" ]]; then
  echo "未找到 Git tag，保持 project.yml 默认版本" >&2
  exit 0
fi

VERSION="${TAG#v}"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "最新 tag ${TAG} 不是 vX.Y.Z 形式，跳过" >&2
  exit 0
fi

# 构建号 = 当前提交总数（单调递增）
BUILD="$(git rev-list --count HEAD)"

echo "同步版本: ${VERSION} (${BUILD})"

python3 - "${VERSION}" "${BUILD}" <<'PY'
import re, sys
version, build = sys.argv[1], sys.argv[2]
path = "project.yml"
text = open(path, encoding="utf-8").read()
text = re.sub(r'MARKETING_VERSION: "[^"]+"', f'MARKETING_VERSION: "{version}"', text)
text = re.sub(r'CURRENT_PROJECT_VERSION: "[^"]+"', f'CURRENT_PROJECT_VERSION: "{build}"', text)
open(path, "w", encoding="utf-8").write(text)
PY

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "未安装 xcodegen：brew install xcodegen" >&2
  exit 1
fi

xcodegen generate
echo "✅ Milla.xcodeproj 已更新到 ${VERSION} (${BUILD})"
