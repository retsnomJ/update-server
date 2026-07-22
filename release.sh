#!/usr/bin/env bash
# release.sh — 一键发布新版本到 GitHub Release
#
# 用途：创建 GitHub Release + 上传 APK + 更新 version.json
# 前置：gh auth login；已在 retsnomj/update-server 仓库有 push 权限
#
# 用法：./release.sh <versionName> <versionCode> <changelog> <apk-path>
# 例子：./release.sh 1.0.1 2 "修复盘点单保存异常" ../path/to/app-release.apk

set -euo pipefail

if [ $# -lt 4 ]; then
    echo "Usage: $0 <versionName> <versionCode> <changelog> <apk-path>"
    echo "Example: $0 1.0.1 2 \"修复盘点单保存异常\" ../app-release.apk"
    exit 1
fi

VERSION_NAME="$1"
VERSION_CODE="$2"
CHANGELOG="$3"
APK_PATH="$4"
REPO="retsnomj/update-server"
APK_NAME="fastmes-pda.apk"
TAG="v${VERSION_NAME}"

# ===== 校验输入 =====
if [ ! -f "$APK_PATH" ]; then
    echo "ERROR: APK 文件不存在: $APK_PATH"
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh (GitHub CLI) 未安装，请先安装：brew install gh"
    exit 1
fi

echo "=========================================="
echo "  准备发版 v${VERSION_NAME} (code=${VERSION_CODE})"
echo "=========================================="
echo "  仓库:  ${REPO}"
echo "  Tag:   ${TAG}"
echo "  APK:   ${APK_PATH} -> ${APK_NAME}"
echo "  说明:  ${CHANGELOG}"
echo ""
read -rp "确认发布？[y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[yY]$ ]] || { echo "已取消"; exit 0; }

# ===== 1. 创建 Release 并上传 APK =====
echo ""
echo "→ [1/3] 创建 GitHub Release ${TAG}..."
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "  Release ${TAG} 已存在，上传 APK 到 Assets..."
    gh release upload "$TAG" "${APK_PATH}#${APK_NAME}" --repo "$REPO" --clobber
else
    gh release create "$TAG" \
        "${APK_PATH}#${APK_NAME}" \
        --repo "$REPO" \
        --title "${TAG}" \
        --notes "${CHANGELOG}"
fi
echo "✓ Release 创建/更新成功"

# ===== 2. 更新 version.json =====
echo ""
echo "→ [2/3] 更新 version.json..."
APK_SIZE=$(stat -f%z "${APK_PATH}" 2>/dev/null || stat -c%s "${APK_PATH}")
PUBLISHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > version.json <<EOF
{
  "versionCode": ${VERSION_CODE},
  "versionName": "${VERSION_NAME}",
  "changelog": "${CHANGELOG}",
  "apkUrl": "/${REPO}/releases/latest/download/${APK_NAME}",
  "apkSize": ${APK_SIZE},
  "publishedAt": "${PUBLISHED_AT}"
}
EOF
echo "✓ version.json 已更新"
cat version.json

# ===== 3. 提交并 push =====
echo ""
echo "→ [3/3] 提交并推送 version.json..."
git add version.json
if git diff --cached --quiet; then
    echo "  version.json 无变化，跳过 commit"
else
    git commit -m "release: v${VERSION_NAME} (code=${VERSION_CODE})"
    git push origin main
    echo "✓ 已推送到 main"
fi

echo ""
echo "=========================================="
echo "  ✓ 发布完成"
echo "=========================================="
echo "  Release: https://github.com/${REPO}/releases/tag/${TAG}"
echo "  version.json: https://raw.githubusercontent.com/${REPO}/main/version.json"
echo "  APK 直链:   https://github.com/${REPO}/releases/latest/download/${APK_NAME}"
echo ""
echo "  客户端下次启动即可拉到新版本（versionCode ${VERSION_CODE} > 当前）"