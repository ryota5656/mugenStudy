import Foundation

protocol IncrementChoiceCountUseCase {
    func execute(questionId: UUID, choiceIndex: Int) async
}

final class DefaultIncrementChoiceCountUseCase: IncrementChoiceCountUseCase {
    private let repository: QuestionsRepository
    init(repository: QuestionsRepository) {
        self.repository = repository
    }
    func execute(questionId: UUID, choiceIndex: Int) async {
        await repository.incrementChoice(questionId: questionId, choiceIndex: choiceIndex)
    }
}


