# STMarkdown

> **High-fidelity streaming Markdown rendering framework for iOS** — built on native UIKit `UITextView`, with tables, LaTeX math, Mermaid, footnotes, code highlighting and character-by-character streaming animation. Supports Swift Package Manager.

[![License](https://img.shields.io/badge/license-MIT-green?style=flat)](https://github.com/i-stack/STMarkdown/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-lightgrey?style=flat)](https://github.com/i-stack/STMarkdown)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-orange?style=flat-square)](https://www.swift.org)
[![SPM](https://img.shields.io/badge/SPM-supported-brightgreen?style=flat)](https://github.com/i-stack/STMarkdown)
[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue?style=flat)](https://github.com/i-stack/STMarkdown)
[![Xcode](https://img.shields.io/badge/Xcode-15%2B-147EFB?style=flat)](https://developer.apple.com/xcode/)

**STMarkdown** is an open-source **iOS Markdown rendering library** written in **Swift**, built on native UIKit `UITextView`. It supports **tables, LaTeX math, Mermaid diagrams, footnotes, citations, code highlighting, TOC anchors** and **character-by-character streaming animation** — designed for AI chat / streaming reply scenarios.

STMarkdown 是一个面向 iOS 16+ 的高保真、流式 Markdown 渲染框架，基于 UIKit 原生 `UITextView` 构建，支持表格、LaTeX 数学公式、Mermaid、脚注、引用、代码高亮、目录锚点以及逐字流式动画。

## 📋 目录 | Table of Contents

- [特性 | Features](#features)
- [安装方式 | Installation](#installation)
- [快速开始 | Getting Started](#quick-start)
  - [静态渲染（UIKit）](#static-uikit)
  - [静态渲染（SwiftUI）](#static-swiftui)
  - [流式渲染 | Streaming](#streaming)
- [样式与预设 | Style & Presets](#style-presets)
- [高级渲染器 | Advanced Renderers](#advanced-renderers)
- [架构概览 | Architecture](#architecture)
- [流式渲染机制 | Streaming Internals](#streaming-internals)
- [高度稳定 | Height Stability](#height-stability)
- [许可证 | License](#license)

<a id="features"></a>
## 🎯 特性 | Features

| 类别 | 能力 |
| --- | --- |
| 核心渲染 | CommonMark / GFM 解析（`swift-markdown`），`NSAttributedString` 输出 |
| 文本元素 | 标题、列表、引用、分隔线、脚注、行内/块级代码、链接、图片占位 |
| 数学公式 | 行内与块级 LaTeX，语法降级（`STMarkdownLatexSyntaxNormalizer`），iosMath / KaTeX 渲染 |
| 表格 | GFM 表格附件、`STMarkdownTableAttachmentRenderer`、可展开行 |
| 图表 | Mermaid 附件（`STMarkdownMermaidAttachmentFactory`） |
| 代码高亮 | JavaScriptCore 引擎 + 私有串行队列 + `NSCache`（10MB），支持行号与全高代码块 |
| 目录 | TOC 锚点（`STMarkdownTOC`） |
| 流式渲染 | 直接追加 fragment 或智能缓冲 `STMarkdownStreamBuffer`，字符级淡入动画（`STShimmerTextView`） |
| 接入方式 | UIKit 原生 `STMarkdownTextView` / `STMarkdownStreamingTextView`，以及 SwiftUI 包装 `STMarkdownSwiftUIView` |
| 无障碍 | 链接点击、脚注点击、引用点击、选区变化等回调 |

<a id="installation"></a>
## 🚀 安装方式 | Installation

### Swift Package Manager

在 `Package.swift` 中声明依赖（发布时指向远程仓库）：

```swift
dependencies: [
    .package(url: "https://github.com/i-stack/STMarkdown.git", from: "1.6.0"),
    // 注意：STMarkdown 依赖 STBaseProject 的部分基础能力
    .package(url: "https://github.com/i-stack/STBaseProject.git", from: "1.6.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "STMarkdown", package: "STMarkdown"),
            .product(name: "STBaseProject", package: "STBaseProject")
        ]
    )
]
```

> 仓库当前 `Package.swift` 以本地路径 `path: "../STBaseProject"` 引用 `STBaseProject`，便于同仓联调；**发布前请改为上方的远程 URL**。

核心依赖：

- [`swift-markdown`](https://github.com/swiftlang/swift-markdown) `from: 0.8.0` — 解析引擎
- [`SwiftMath`](https://github.com/mgriebling/SwiftMath) `revision: 48ff188…` — LaTeX 公式渲染

**系统要求**：iOS 16.0+ / Swift 5.9+ / Xcode 15+

<a id="quick-start"></a>
## ⚡ 快速开始 | Getting Started

<a id="static-uikit"></a>
### 静态渲染（UIKit）

```swift
import STMarkdown

let textView = STMarkdownTextView(
    style: .default,
    advancedRenderers: STMarkdownPresets.makeDefaultAdvancedRenderers(),
    engine: STMarkdownEngine()
)
textView.setMarkdown("# 标题\n\n这是 **加粗** 与 *斜体* 文本。")
view.addSubview(textView)
```

<a id="static-swiftui"></a>
### 静态渲染（SwiftUI）

```swift
import SwiftUI
import STMarkdown

struct ContentView: View {
    var body: some View {
        STMarkdownSwiftUIView(
            markdown: "# Hello\n\n- 列表项 A\n- 列表项 B",
            style: .article,
            advancedRenderers: STMarkdownPresets.makeDefaultAdvancedRenderers(),
            onLinkTap: { url in
                UIApplication.shared.open(url)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

> `STMarkdownSwiftUIView` 提供 `onLinkTap`、`onFootnoteTap`、`onCitationTap`、`onSelectionChange`、`onExpandTable` 等回调，并支持 `isTextSelectionEnabled`。

<a id="streaming"></a>
### 流式渲染 | Streaming

`STMarkdownStreamingTextView` 提供两条流式路径：

**路径 A — 直接追加 fragment**（每片都触发渲染 + 字符级 diff 动画）：

```swift
let streamView = STMarkdownStreamingTextView(style: .default)
streamView.setMarkdown("")                  // 初始化空内容
streamView.appendMarkdownFragment("模型正在", animated: true)
streamView.appendMarkdownFragment("生成 **流式** Markdown…", animated: true)
```

**路径 B — 智能缓冲（推荐）**：`STMarkdownStreamBuffer` 累积 chunk，只提交结构安全的「已闭合前缀」（`committedSafePrefix`），前缀单调增长时走增量解析，降低流式 CPU 占用。

```swift
let streamView = STMarkdownStreamingTextView(
    style: .default,
    advancedRenderers: STMarkdownPresets.makeDefaultAdvancedRenderers()
)

streamView.beginSmartMarkdownStreaming()                 // 开启智能缓冲会话
// 在上游 chunk 回调中：
streamView.appendSmartMarkdownStreamingChunk(chunk)      // 累积并智能渲染安全前缀
// 流结束时：
streamView.endSmartMarkdownStreaming(flushPending: true) // 冲刷尾部未闭合片段
```

关键属性：

- `tokenFadeDuration` — 单字符淡入时长，默认 `0.3s`
- `animateAcrossNewlines` — 是否跨行继续动画（默认 `false` 仅最后一行动画）
- `streamingAnimationWatchdogTimeout` — 兜底超时（默认 `4.0s`），超时强制收口
- `isSmartMarkdownStreamingActive` / `isStreamingAnimationIdle` — 会话与动画状态查询

<a id="style-presets"></a>
## 🎨 样式与预设 | Style & Presets

`STMarkdownStyle` 统一控制字体、颜色、行高、字距、列表缩进、标题倍率等排版字段。内置预设：

- `STMarkdownStyle.default` — 默认样式
- `STMarkdownPresets.article` — 正文阅读样式（17pt / 行高 26）
- `STMarkdownPresets.compact` — 紧凑样式（14pt / 行高 20）

字体变体由 `STMarkdownFontResolver` 基于 `fontDescriptor.withSymbolicTraits` 推导；缺少真实 italic / boldItalic 时通过 `obliqueness` 视觉补偿。

<a id="advanced-renderers"></a>
## 🧩 高级渲染器 | Advanced Renderers

高级渲染器（图片、表格、代码块、数学等）通常持有内部缓存或可变状态，**每个调用方应持有自己的实例**，避免跨场景共享造成并发污染。请使用工厂方法：

```swift
let renderers = STMarkdownPresets.makeDefaultAdvancedRenderers()
// 包含：inline/block 数学、代码块、表格、图片、分隔线渲染器
```

> 旧 `STMarkdownPresets.defaultAdvancedRenderers` 因共享实例风险已标记 `@available(*, deprecated)`，请改用工厂方法。

<a id="architecture"></a>
## 🏗 架构概览 | Architecture

仓库按职责划分为以下模块（`Sources/STMarkdown/`）：

| 目录 | 职责 |
| --- | --- |
| `Core/` | 引擎 `STMarkdownEngine`、流水线 `STMarkdownPipeline`、增量解析、样式/排版、TOC、流式缓冲 `STMarkdownStreamBuffer`、高度协调 |
| `Parsing/` | 结构解析 `STMarkdownStructureParser`、推测重写（流式 emphasis / table rewriter）、AST 转渲染块 |
| `Rendering/` | `NSAttributedString` 渲染、`STMarkdownPlainTextRenderer`、HTML 预览、Mermaid/代码块附件工厂 |
| `Table/` | GFM 表格附件与视图模型 |
| `Attachments/` | 图片、脚注、引用、数学等附件 |
| `UI/` | `STMarkdownTextView`、`STMarkdownStreamingTextView`、`STMarkdownBaseTextView`、`STMarkdownSwiftUIView`、`STMarkdownTextViewMeasure` |

渲染流水线：`sanitize → parse → normalize → adapt`，由 `STMarkdownEngine.process(_:)` 返回 `STMarkdownPipelineResult`。

<a id="streaming-internals"></a>
## 🌊 流式渲染机制 | Streaming Internals

- **推测重写**：`STMarkdownStructureParser.streamingParser()` 预配置 `STStreamingEmphasisRewriter` 与 `STStreamingTableRewriter`，在流式中间态把未闭合的 `**...`、半截表头等推测为完整结构，避免闪烁；非流式解析保持空 rewriter 以保留完整语义。
- **文本层稳定化**：`STMarkdownStreamingPresenter` / `STMarkdownStreamingTransforms` 裁剪不完整引用标签、稳定半截表格、修正尾部 inline code / emphasis / CJK 边界。AST 层保留结构语义，文本层避免暴露未完成语法。
- **逐字动画**：`STShimmerTextView` 字符级淡入（`characterStaggerInterval = 0.016s`，`tokenFadeDuration` 默认 `0.3s`），使用 `CADisplayLink` 每帧更新 `foregroundColor.alpha`；可切换行级 `CAGradientLayer` mask。附件与标记片段跳过淡入。
- **LaTeX 降级**：`STMarkdownMathNormalizer` 归一化分隔符并以占位符保护数学内部 Markdown 特殊字符，下游调用 `STMarkdownLatexSyntaxNormalizer` 对齐 8 类常见命令降级（如 `\dfrac`→`\frac`、`\implies`→`\Rightarrow`）。

<a id="height-stability"></a>
## 📐 高度稳定 | Height Stability

自适应高度场景（如动态 cell）建议由宿主设置 `preferredContentWidth`，让首帧测量宽度与最终宽度一致。机制组成：

- `STMarkdownBaseTextView.intrinsicContentSize` 使用 `resolvedMarkdownMeasurementWidth()` 测量，`sizeThatFits` 失败时回退 `contentSize.height` / `bounds.height`。
- 宽度来源优先级：`preferredContentWidth` → `bounds.width` → `textView` 宽度 → `window` 宽度 → 屏幕宽度。
- 高度变化通过 `onContentLayoutHeightChange` 回调通知，受 `contentLayoutHeightNotificationThreshold`（默认 9pt）与最小间隔约束，并抑制瞬时 0 高度。
- 动画只改 `foregroundColor.alpha`，追加/替换内容时保存并恢复 `contentOffset`，避免跳动。

<a id="license"></a>
## 📄 许可证 | License

本项目采用 MIT 许可证。

---

**STMarkdown** — a high-fidelity streaming Markdown rendering library for iOS & Swift. Keywords: *iOS, Swift, Markdown, UIKit, Swift Package Manager, streaming, LaTeX, Mermaid, table rendering, code highlighting, NSAttributedString*.
