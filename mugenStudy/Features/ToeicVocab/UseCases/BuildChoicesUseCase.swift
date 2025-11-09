import Foundation
import CryptoKit

protocol BuildChoicesUseCaseProtocol {
    func execute(correct: String, pos: String?) -> (choices: [String], correctIndex: Int, wordUUID: UUID)
}

struct DefaultBuildChoicesUseCase: BuildChoicesUseCaseProtocol {
    private let wordsRepository: VocabWordsRepositoryProtocol

    init(wordsRepository: VocabWordsRepositoryProtocol = VocabWordsRepository()) {
        self.wordsRepository = wordsRepository
    }

    func execute(correct: String, pos: String?) -> (choices: [String], correctIndex: Int, wordUUID: UUID) {
        guard !correct.isEmpty else { return ([], 0, UUID()) }

        var pool: [String] = []
        // 優先: 同品詞
        pool.append(contentsOf: wordsRepository.randomMeanings(count: 20, pos: pos))
        // 補完: 任意
        if pool.count < 3 {
            pool.append(contentsOf: wordsRepository.randomMeanings(count: 20, pos: nil))
        }
        let uniqueDummies = Array(
            pool.filter { !$0.isEmpty && $0 != correct }
                .uniqued()
                .prefix(3)
        )
        var options = [correct] + uniqueDummies
        while options.count < 4 { options.append("—") }
        options = Array(options.prefix(4))
        
        let wordUUID = uuidFromWord(word: correct)
        return (options, 0, wordUUID)
    }
    
    func uuidFromWord(word: String) -> UUID {
        let hash = SHA256.hash(data: Data(word.utf8))
        let uuidBytes = Array(hash.prefix(16)) // SHA256は32バイトなので、UUID(16バイト)に縮める
        let uuid = uuidBytes.withUnsafeBytes { ptr in
            UUID(uuid: ptr.load(as: uuid_t.self))
        }
        return uuid
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        var result: [Element] = []
        for e in self { if set.insert(e).inserted { result.append(e) } }
        return result
    }
}


