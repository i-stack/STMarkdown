#!/usr/bin/env bash
set -euo pipefail

# 守护 STMarkdown 包中已被删除的旧 API，防止被误用/回潮。
# 与 STBaseProject/.github/check_removed_api.sh 保持同一风格。
#
# 注意：firstLineIndent 当前仍以「局部变量」形式存在于
#   STMarkdownTypography.swift / STMarkdownAttributedStringRenderer.swift 中（正常实现，
#   不应被监控）。这里只匹配「作为 API 形态」的引用：
#     \.firstLineIndent   —— 点语法成员访问 / 赋值（被删的列表缩进 API 属性）
#     firstLineIndent:    —— 参数 / 字典 / 尾随闭包键（被删的无效属性）
#   不监控裸 `let firstLineIndent`，避免误伤正常局部变量。
readonly SEARCH_ROOTS=(Sources Tests)

readonly REMOVED_API_PATTERN='\bSTMarkdownCircleNumberAttachment\b|\bdefaultAdvancedRenderers\b|\.firstLineIndent\b|firstLineIndent:'

if rg --line-number --glob '*.swift' "$REMOVED_API_PATTERN" "${SEARCH_ROOTS[@]}"; then
  echo "::error::Removed API usage detected in STMarkdown. Use the current public API directly."
  exit 1
fi

echo "STMarkdown removed API check passed."
