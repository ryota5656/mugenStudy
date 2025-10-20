internal import Combine
import Foundation
import SwiftUI
import FoundationModels
import FirebaseFirestore

@Generable struct VocabItem {
    @Guide(description: "6語程度の短い例文") var prompt: String?
    @Guide(description: "promptの自然な日本語訳") var promptJa: String?

    static var empty: VocabItem { VocabItem(prompt: nil, promptJa: nil) }

    var isEmpty: Bool {
        (prompt == nil || prompt?.isEmpty == true) &&
        (promptJa == nil || promptJa?.isEmpty == true)
    }
}

@MainActor
final class ToeicVocabularyViewModel: ObservableObject {
    @Published  var userInput = ""
    @Published  var selectWord: NgslWord?
    @Published  var output: VocabItem?
    @Published  var isLoading = false
    @Published  var instructions = """
        あなたは英語教育のプロです。
        入力された英単語をそのまま使って短い例文とその日本語訳を作ってください。
        """
    
    // MARK: - プロンプト送信処理
    func sendPrompt() {
        Task {
            guard let word = NgslWordsLoader.random(category: .essential) else { return }
            selectWord = word
            let prompt = "入力された語彙は「\(word.word)」です。"
            
            guard SystemLanguageModel.default.availability == .available else {
                output = VocabItem(prompt: "失敗", promptJa: nil)
                return
            }
            isLoading = true
            do {
                let session = LanguageModelSession(instructions: instructions)
                // Ask the model to produce a VocabItem directly
                let response: LanguageModelSession.Response<VocabItem> = try await session.respond(to: prompt)
                output = response.content
            } catch {
                output = VocabItem(prompt: "エラー：\(error.localizedDescription)", promptJa: nil)
            }
            isLoading = false
        }
    }
    
    func bolded(_ text: String, keyword: String, caseInsensitive: Bool = true) -> AttributedString {
        var attr = AttributedString(text)
        // Use String search to find occurrences, then map to AttributedString ranges
        let source = String(text)
        let options: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
        var searchRange: Range<String.Index>? = source.startIndex..<source.endIndex

        while let r = source.range(of: keyword, options: options, range: searchRange) {
            // Map String range to AttributedString range
            if let ar = Range(r, in: attr) {
                attr[ar].inlinePresentationIntent = .stronglyEmphasized
            }
            searchRange = r.upperBound..<source.endIndex
        }
        return attr
    }
}
