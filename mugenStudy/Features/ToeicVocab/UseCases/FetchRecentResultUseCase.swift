import Foundation
import CryptoKit

protocol FetchRecentResultUseCaseProtocol {
    func latestIsCorrect(for word: NgslWord) -> Bool?
}

struct DefaultFetchRecentResultUseCase: FetchRecentResultUseCaseProtocol {
    private let historyRepository: AnswerHistoryRepositoryProtocol
    
    init(historyRepository: AnswerHistoryRepositoryProtocol = AnswerHistoryRepository()) {
        self.historyRepository = historyRepository
    }
    
    func latestIsCorrect(for word: NgslWord) -> Bool? {
        let qid = uuidFromWord(word: word.meaning)
        let recent = historyRepository.recentResults(questionId: qid, limit: 1)
        return recent.first
    }
    
    private func uuidFromWord(word: String) -> UUID {
        let hash = SHA256.hash(data: Data(word.utf8))
        let uuidBytes = Array(hash.prefix(16))
        let uuid = uuidBytes.withUnsafeBytes { ptr in
            UUID(uuid: ptr.load(as: uuid_t.self))
        }
        return uuid
    }
}
