//
//  STMarkdownPreset.swift
//  STBaseProject
//
//  Created by 寒江孤影 on 2019/03/16.
//

import UIKit

public enum STMarkdownPresets {
    public static var `default`: STMarkdownStyle { STMarkdownStyle.default }

    /// 构造一组默认的高级渲染器实例。
    ///
    /// 高级渲染器（图片、表格、代码块等）通常持有内部缓存或可变状态，因此
    /// **每个调用方应单独持有自己的实例**，避免跨场景共享导致的并发污染。
    /// 故采用工厂方法返回新实例，禁止使用全局单例。
    public static func makeDefaultAdvancedRenderers() -> STMarkdownAdvancedRenderers {
        STMarkdownAdvancedRenderers(
            inlineMathRenderer: STMarkdownHighFidelityMathRenderer(),
            blockMathRenderer: STMarkdownHighFidelityMathRenderer(),
            codeBlockRenderer: STMarkdownCodeBlockRenderer(),
            tableRenderer: STMarkdownTableAttachmentRenderer(),
            imageRenderer: STMarkdownAsyncImageRenderer(),
            horizontalRuleRenderer: STMarkdownDefaultHorizontalRuleRenderer()
        )
    }

    public static var article: STMarkdownStyle {
        let font = UIFont.st_preferredFont(ofSize: 17, forTextStyle: .body)
        return STMarkdownStyle(
            font: font,
            dynamicTypeConfiguration: STMarkdownDynamicTypeConfiguration(
                basePointSize: 17,
                textStyle: .body,
                minimumLineHeight: 26
            ),
            textColor: UIColor.label,
            lineHeight: max(26, ceil(font.lineHeight)),
            kern: 0.1,
            paragraphSpacing: 10,
            bodyLineSpacing: 3,
            headingTextColor: UIColor.label,
            linkColor: UIColor.systemBlue,
            inlineCodeTextColor: UIColor.secondaryLabel,
            codeBlockTextColor: UIColor.label,
            codeBlockHeaderTextColor: UIColor.secondaryLabel,
            codeBlockBackgroundColor: UIColor.secondarySystemBackground,
            tableTextColor: UIColor.label,
            tableHeaderTextColor: UIColor.label,
            tableBorderColor: UIColor.separator,
            tableBackgroundColor: UIColor.secondarySystemBackground,
            imagePlaceholderTextColor: UIColor.label,
            imagePlaceholderBackgroundColor: UIColor.tertiarySystemBackground,
            imagePlaceholderCaptionColor: UIColor.secondaryLabel,
            horizontalRuleColor: UIColor.separator,
            horizontalRuleLength: 24,
            listItemSpacing: 10,
            listIndentPerLevel: 16,
            headingLineHeightMultiplier: 1.25
        )
    }

    public static var compact: STMarkdownStyle {
        let font = UIFont.st_preferredFont(ofSize: 14, forTextStyle: .subheadline)
        return STMarkdownStyle(
            font: font,
            dynamicTypeConfiguration: STMarkdownDynamicTypeConfiguration(
                basePointSize: 14,
                textStyle: .subheadline,
                minimumLineHeight: 20
            ),
            textColor: UIColor.label,
            lineHeight: max(20, ceil(font.lineHeight)),
            kern: 0.08,
            paragraphSpacing: 6,
            bodyLineSpacing: 1,
            headingTextColor: UIColor.label,
            linkColor: UIColor.systemBlue,
            inlineCodeTextColor: UIColor.secondaryLabel,
            codeBlockTextColor: UIColor.label,
            codeBlockHeaderTextColor: UIColor.secondaryLabel,
            codeBlockBackgroundColor: UIColor.secondarySystemBackground,
            tableTextColor: UIColor.label,
            tableHeaderTextColor: UIColor.label,
            tableBorderColor: UIColor.separator,
            tableBackgroundColor: UIColor.secondarySystemBackground,
            imagePlaceholderTextColor: UIColor.label,
            imagePlaceholderBackgroundColor: UIColor.tertiarySystemBackground,
            imagePlaceholderCaptionColor: UIColor.secondaryLabel,
            horizontalRuleColor: UIColor.separator,
            horizontalRuleLength: 18,
            listItemSpacing: 6,
            listIndentPerLevel: 12,
            headingLineHeightMultiplier: 1.18
        )
    }
}
