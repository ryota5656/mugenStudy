import Foundation
import SwiftUI

// 共通ハイライトユーティリティ
enum TextHighlighter {
    // 単一キーワードを太字化
    static func bolded(_ text: String, keyword: String, caseInsensitive: Bool = true) -> AttributedString {
        bolded(text, keywords: [keyword], caseInsensitive: caseInsensitive)
    }

    // 複数キーワードを太字化
    static func bolded(_ text: String, keywords: [String], caseInsensitive: Bool = true) -> AttributedString {
        var attr = AttributedString(text)
        let source = String(text)
        let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []

        for key in keywords where !key.isEmpty {
            var searchRange: Range<String.Index>? = source.startIndex..<source.endIndex
            while let r = source.range(of: key, options: options, range: searchRange) {
                if let ar = Range(r, in: attr) {
                    attr[ar].inlinePresentationIntent = .stronglyEmphasized
                }
                searchRange = r.upperBound..<source.endIndex
            }
        }
        return attr
    }

    // スタイル付き（フォント/色）で一致箇所を装飾
    static func styled(
        _ text: String,
        keyword: String,
        baseFont: Font? = nil,
        baseColor: Color? = nil,
        highlightFont: Font? = nil,
        highlightColor: Color? = nil,
        caseInsensitive: Bool = true
    ) -> AttributedString {
        var attr = AttributedString(text)
        let source = String(text)
        let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []

        if let baseFont { attr.font = baseFont }
        if let baseColor { attr.foregroundColor = baseColor }

        guard !keyword.isEmpty else { return attr }

        var searchRange: Range<String.Index>? = source.startIndex..<source.endIndex
        while let r = source.range(of: keyword, options: options, range: searchRange) {
            if let ar = Range(r, in: attr) {
                if let highlightFont { attr[ar].font = highlightFont }
                if let highlightColor { attr[ar].foregroundColor = highlightColor }
                attr[ar].inlinePresentationIntent = .stronglyEmphasized
            }
            searchRange = r.upperBound..<source.endIndex
        }
        return attr
    }
}
