import Foundation
internal import Combine
import SwiftUI
import FirebaseFirestore

@MainActor
final class ToeicPart5ViewModel: ObservableObject {
    @Published var selectedLevel: ToeicLevel = .l600
    @Published var selectedTypes: Set<QuestionType> = [.grammar, .partOfSpeech, .vocabulary]
    @Published var isLoading: Bool = false
    @Published var questions: [ToeicQuestion] = []
    @Published var displayChoice: [String] = []
    @Published var currentIndex: Int = 0
    @Published var selectedChoiceIndex: Int? = nil
    @Published var showExplanation: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    
    enum SideEffect { case showInterstitial }
    let sideEffects = PassthroughSubject<SideEffect, Never>()

    private let generateQuestionsUC: GenerateQuestionsUseCase
    private let checkLatestUC: CheckLatestQuestionsUseCase
    private let recordAnswerUC: RecordAnswerUseCase
    private let incrementChoiceUC: IncrementChoiceCountUseCase
    
    init(firebase: FirebaseService = FirebaseService(), answerStore: AnswerHistoryStoring = AnswerHistoryStoreFactory.makeDefault()) {
        let infoPlistKey = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY_1") as? String
        let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY_1"]
        let apiKey: String = infoPlistKey ?? envKey ?? ""
        let groq = GroqToeicService(apiKey: apiKey)
        let questionsRepo = FirebaseQuestionsRepository(service: firebase)
        let answerRepo = AnswerHistoryRepository(store: answerStore)

        self.generateQuestionsUC = GroqGenerateQuestionsUseCase(groq: groq, questionsRepo: questionsRepo)
        self.checkLatestUC = DefaultCheckLatestQuestionsUseCase(questionsRepo: questionsRepo)
        self.recordAnswerUC = DefaultRecordAnswerUseCase(repository: answerRepo)
        self.incrementChoiceUC = DefaultIncrementChoiceCountUseCase(repository: questionsRepo)

        if apiKey.isEmpty {
            self.errorMessage = "GROQが未設定です。Info.plist または環境変数に設定してください。"
        }
    }
    
    var currentQuestion: ToeicQuestion? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var isLastQuestion: Bool { currentIndex == max(questions.count - 1, 0) }
    
    func onTapGenerateLatest() {
        sideEffects.send(.showInterstitial)
        Task { await generateLatestFlow() }
    }

    private func generateLatestFlow() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await checkLatestUC.execute()
            self.questions = items
        } catch {
            self.errorMessage = "最新の問題取得に失敗しました: \(error.localizedDescription)"
            self.showErrorAlert = true
        }
    }
    
    func onTapGenerateAI() {
        sideEffects.send(.showInterstitial)
        Task { await fetchQuestions() }
    }

    private func fetchQuestions() async {
        guard !selectedTypes.isEmpty else {
            self.errorMessage = "出題カテゴリを1つ以上選択してください"
            self.showErrorAlert = true
            return
        }
        isLoading = true
        errorMessage = nil
        questions = []
        currentIndex = 0
        selectedChoiceIndex = nil
        showExplanation = false
        defer { isLoading = false }
        for attempt in 1...2 {
            do {
                let items = try await generateQuestionsUC.execute(level: selectedLevel, types: selectedTypes)
                self.questions = items
                return
            } catch {
                if attempt == 2 {
                    self.errorMessage = "問題の取得に失敗しました: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
                continue
            }
        }
    }
    
    func selectChoice(_ index: Int) {
        selectedChoiceIndex = index
        showExplanation = true
        if let q = currentQuestion {
            recordAnswerUC.execute(question: q, selectedIndex: index)
        }
    }
    
    func goNext() {
        // 選択結果をRTDBに保存（最終問題でも記録するため早期に実行）
        if let selected = selectedChoiceIndex, currentIndex < questions.count {
            let q = questions[currentIndex]
            Task { await incrementChoiceUC.execute(questionId: q.id, choiceIndex: selected) }
        }
        guard currentIndex + 1 < questions.count else { return }
        currentIndex += 1
        selectedChoiceIndex = nil
        showExplanation = false
    }
}

extension ToeicPart5ViewModel: InterstitialAdManagerDelegate {
    func interstitialAdDidDismiss() {
        print("😃：広告が閉じられました！")
    }
}

