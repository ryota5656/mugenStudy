import Foundation
import CryptoKit

protocol FavoriteWordUseCaseProtocol {
    func setFavorite(for word: NgslWord, isFavorite: Bool)
    func isFavorite(for word: NgslWord) -> Bool
}

struct DefaultFavoriteWordUseCase: FavoriteWordUseCaseProtocol {
    private let repository: AnswerHistoryRepositoryProtocol
    init(repository: AnswerHistoryRepositoryProtocol = AnswerHistoryRepository()) {
        self.repository = repository
    }
    func setFavorite(for word: NgslWord, isFavorite: Bool) {
        let id = uuidFromWord(word: word.meaning)
        repository.setFavorite(questionId: id, isFavorite: isFavorite)
    }
    func isFavorite(for word: NgslWord) -> Bool {
        let id = uuidFromWord(word: word.meaning)
        return repository.isFavorite(questionId: id)
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


