import SwiftUI
import FoundationModels

struct ToeicVocabularyView: View {
    var range: ClosedRange<Int>? = nil
    @StateObject private var viewModel = ToeicVocabularyViewModel()
    @State private var selectedIndex: Int? = nil
    @State private var choices: [String] = []
    @State private var correctIndex: Int = 0
    @State private var currentQuestion: ToeicQuestion? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let q = currentQuestion {
                    SinglePracticeView(
                        question: q,
                        onSelect: { _, _ in },
                        onNext: { prepareNextQuestion() }
                    )
                } else {
                    Text("下のボタンから問題を生成してください")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Vocabulary Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            if let r = range { viewModel.allowedIndexRange = r }
            prepareNextQuestion()
        }
        .onChange(of: viewModel.output) { _ in
            // 新しい出力が来たら選択肢を生成してリセット
            generateChoices()
            buildQuestion()
        }
        .onChange(of: choices) { _ in buildQuestion() }
        .allowsHitTesting(!viewModel.isLoading)
        .overlay(alignment: .center) {
            if viewModel.isLoading {
                ZStack {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("生成中...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        
    }

    // 次の問題生成（状態の初期化込み）
    private func prepareNextQuestion() {
        
        selectedIndex = nil
        choices = []
        correctIndex = 0
        viewModel.output = nil
        viewModel.prePrompt()
    }

    // 選択肢を生成（正解+ダミー3）
    private func generateChoices() {
        guard let correct = viewModel.selectWord?.meaning, !correct.isEmpty else {
            choices = []
            correctIndex = 0
            return
        }
        // ダミーの意味はNGSLからランダム抽出（pos一致を優先）
        var pool: [String] = []
        if let pos = viewModel.selectWord?.pos {
            let samePos = (NgslWordsLoader.random(count: 20, pos: pos)).map { $0.meaning }
            pool.append(contentsOf: samePos)
        }
        if pool.count < 3 {
            let any = (NgslWordsLoader.random(count: 20)).map { $0.meaning }
            pool.append(contentsOf: any)
        }
        // 正解と同一の意味や空を除外
        let uniqueDummies = Array(
            pool.filter { !$0.isEmpty && $0 != correct }
                .uniqued()
                .prefix(3)
        )
        var options = [correct] + uniqueDummies
        // 足りなければプレースホルダで埋める
        while options.count < 4 { options.append("—") }
        options = Array(options.prefix(4))
        choices = options
//        correctIndex = shuffledChoices.firstIndex(of: correct) ?? 0
    }

    private func buildQuestion() {
        guard let word = viewModel.selectWord, correctIndex < choices.count else {
            currentQuestion = nil
            return
        }
        let id = UUID()
        let promptText = viewModel.output?.prompt ?? ""
        let filledSentenceJa = viewModel.output?.promptJa
        currentQuestion = ToeicQuestion(
            id: id,
            type: .word,
            prompt: promptText,
            choices: choices,
            answerIndex: correctIndex,
            filledSentenceJa: filledSentenceJa,
            choiceTranslationsJa: nil,
            headword: word.word
        )
    }
}

// MARK: - UI Components
private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        var result: [Element] = []
        for e in self {
            if set.insert(e).inserted { result.append(e) }
        }
        return result
    }
}


#Preview {
    ToeicVocabularyView()
}
