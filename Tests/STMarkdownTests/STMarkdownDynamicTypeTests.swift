import XCTest
import STBaseProject
@testable import STMarkdown

/// STMarkdown Dynamic Type 回归测试集, 覆盖审核报告中的核心优化点:
/// - 流式 Markdown 字号切换 -> 会话 / 累计内容 / 显示文本 / 动画状态保持
/// - 代码块 / 表格 / 公式 / 图片附件的 Dynamic Type 重排
/// - 手机小屏 / 手机横竖屏 / iPad 横竖屏 + 标准 / 超大无障碍字号矩阵
final class STMarkdownDynamicTypeTests: XCTestCase {

    private func withTraits<Value>(
        _ traits: UITraitCollection,
        perform body: () -> Value
    ) -> Value {
        var value: Value!
        traits.performAsCurrent {
            value = body()
        }
        return value
    }

    private func attachments(in attributedText: NSAttributedString) -> [NSTextAttachment] {
        var attachments: [NSTextAttachment] = []
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                attachments.append(attachment)
            }
        }
        return attachments
    }

    // MARK: - Markdown 布局矩阵

    func testMarkdownLayoutMatrixAcrossDevicesOrientationsAndContentSizes() {
        let cases: [(name: String, width: CGFloat)] = [
            ("iPhone SE portrait", 320),
            ("iPhone portrait", 393),
            ("iPhone landscape", 852),
            ("iPad portrait", 1024),
            ("iPad landscape", 1366),
        ]
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        let markdown = """
        # Adaptive Layout

        This paragraph deliberately contains enough text to wrap on compact phones while remaining readable on tablets.

        - First semantic item
        - Second semantic item with **emphasis** and [a link](https://example.com)

        > Dynamic Type must trigger a complete text layout pass.
        """

        for testCase in cases {
            let view = STMarkdownTextView(style: .default)
            view.frame = CGRect(x: 0, y: 0, width: testCase.width, height: 1)
            view.preferredContentWidth = testCase.width
            view.refreshDynamicType(compatibleWith: standardTraits)
            view.setMarkdown(markdown)
            let standardSize = view.sizeThatFitsMarkdown(width: testCase.width)

            view.refreshDynamicType(compatibleWith: accessibilityTraits)
            let accessibilitySize = view.sizeThatFitsMarkdown(width: testCase.width)

            XCTAssertEqual(standardSize.width, testCase.width, accuracy: 0.5, testCase.name)
            XCTAssertEqual(accessibilitySize.width, testCase.width, accuracy: 0.5, testCase.name)
            XCTAssertTrue(standardSize.height.isFinite, testCase.name)
            XCTAssertTrue(accessibilitySize.height.isFinite, testCase.name)
            XCTAssertGreaterThan(standardSize.height, 0, testCase.name)
            XCTAssertGreaterThan(accessibilitySize.height, standardSize.height, testCase.name)
        }
    }

    func testMarkdownRerendersAndInvalidatesHeightWhenContentSizeCategoryChanges() throws {
        let view = STMarkdownTextView(style: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        view.preferredContentWidth = 320
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        view.refreshDynamicType(compatibleWith: standardTraits)
        view.setMarkdown("# Dynamic Type\n\n正文需要随系统字号重新排版并增长高度。")

        let beforeFont = try XCTUnwrap(
            view.attributedText.attribute(.font, at: view.attributedText.length - 1, effectiveRange: nil) as? UIFont
        )
        let beforeHeight = view.sizeThatFitsMarkdown(width: 320).height

        view.refreshDynamicType(compatibleWith: accessibilityTraits)

        let afterFont = try XCTUnwrap(
            view.attributedText.attribute(.font, at: view.attributedText.length - 1, effectiveRange: nil) as? UIFont
        )
        let afterHeight = view.sizeThatFitsMarkdown(width: 320).height
        XCTAssertGreaterThan(afterFont.pointSize, beforeFont.pointSize)
        XCTAssertGreaterThan(afterHeight, beforeHeight)
    }

    func testStreamingMarkdownPreservesSessionDuringDynamicTypeRefresh() throws {
        let view = STMarkdownStreamingTextView(style: .default)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        view.preferredContentWidth = 320
        view.tokenFadeDuration = 0
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        view.refreshDynamicType(compatibleWith: standardTraits)

        let markdown = "# Streaming\n\nA completed paragraph that is long enough to be committed safely.\n\n"
        view.beginSmartMarkdownStreaming()
        view.appendSmartMarkdownStreamingChunk(markdown)
        view.finishStreaming()

        let beforeText = view.attributedText.string
        let beforeFont = try XCTUnwrap(
            view.attributedText.attribute(
                .font,
                at: view.attributedText.length - 1,
                effectiveRange: nil
            ) as? UIFont
        )
        XCTAssertTrue(view.isSmartMarkdownStreamingActive)
        XCTAssertEqual(view.smartStreamingAccumulatedText, markdown)

        view.refreshDynamicType(compatibleWith: accessibilityTraits)

        let afterFont = try XCTUnwrap(
            view.attributedText.attribute(
                .font,
                at: view.attributedText.length - 1,
                effectiveRange: nil
            ) as? UIFont
        )
        XCTAssertTrue(view.isSmartMarkdownStreamingActive)
        XCTAssertEqual(view.smartStreamingAccumulatedText, markdown)
        XCTAssertEqual(view.attributedText.string, beforeText)
        XCTAssertTrue(view.isStreamingAnimationIdle)
        XCTAssertGreaterThan(afterFont.pointSize, beforeFont.pointSize)
    }

    func testMarkdownAdvancedAttachmentsRerenderForDynamicType() throws {
        let view = STMarkdownTextView(
            style: .default,
            advancedRenderers: STMarkdownPresets.makeDefaultAdvancedRenderers()
        )
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 1)
        view.preferredContentWidth = 320
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        let markdown = """
        ```swift
        let value = 42
        ```

        | Name | Value |
        | --- | --- |
        | Answer | 42 |

        Inline math: \\(x^2 + y^2\\).

        $$
        x^2 + y^2 = z^2
        $$

        ![sample](https://example.invalid/sample.png)
        """

        view.refreshDynamicType(compatibleWith: standardTraits)
        view.setMarkdown(markdown)
        let beforeAttachments = self.attachments(in: view.attributedText)
        let beforeCode = try XCTUnwrap(beforeAttachments.compactMap { $0 as? STMarkdownCodeBlockAttachment }.first)
        let beforeTable = try XCTUnwrap(beforeAttachments.compactMap { $0 as? STMarkdownTableViewAttachment }.first)
        let beforeHeight = view.sizeThatFitsMarkdown(width: 320).height

        view.refreshDynamicType(compatibleWith: accessibilityTraits)

        let afterAttachments = self.attachments(in: view.attributedText)
        let afterCode = try XCTUnwrap(afterAttachments.compactMap { $0 as? STMarkdownCodeBlockAttachment }.first)
        let afterTable = try XCTUnwrap(afterAttachments.compactMap { $0 as? STMarkdownTableViewAttachment }.first)
        let afterHeight = view.sizeThatFitsMarkdown(width: 320).height

        XCTAssertGreaterThanOrEqual(beforeAttachments.count, 5)
        XCTAssertEqual(afterAttachments.count, beforeAttachments.count)
        XCTAssertFalse(zip(beforeAttachments, afterAttachments).contains { $0 === $1 })
        XCTAssertGreaterThan(afterCode.style.font.pointSize, beforeCode.style.font.pointSize)
        XCTAssertGreaterThan(afterTable.style.font.pointSize, beforeTable.style.font.pointSize)
        XCTAssertGreaterThan(afterHeight, beforeHeight)
        XCTAssertTrue(afterAttachments.allSatisfy {
            $0.bounds.width.isFinite && $0.bounds.height.isFinite
        })
    }

    func testMarkdownPresetsKeepLineHeightAboveFontAtAccessibilitySizes() {
        let accessibilityTraits = UITraitCollection(
            preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
        let presets = [
            STMarkdownPresets.default,
            STMarkdownPresets.article,
            STMarkdownPresets.compact,
        ]

        for preset in presets {
            let resolved = preset.resolvedForDynamicType(compatibleWith: accessibilityTraits)
            XCTAssertGreaterThanOrEqual(resolved.lineHeight, ceil(resolved.font.lineHeight))
        }
    }

    func testMarkdownHeadingFontRespondsToContentSizeCategory() {
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

        let standardFont = self.withTraits(standardTraits) { STMarkdownTypography.headingFont(for: 1) }
        let accessibilityFont = self.withTraits(accessibilityTraits) { STMarkdownTypography.headingFont(for: 1) }

        XCTAssertGreaterThan(accessibilityFont.pointSize, standardFont.pointSize)
    }

    func testMarkdownPresetDoesNotFreezeContentSizeCategory() {
        let standardTraits = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibilityTraits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

        let standardFont = self.withTraits(standardTraits) { STMarkdownPresets.article.font }
        let accessibilityFont = self.withTraits(accessibilityTraits) { STMarkdownPresets.article.font }

        XCTAssertGreaterThan(accessibilityFont.pointSize, standardFont.pointSize)
    }
}
