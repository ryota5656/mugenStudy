// MARK: - View Model

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
    
    private let service: GroqToeicService
    private let firebase: FirebaseService
    private let answerStore: AnswerHistoryStoring
    private var answer: String = ""
    
    init(firebase: FirebaseService = FirebaseService(), answerStore: AnswerHistoryStoring = AnswerHistoryStoreFactory.makeDefault()) {
        let infoPlistKey = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY_1") as? String
        let envKey = ProcessInfo.processInfo.environment["GROQ_API_KEY_1"]
        let apiKey: String = infoPlistKey ?? envKey ?? ""
        self.service = GroqToeicService(apiKey: apiKey)
        self.firebase = firebase
        self.answerStore = answerStore
        if apiKey.isEmpty {
            self.errorMessage = "GROQが未設定です。Info.plist または環境変数に設定してください。"
        }
    }
    
    var currentQuestion: ToeicQuestion? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var isLastQuestion: Bool { currentIndex == max(questions.count - 1, 0) }
    
    func checklatestQuestion() async {
        isLoading = true
        defer { isLoading = false }
        for attempt in 1...2 {
            do {
                let item = try await firebase.fetchQuestions(collection: "toeic_part5_items", limit: 1, source: .cache)
                if item.isEmpty {
                    questions = try await firebase.fetchQuestionsPage(collection: "toeic_part5_items", descending: false, pageSize: 10).items
                    return
                }
                let check = try await firebase.existsNewerThan(collection: "toeic_part5_items", since: item[0].updatedAt)
                if check {
                    questions = try await firebase.fetchQuestionsPage(collection: "toeic_part5_items", from: item[0].updatedAt, descending: false, pageSize: 10).items
                } else {
                    await fetchQuestions()
                }
                return
            } catch {
                if attempt == 2 {
                    self.errorMessage = "最新の問題取得に失敗しました: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
                continue
            }
        }
    }
    
    func fetchQuestions() async {
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
        // 15件を作成。typeは選択済みカテゴリで均等配分し、要素はローダーからランダムに取得
        let total = 10
        let typePool = Array(selectedTypes) // Set -> Array
        // 均等配分（できる限り均等に割り振り、余りは先頭から）
        var counts: [QuestionType: Int] = [:]
        let base = total / max(typePool.count, 1)
        let rem  = total % max(typePool.count, 1)
        for (idx, t) in typePool.enumerated() {
            counts[t] = base + (idx < rem ? 1 : 0)
        }
        // タイプ配列を作成してシャッフル
        var typesForPlans: [QuestionType] = []
        for t in typePool { typesForPlans += Array(repeating: t, count: counts[t] ?? 0) }
        typesForPlans.shuffle()

        // WordsLoader の level は等価一致なので、代表値にマップ
        let levelExact: Int = {
            switch selectedLevel {
            case .l200: return 200
            case .l400: return 400
            case .l600: return 600
            case .l800: return 800
            case .l990: return 990
            }
        }()

        var plans: [ItemPlan] = []
        plans.reserveCapacity(total)
        for i in 0..<total {
            let t: QuestionType = (i < typesForPlans.count) ? typesForPlans[i] : (typePool.randomElement() ?? .grammar)
            // シーンはランダム
            let scene = ScenesLoader.randomLabelAndScene()
            let sceneText = "\(scene?.labelJa ?? "")に関する\(scene?.scene ?? "")のシーンです"

            // grammar/vocabulary の場合のみ付加情報をセット
            let grammarSub: String? = (t == .grammar) ? (CEFRGrammarLoader.randomTopic(for: selectedLevel) ?? GrammarLoader.randomSubcategory()) : nil
            let vocabEntry = (t == .vocabulary) ? ScoreWordsLoader.randomWord(approxScore: levelExact) : nil
            let vocab: ItemPlan.Vocab? = vocabEntry.map { ItemPlan.Vocab(headword: $0.word, meaning: $0.meaning, pos: $0.pos) }
            // partOfSpeech の場合は指定品詞をランダム選択
            let posLabel: String? = {
                guard t == .partOfSpeech else { return nil }
                let posOptions: [(ja: String, en: String)] = [
                    ("名詞", "noun"),
                    ("動詞", "verb"),
                    ("形容詞", "adjective"),
                    ("副詞", "adverb"),
                    ("前置詞", "preposition"),
                    ("接続詞", "conjunction"),
                    ("動詞形", "verb form"),
                    ("代名詞", "pronoun"),
                    ("冠詞", "article"),
                    ("関係詞", "relative pronoun")
                ]
                if let pick = posOptions.randomElement() {
                    return "\(pick.ja) (\(pick.en))"
                }
                return nil
            }()

            plans.append(.init(index: i + 1,
                               type: t,
                               sceneText: sceneText,
                               grammarSubcategory: grammarSub,
                               vocab: vocab,
                               pos: posLabel))
        }
        
//                questions = []
//                currentIndex = 0
//                selectedChoiceIndex = nil
//                showExplanation = false
//                questions = [ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt", choices: ["a", "b", "c", "e"], answerIndex: 0)]
//                questions.append(contentsOf: [
//                    ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt2", choices: ["a", "b", "c", "e"], answerIndex: 0)
//                ])
//                questions.append(contentsOf: [
//                    ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt3", choices: ["a", "b", "c", "e"], answerIndex: 0)
//                ])
//                questions.append(contentsOf: [
//                    ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt4", choices: ["a", "b", "c", "e"], answerIndex: 0)
//                ])
//                questions.append(contentsOf: [
//                    ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt5", choices: ["a", "b", "c", "e"], answerIndex: 0)
//                ])
//                questions.append(contentsOf: [
//                    ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt6", choices: ["a", "b", "c", "e"], answerIndex: 0)
//                ])
//                questions.append(contentsOf: [
//                    ToeicQuestion(id: UUID(), type: .grammar, prompt: "testPrompt7", choices: ["a", "b", "c", "e"], answerIndex: 0)
//                ])
//                return
                
        var lastError: Error? = nil
        for attempt in 1...2 {
            do {
                let items = try await service.generateQuestions(with: plans, level: selectedLevel, types: Array(selectedTypes))
                await MainActor.run {
                    self.questions = items
                    for item in items {
                        print(item.prompt)
                        for (idx, choice) in item.choices.enumerated() {
                            print("#\(idx): \(choice)")
                        }
                    }
                    print(items)
                }
                do {
                    try await firebase.saveQuestions(collection: "toeic_part5_items", items: items, level: levelExact)
                } catch {
                    self.errorMessage = "Firebase保存に失敗しました: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
                return
            } catch {
                lastError = error
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
            let correct = (index == q.answerIndex)
            answerStore.save(questionId: q.id, isCorrect: correct)
        }
    }
    
    func goNext() {
        // 選択結果をRTDBに保存（最終問題でも記録するため早期に実行）
        if let selected = selectedChoiceIndex, currentIndex < questions.count {
            let q = questions[currentIndex]
            Task { await firebase.incrementChoiceCountRTDB(questionId: q.id, choiceIndex: selected) }
        }
        guard currentIndex + 1 < questions.count else { return }
        currentIndex += 1
        selectedChoiceIndex = nil
        showExplanation = false
    }
}

