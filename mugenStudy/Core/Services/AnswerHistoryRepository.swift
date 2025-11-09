import Foundation

// MARK: - Repository Protocol
protocol AnswerHistoryRepositoryProtocol {
    func save(questionId: UUID, isCorrect: Bool)
    func recentResults(questionId: UUID, limit: Int) -> [Bool]
    func setFavorite(questionId: UUID, isFavorite: Bool)
    func isFavorite(questionId: UUID) -> Bool
}

// MARK: - Implementation using existing storage abstraction
final class AnswerHistoryRepository: AnswerHistoryRepositoryProtocol {
    private let store: AnswerHistoryStoring
    init(store: AnswerHistoryStoring = AnswerHistoryStoreFactory.makeDefault()) {
        self.store = store
    }
    func save(questionId: UUID, isCorrect: Bool) {
        store.save(questionId: questionId, isCorrect: isCorrect)
    }
    func recentResults(questionId: UUID, limit: Int) -> [Bool] {
        store.recentResults(questionId: questionId, limit: limit)
    }
    func setFavorite(questionId: UUID, isFavorite: Bool) {
        store.setFavorite(questionId: questionId, isFavorite: isFavorite)
    }
    func isFavorite(questionId: UUID) -> Bool {
        store.isFavorite(questionId: questionId)
    }
}

