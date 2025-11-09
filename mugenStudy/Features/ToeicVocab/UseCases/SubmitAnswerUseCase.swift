import Foundation

protocol SubmitAnswerUseCase {
    func execute(questionId: UUID, isCorrect: Bool)
}

struct DefaultSubmitAnswerUseCase: SubmitAnswerUseCase {
    private let history: AnswerHistoryRepository
    init(history: AnswerHistoryRepository = AnswerHistoryRepository()) {
        self.history = history
    }
    func execute(questionId: UUID, isCorrect: Bool) {
        history.save(questionId: questionId, isCorrect: isCorrect)
    }
}


