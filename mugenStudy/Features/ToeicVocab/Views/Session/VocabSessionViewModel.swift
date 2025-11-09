import Foundation
import SwiftUI
internal import Combine

@MainActor
final class VocabSessionViewModel: ObservableObject {
    @Published var currentQuestion: ToeicQuestion?
    @Published var isFinished: Bool = false
    @Published var progressText: String = "1/10"
    @Published var correctCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var total: Int = 10
    @Published var range: Int

    private let wordsRepository: VocabWordsRepository
    private let buildChoicesUseCase: BuildChoicesUseCaseProtocol
    private let finishSessionUseCase: FinishSessionUseCase
    private let submitAnswerUseCase: SubmitAnswerUseCase
    private let generateExampleUseCase: GenerateExampleSentenceUseCaseProtocol
    private var wordsQueue: [NgslWord] = []
    // グローバルな進行位置（セッション継続時に次のrangeへ進む）
    private var currentIndex: Int = 0
    // 今バッチの範囲（[batchStartIndex, batchEndExclusive)）
    private var batchStartIndex: Int = 0
    private var batchEndExclusive: Int = 0
    private var category: NgslWordCategory = .essential
    private var allowedIndexRange: ClosedRange<Int>?
    private let instructions = """
    あなたは英語教育のプロです。
    入力された英単語を形を変えずにそのまま使って短い例文とその日本語訳を作ってください。
    """

    init(
        wordsQueue: [NgslWord],
        range: Int = 10,
        wordsRepository: VocabWordsRepository = VocabWordsRepository(),
        buildChoicesUseCase: BuildChoicesUseCaseProtocol = DefaultBuildChoicesUseCase(),
        generateExampleUseCase: GenerateExampleSentenceUseCaseProtocol = DefaultGenerateExampleSentenceUseCase(),
        finishSessionUseCase: FinishSessionUseCase = DefaultFinishSessionUseCase(),
        submitAnswerUseCase: SubmitAnswerUseCase = DefaultSubmitAnswerUseCase(),
    ) {
        self.wordsQueue = wordsQueue
        self.range = range
        self.wordsRepository = wordsRepository
        self.buildChoicesUseCase = buildChoicesUseCase
        self.generateExampleUseCase = generateExampleUseCase
        self.finishSessionUseCase = finishSessionUseCase
        self.submitAnswerUseCase = submitAnswerUseCase
    }

    func start() {
        // 既進行位置から次のrange分だけを今回の出題対象にする
        guard currentIndex < wordsQueue.count else {
            // もう残りがない場合は終了とする
            self.total = 0
            self.progressText = "0/0"
            self.isFinished = true
            self.currentQuestion = nil
            return
        }
        self.batchStartIndex = currentIndex
        self.batchEndExclusive = min(wordsQueue.count, batchStartIndex + max(1, range))
        self.total = batchEndExclusive - batchStartIndex
        self.correctCount = 0
        self.isFinished = false
        self.progressText = self.total > 0 ? "1/\(self.total)" : "0/0"
        loadNextQuestion()
    }

    var hasNextRange: Bool {
        return batchEndExclusive < wordsQueue.count
    }

    func restartSameRange() {
        // 同じバッチの先頭に戻って再度開始
        currentIndex = batchStartIndex
        start()
    }

    func startNextRange() {
        // 次のバッチの先頭から開始（残りがなければ start 内で終了扱い）
        currentIndex = batchEndExclusive
        start()
    }

    private func loadNextQuestion() {
        // 今回のバッチ範囲を超えたら終了
        guard currentIndex < batchEndExclusive else {
            isFinished = true
            currentQuestion = nil
            return
        }
        let word = wordsQueue[currentIndex]
        currentIndex += 1
        isLoading = true
        // 先に選択肢と初期問題を構築（空のプロンプトで表示開始）
        let result = self.buildChoicesUseCase.execute(correct: word.meaning, pos: word.pos)
        let baseQuestion = ToeicQuestion(
            id: result.wordUUID,
            type: .word,
            prompt: "", // streamingで更新
            choices: result.choices,
            answerIndex: result.correctIndex,
            filledSentenceJa: nil,
            choiceTranslationsJa: nil,
            headword: word.word
        )
        self.currentQuestion = baseQuestion

        Task { [weak self] in
            guard let self else { return }
            // ストリームで逐次反映
            do {
                for try await partial in generateExampleUseCase.stream(selectWord: word, instructions: instructions) {
                    // 最新のプロンプトを反映した問題に更新
                    if var q = self.currentQuestion {
                        let updated = ToeicQuestion(
                            id: q.id,
                            type: q.type,
                            prompt: partial.prompt ?? q.prompt,
                            choices: q.choices,
                            answerIndex: q.answerIndex,
                            filledSentenceJa: partial.promptJa ?? q.filledSentenceJa,
                            choiceTranslationsJa: q.choiceTranslationsJa,
                            headword: q.headword
                        )
                        self.currentQuestion = updated
                    }
                }
            } catch {
                
            }
            self.isLoading = false
        }
    }
    
    func submit(choice selectedIndex: Int) {
        guard let q = currentQuestion else { return }
        if selectedIndex == q.answerIndex { correctCount += 1 }
        submitAnswerUseCase.execute(questionId: q.id, isCorrect: selectedIndex == q.answerIndex)
    }

    func next() {
        // バッチ内の現在の出題番号（1-originで表示用）
        let currentNumberInBatch = (currentIndex - batchStartIndex) + 1
        if currentIndex >= batchEndExclusive {
            isFinished = true
            currentQuestion = nil
            progressText = "\(total)/\(total)"
            _ = finishSessionUseCase.execute(total: total, correct: correctCount)
        } else {
            loadNextQuestion()
            let nextNumber = min(currentNumberInBatch + 1, total)
            progressText = "\(nextNumber)/\(total)"
        }
    }
}
