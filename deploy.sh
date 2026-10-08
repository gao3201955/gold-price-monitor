#!/usr/bin/env bash
# ============================================================
#  黄金价格监控 · GitHub Pages 一键部署脚本
#  把当前目录的 index.html 部署成永久公开网址：
#      https://<你的用户名>.github.io/<仓库名>/
#
#  前置依赖：git、curl、jq（macOS: brew install jq; Linux: apt install jq）
#
#  使用方法（二选一）：
#  ── 方式 A：自己本地跑 ─────────────────────────────
#     export GITHUB_USER=你的GitHub用户名
#     export GITHUB_TOKEN=你的Token(需 repo + pages 权限)
#     bash deploy.sh
#  ── 方式 B：自定义仓库名 ───────────────────────────
#     REPO_NAME=my-gold bash deploy.sh
#
#  Token 权限说明：
#    · Classic PAT 勾选 repo（全部）
#    · 或 Fine-grained 勾选 Contents 读写 + Pages 读写 + Metadata 读
#  部署后页面是公开的；Token 用完后可在 GitHub 设置里随时撤销。
# ============================================================
set -euo pipefail

REPO_NAME="${REPO_NAME:-gold-price-monitor}"
REPO_DESC="${REPO_DESC:-黄金价格监控 · 实时国际/国内金价}"
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
SRC_DIR="${SRC_DIR:-$(cd "$(dirname "$0")" && pwd)}"
BRANCH="main"
API="https://api.github.com"
AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json")

echo "📦 源目录: $SRC_DIR"
[[ -f "$SRC_DIR/index.html" ]] || { echo "❌ 未找到 $SRC_DIR/index.html"; exit 1; }
[[ -n "$GITHUB_USER" && -n "$GITHUB_TOKEN" ]] || {
  echo "❌ 请先设置环境变量 GITHUB_USER 与 GITHUB_TOKEN"; exit 1; }

echo "🚀 创建/确认仓库 $GITHUB_USER/$REPO_NAME ..."
HTTP=$(curl -s -o /tmp/gh_repo.json -w "%{http_code}" "${AUTH[@]}" -X POST \
  "$API/user/repos" -d "{\"name\":\"$REPO_NAME\",\"description\":\"$REPO_DESC\",\"private\":false,\"auto_init\":false}")
if [[ "$HTTP" != "201" ]]; then
  EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH[@]}" -X GET "$API/repos/$GITHUB_USER/$REPO_NAME")
  if [[ "$EXISTS" != "200" ]]; then
    echo "❌ 仓库创建失败 (HTTP $HTTP):"; cat /tmp/gh_repo.json; exit 1
  fi
fi
echo "✅ 仓库就绪"

echo "📤 推送 index.html 到 $BRANCH ..."
cd "$SRC_DIR"
rm -rf .git
git init -q
git config user.email "deploy@local"
git config user.name "Gold Monitor"
git checkout -q -B "$BRANCH"
git add -A
git commit -q -m "deploy gold price monitor" || true
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git"
git push -q -f origin "$BRANCH"
echo "✅ 代码已推送"

echo "⚙️  启用 GitHub Pages ..."
curl -s -o /tmp/gh_pages.json -w "Pages API HTTP %{http_code}\n" "${AUTH[@]}" -X POST \
  "$API/repos/$GITHUB_USER/$REPO_NAME/pages" \
  -d "{\"source\":{\"branch\":\"$BRANCH\",\"path\":\"/\"}}" >/dev/null
echo "Pages 响应:"; jq -r '.html_url // .message // .' /tmp/gh_pages.json 2>/dev/null || cat /tmp/gh_pages.json

echo ""
echo "🎉 部署已提交！GitHub Pages 通常需要 1~3 分钟首次构建。"
echo "🌐 你的永久独立网址："
echo "   https://$GITHUB_USER.github.io/$REPO_NAME/"
