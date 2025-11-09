import Foundation

protocol FinishSessionUseCase {
    func execute(total: Int, correct: Int) -> VocabScore
}

struct DefaultFinishSessionUseCase: FinishSessionUseCase {
    func execute(total: Int, correct: Int) -> VocabScore {
        VocabScore(total: total, correct: correct)
    }
}


