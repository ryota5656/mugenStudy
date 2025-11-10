import Foundation
import SwiftUI

// 共通ハイライトユーティリティ
enum TextHighlighter {
    // 英字かどうかの判定
    private static func isLetter(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    // 前後が英字でない（または端）場合のみ一致とみなすレンジを返す
    private static func wholeWordRanges(in source: String, keyword: String, caseInsensitive: Bool) -> [Range<String.Index>] {
        guard !keyword.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []

        var searchRange: Range<String.Index>? = source.startIndex..<source.endIndex
        while let r = source.range(of: keyword, options: options, range: searchRange) {
            var ok = true
            if r.lowerBound > source.startIndex {
                let prev = source[source.index(before: r.lowerBound)]
                if isLetter(prev) { ok = false }
            }
            if r.upperBound < source.endIndex {
                let next = source[r.upperBound]
                if isLetter(next) { ok = false }
            }
            if ok { ranges.append(r) }
            searchRange = r.upperBound..<source.endIndex
        }
        return ranges
    }
    // 単一キーワードを太字化
    static func bolded(_ text: String, keyword: String, caseInsensitive: Bool = true) -> AttributedString {
        bolded(text, keywords: [keyword], caseInsensitive: caseInsensitive)
    }

    // 複数キーワードを太字化
    static func bolded(_ text: String, keywords: [String], caseInsensitive: Bool = true) -> AttributedString {
        var attr = AttributedString(text)
        let source = String(text)
        for key in keywords where !key.isEmpty {
            for r in wholeWordRanges(in: source, keyword: key, caseInsensitive: caseInsensitive) {
                if let ar = Range(r, in: attr) {
                    attr[ar].inlinePresentationIntent = .stronglyEmphasized
                }
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

        if let baseFont { attr.font = baseFont }
        if let baseColor { attr.foregroundColor = baseColor }

        guard !keyword.isEmpty else { return attr }

        for r in wholeWordRanges(in: source, keyword: keyword, caseInsensitive: caseInsensitive) {
            if let ar = Range(r, in: attr) {
                if let highlightFont { attr[ar].font = highlightFont }
                if let highlightColor { attr[ar].foregroundColor = highlightColor }
                attr[ar].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return attr
    }
}
