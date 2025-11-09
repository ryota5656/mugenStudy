import Foundation

protocol GenerateExampleSentenceUseCaseProtocol {
    func stream(selectWord: NgslWord, instructions: String) -> AsyncThrowingStream<VocabItem, Error>
}

struct DefaultGenerateExampleSentenceUseCase: GenerateExampleSentenceUseCaseProtocol {
    private let repository: LanguageModelRepositoryProtocol

    init(repository: LanguageModelRepositoryProtocol = LanguageModelRepository()) {
        self.repository = repository
    }

    func stream(selectWord: NgslWord, instructions: String) -> AsyncThrowingStream<VocabItem, Error> {
        let prompt = "入力された語彙は「\(selectWord.word)」です。"
        return AsyncThrowingStream { continuation in
            Task {
                let maxRetries = 5
                var attempt = 0
                var finished = false
                while attempt < maxRetries && !finished {
                    attempt += 1
                    var last: VocabItem?
                    do {
                        for try await partial in repository.streamVocabItems(instructions: instructions, prompt: prompt) {
                            last = partial
                            continuation.yield(partial)
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                    if let last, containsWholeWord(in: last.prompt ?? "", word: selectWord.word) {
                        finished = true
                    } else {
                        // 次の試行へ（attempt ループ継続）
                    }
                }
                continuation.finish()
            }
        }
    }
}

// 単語境界（前後空白・文頭/文末・簡易句読点）での一致を確認
private func containsWholeWord(in text: String, word: String) -> Bool {
    let escaped = NSRegularExpression.escapedPattern(for: word)
    // 前: 文頭 or 空白 / 後: 空白 or 文末 or 句読点
    let pattern = "(?i)(^|\\s)" + escaped + "(\\s|$|[.,!?;:])"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.firstMatch(in: text, options: [], range: range) != nil
}
