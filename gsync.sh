#!/bin/bash
#
# gsync.sh — STMarkdown 与 STBaseProject 分支联动同步脚本
#
# 用法：
#   ./gsync.sh <branch>       切换 STMarkdown 与 STBaseProject 到同一分支
#   ./gsync.sh -b <branch>    新建并切换到该分支（两边同步创建同名分支）
#   ./gsync.sh auto           把 STBaseProject 同步到 STMarkdown 当前分支（供 git hook 调用）
#   ./gsync.sh                不带参数：仅打印两个仓库当前分支状态
#
# 分支对应规则：
#   STMarkdown 的任意分支  <->  STBaseProject 的同名分支
#   例如 feature_2.0.0 <-> feature_2.0.0，main <-> main，新增分支自动同名对应。
#
# 说明：
#   STMarkdown 通过本地路径依赖 STBaseProject（见 Package.swift）：
#     .package(name: "STBaseProject", path: "../STBaseProject")
#   因此 STMarkdown 直接使用 STBaseProject 本地仓库的当前 git 状态。
#   切换 STMarkdown 分支时，需同步 STBaseProject 的分支，否则会用错代码。
#
# 退出码：
#   0  两个仓库最终均处于目标分支（或无参数状态查询且 Base 可用）
#   非0 同步失败（如 checkout/pull 出错、Base 缺失或无法同步到同名分支、最终状态不一致）

set -uo pipefail

# 脚本所在目录即 STMarkdown 仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKDOWN_DIR="$SCRIPT_DIR"

# STBaseProject 路径：默认放在 STMarkdown 同级目录，可用环境变量 STBASE_PATH 覆盖
# （开源共享时他人目录布局可能不同，故支持自定义）
if [ -n "${STBASE_PATH:-}" ]; then
  BASE_DIR="${STBASE_PATH}"
else
  BASE_DIR="${SCRIPT_DIR}/../STBaseProject"
fi

BASE_ENABLED=1
if [ ! -d "${BASE_DIR}/.git" ]; then
  BASE_ENABLED=0
fi

current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(detached)"
}

print_status() {
  echo "📦 STMarkdown    : $(current_branch "$MARKDOWN_DIR")  ($MARKDOWN_DIR)"
  if [ "$BASE_ENABLED" -eq 1 ]; then
    echo "📦 STBaseProject : $(current_branch "$BASE_DIR")  ($BASE_DIR)"
  else
    echo "📦 STBaseProject : (未找到仓库，期望路径: ${BASE_DIR})"
  fi
}

# 确认 STBaseProject 当前确实处于目标分支，否则返回非零
assert_base_on() {
  local BRANCH="$1"
  if [ "$BASE_ENABLED" -ne 1 ]; then
    echo "❌ STBaseProject 仓库不存在（期望路径: ${BASE_DIR}），无法同步到 '$BRANCH'。" >&2
    return 1
  fi
  local ACTUAL
  ACTUAL="$(current_branch "$BASE_DIR")"
  if [ "$ACTUAL" != "$BRANCH" ]; then
    echo "❌ STBaseProject 实际位于 '$ACTUAL'，未能同步到 '$BRANCH'。" >&2
    return 1
  fi
  return 0
}

# 确保 STBaseProject 处于同名分支 $1（先 fetch 远端，避免陈旧引用误判）。
# 本地有则切；origin 有则跟踪；都无则基于当前 HEAD 新建。
# 返回：0 成功且最终确实处于该分支；非0 失败（含 Base 缺失、fetch 后远端也无且不允许新建）
ensure_base_branch() {
  local BRANCH="$1"
  local ALLOW_CREATE="${2:-1}"   # 1=允许基于 HEAD 新建；0=仅切换/跟踪，不允许新建

  if [ "$BASE_ENABLED" -ne 1 ]; then
    echo "❌ STBaseProject 仓库不存在（期望路径: ${BASE_DIR}），无法同步到 '$BRANCH'。" >&2
    return 1
  fi

  # 先定向拉取远端引用，避免把“本地尚未 fetch 的真实远端分支”误判为不存在
  echo "🔄 核验 STBaseProject 远端分支..."
  git -C "$BASE_DIR" fetch origin --quiet || echo "⚠️  fetch origin 失败，将以本地缓存判断。" >&2

  if git -C "$BASE_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "🔀 切换 STBaseProject 到分支: $BRANCH (本地已存在)"
    git -C "$BASE_DIR" checkout "$BRANCH" || return 1
  elif git -C "$BASE_DIR" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    echo "🔀 切换 STBaseProject 到分支: $BRANCH (从 origin 跟踪)"
    git -C "$BASE_DIR" checkout -B "$BRANCH" "origin/$BRANCH" || return 1
  elif [ "$ALLOW_CREATE" = "1" ]; then
    echo "🌱 在 STBaseProject 基于当前 HEAD 新建分支: $BRANCH"
    git -C "$BASE_DIR" checkout -b "$BRANCH" || return 1
  else
    echo "❌ STBaseProject 不存在分支 '$BRANCH'（本地/远端均无），无法同步。" >&2
    echo "    请先在 STBaseProject 创建该分支，或手动处理。" >&2
    return 1
  fi

  # 若已跟踪远端，尝试快进拉取最新；失败须显式报错并返回非零
  if git -C "$BASE_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    echo "⬇️  拉取 STBaseProject 最新代码..."
    if ! git -C "$BASE_DIR" pull --ff-only; then
      echo "❌ STBaseProject pull 失败（可能有未提交改动或冲突），请手动处理。" >&2
      return 1
    fi
  fi

  assert_base_on "$BRANCH" || return 1
  return 0
}

# 无参数：仅打印状态（Base 缺失时此处可成功，但会明确标注未找到）
if [ "$#" -eq 0 ]; then
  if [ "$BASE_ENABLED" -ne 1 ]; then
    echo "⚠️  STBaseProject 仓库不存在（期望路径: ${BASE_DIR}）。" >&2
    echo "    可通过环境变量指定：STBASE_PATH=/path/to/STBaseProject ./gsync.sh" >&2
  fi
  print_status
  exit 0
fi

MODE="$1"; shift

case "$MODE" in
  auto)
    # 供 post-checkout hook 调用：同步到 STMarkdown 当前分支
    BRANCH="$(current_branch "$MARKDOWN_DIR")"
    if [ "$BRANCH" = "(detached)" ]; then
      echo "ℹ️  STMarkdown 处于 detached HEAD，不联动 STBaseProject。"
      exit 0
    fi
    if ensure_base_branch "$BRANCH" 0; then
      echo ""
      echo "✅ 联动完成，当前状态："
      print_status
      exit 0
    else
      echo ""
      echo "⚠️  联动未完成，当前状态：" >&2
      print_status >&2
      exit 1
    fi
    ;;
  -b)
    BRANCH="${1:-}"
    if [ -z "$BRANCH" ]; then
      echo "用法: ./gsync.sh -b <branch>" >&2
      exit 1
    fi
    # 在 STMarkdown 创建并切换（禁用 hook，避免重复同步，由本脚本统一处理）
    echo "🔀 在 STMarkdown 创建并切换到新分支: $BRANCH"
    STBASE_DISABLE_SYNC=1 git -C "$MARKDOWN_DIR" checkout -b "$BRANCH" || {
      echo "❌ STMarkdown 创建分支 '$BRANCH' 失败。" >&2; exit 1; }

    # 在 STBaseProject 也创建同名分支（统一走 ensure_base_branch，自动 fetch 远端）
    if ensure_base_branch "$BRANCH" 1; then
      echo ""
      echo "✅ 切换完成，当前状态："
      print_status
      exit 0
    else
      echo ""
      echo "⚠️  切换未完成，当前状态：" >&2
      print_status >&2
      exit 1
    fi
    ;;
  -*)
    echo "未知选项: $MODE" >&2
    exit 1
    ;;
  *)
    BRANCH="$MODE"
    # 在 STMarkdown 切换（禁用 hook，避免重复同步，由本脚本统一处理）
    echo "🔀 切换 STMarkdown 到分支: $BRANCH"
    STBASE_DISABLE_SYNC=1 git -C "$MARKDOWN_DIR" checkout "$BRANCH" || {
      echo "❌ STMarkdown 切换分支 '$BRANCH' 失败。" >&2; exit 1; }

    if ensure_base_branch "$BRANCH" 0; then
      echo ""
      echo "✅ 切换完成，当前状态："
      print_status
      exit 0
    else
      echo ""
      echo "⚠️  切换未完成，当前状态：" >&2
      print_status >&2
      exit 1
    fi
    ;;
esac
