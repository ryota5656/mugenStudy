internal import Combine
import Foundation
import SwiftUI
import FoundationModels
import FirebaseFirestore

@Generable
struct VocabItem: Equatable { // Equatable to allow Optional onChange
    @Guide(description: "6語程度の短い例文") var prompt: String?
    @Guide(description: "promptの自然な日本語訳") var promptJa: String?
}

@MainActor
final class ToeicVocabularyViewModel: ObservableObject {
    @Published  var userInput = ""
    @Published  var selectWord: NgslWord?
    @Published  var output: VocabItem?
    @Published  var isLoading = false
    @Published  var instructions = """
        あなたは英語教育のプロです。
        入力された英単語を形を変えずにそのまま使って短い例文とその日本語訳を作ってください。
        """
    // リトライ時に前回タスクを明示的にキャンセル（メモリ解放）させるために変数でタスクを保持
    private var currentTask: Task<Void, Never>? = nil
    // サブレンジ選択で指定されたインデックス範囲（1始まり）
    var allowedIndexRange: ClosedRange<Int>? = nil
    
    func prePrompt() {
        let selectedWord: NgslWord?
        if let range = allowedIndexRange {
            selectedWord = NgslWordsLoader.random(indexRange: range)
        } else {
            selectedWord = NgslWordsLoader.random(category: .frequent3)
        }
        guard let word = selectedWord else { self.isLoading = false; return }
        self.selectWord = word
        print("入力された語彙は「\(word.word)」です。")
        sendPrompt()
    }
    
    // MARK: - プロンプト送信処理（10秒タイムアウト・自動リトライ）
    func sendPrompt() {
        // 前回処理をキャンセルしてから開始
        currentTask = nil
        currentTask?.cancel()

        currentTask = Task { [weak self] in
            guard let self else { return }
            guard let word = self.selectWord else { return }
            self.isLoading = true

            let prompt = "入力された語彙は「\(word.word)」です。"
            guard SystemLanguageModel.default.availability == .available else {
                self.output = VocabItem(prompt: "現在利用できません", promptJa: nil)
                self.isLoading = false
                return
            }
            
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = session.streamResponse(to: prompt, generating: VocabItem.self)
                // ストリーム読取タスク
                let streamTask = Task {
                    for try await partial in response {
                        let c = partial.content
                        print(c)
                        await MainActor.run {
                            self.output = VocabItem(prompt: c.prompt, promptJa: c.promptJa)
                        }
                    }
                }

                // 先に終わった方で決着
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await streamTask.value }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                        streamTask.cancel()   // ← ストリーム読取を明示停止
                        throw CancellationError()
                    }
                    try await group.next()
                    group.cancelAll()
                }

                self.isLoading = false
            } catch {
                // タイムアウト：完全に断ってからリトライ
                self.currentTask = nil
                self.output = VocabItem(prompt: "試行中...", promptJa: nil)
                try? await Task.sleep(nanoseconds: 800_000_000)
                self.prePrompt()
                self.isLoading = false
                return
            }
            self.isLoading = false
        }
    }

    // 共通ユーティリティを利用
    func bolded(_ text: String, keyword: String, caseInsensitive: Bool = true) -> AttributedString {
        TextHighlighter.bolded(text, keyword: keyword, caseInsensitive: caseInsensitive)
    }
}

