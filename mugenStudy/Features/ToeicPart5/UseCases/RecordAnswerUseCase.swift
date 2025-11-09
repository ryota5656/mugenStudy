import Foundation

protocol RecordAnswerUseCase {
    func execute(question: ToeicQuestion, selectedIndex: Int)
}

final class DefaultRecordAnswerUseCase: RecordAnswerUseCase {
    private let repository: AnswerHistoryRepository
    init(repository: AnswerHistoryRepository) {
        self.repository = repository
    }
    func execute(question: ToeicQuestion, selectedIndex: Int) {
        let correct = (selectedIndex == question.answerIndex)
        repository.save(questionId: question.id, isCorrect: correct)
    }
}


