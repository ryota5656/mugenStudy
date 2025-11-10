import Foundation
import FoundationModels

protocol LanguageModelRepositoryProtocol {
    func streamVocabItems(instructions: String, prompt: String) -> AsyncThrowingStream<VocabItem, Error>
}

@Generable
struct VocabItem: Equatable { // Equatable to allow Optional onChange
    @Guide(description: "6語程度の短い例文") var prompt: String?
    @Guide(description: "promptの自然な日本語訳") var promptJa: String?
}

struct LanguageModelRepository: LanguageModelRepositoryProtocol {
    func streamVocabItems(instructions: String, prompt: String) -> AsyncThrowingStream<VocabItem, Error> {
        if SystemLanguageModel.default.availability != .available {
            return AsyncThrowingStream { continuation in
                continuation.yield(VocabItem(prompt: "現在利用できません", promptJa: nil))
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = session.streamResponse(to: prompt, generating: VocabItem.self)
                    for try await partial in response {
                        let c = partial.content
                        continuation.yield(VocabItem(prompt: c.prompt, promptJa: c.promptJa))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}


