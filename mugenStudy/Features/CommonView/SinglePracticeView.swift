import SwiftUI

struct SinglePracticeView: View {
    let question: ToeicQuestion
    private let historyStore: AnswerHistoryStoring = AnswerHistoryStoreFactory.makeDefault()
    @State private var selected: Int? = nil
    @State private var showExplanation: Bool = false
    @State private var displayIndex: [Int] = []
    @State private var pendingIsCorrect: Bool? = nil
    @State private var recentResults: [Bool] = [] // 過去3回の正誤
    var onSelect: (_ isCorrect: Bool, _ selectIndex: Int) -> Void
    var onNext: (() -> Void)? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerView()
                promptView()
                choicesList()
                explanationView()
            }
            .padding()
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: showExplanation)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: selected)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: displayIndex)
            .onAppear {
                if displayIndex.isEmpty {
                    displayIndex = Array(0..<question.choices.count)
                    displayIndex.shuffle()
                }
                recentResults = historyStore.recentResults(questionId: question.id, limit: 3)
            }
            .onChange(of: question.id) { _ in
                displayIndex = Array(0..<question.choices.count)
                displayIndex.shuffle()
                selected = nil
                showExplanation = false
                recentResults = historyStore.recentResults(questionId: question.id, limit: 3)
            }
        }
    }

    @ViewBuilder
    private func headerView() -> some View {
        HStack {
            Text(question.type.displayName)
                .font(.subheadline)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.baseColor.opacity(0.1))
                .cornerRadius(6)
            if question.type == .word, let hw = question.headword, !hw.isEmpty {
                Text(hw)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.baseColor.opacity(0.12))
                    .cornerRadius(6)
            }
            Spacer()
            if !recentResults.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(recentResults.prefix(3).enumerated()), id: \.offset) { _, ok in
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ok ? Color.baseColor : .red)
                    }
                }
                .accessibilityLabel("直近3回の正誤")
            }
        }
    }

    @ViewBuilder
    private func promptView() -> some View {
        if question.type == .word, let hw = question.headword, !hw.isEmpty {
            Text(TextHighlighter.styled(
                question.prompt,
                keyword: hw,
                baseFont: .title3,
                baseColor: .primary,
                highlightFont: .title2,
                highlightColor: .baseColor
            ))
        } else {
            Text(question.prompt)
                .font(.title3)
        }
        if question.type == .word {
            if showExplanation, selected != nil {
                Text(question.filledSentenceJa ?? "")
                    .font(.body)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func choicesList() -> some View {
        ForEach(Array(displayIndex.enumerated()), id: \.offset) { index, choiceIndex in
            let choice = question.choices[choiceIndex]
            let isSelected = (showExplanation && selected == choiceIndex)
            let isCorrectChoice = (choiceIndex == question.answerIndex)
            let didSelectIncorrect = showExplanation && (selected != nil) && (selected != question.answerIndex)
            let backgroundColor: Color = {
                if isSelected { return isCorrectChoice ? .baseColor : .red }
                if didSelectIncorrect && isCorrectChoice { return .baseColor.opacity(0.2) }
                return .clear
            }()
            let textColor: Color = isSelected ? .white : .primary

            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    selected = choiceIndex
                    showExplanation = true
                }
                let isCorrect = (choiceIndex == question.answerIndex)
                 pendingIsCorrect = isCorrect
                onSelect(isCorrect, choiceIndex)
            }) {
                HStack(alignment: .top) {
                    Text(String(UnicodeScalar(65 + index)!)).bold()
                    Text(choice).multilineTextAlignment(.leading)
                    Spacer()
                }
                .foregroundStyle(textColor)
            }
            .buttonStyle(.bordered)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .disabled(showExplanation)
        }
    }

    @ViewBuilder
    private func explanationView() -> some View {
        if showExplanation, let s = selected {
            let isCorrect = (s == question.answerIndex)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .baseColor : .red)
                    Text(isCorrect ? "正解！" : "不正解").bold()
                }

                if let ex = question.explanation, !ex.isEmpty  {
                    Text("解説: \(ex)")
                        .font(.body)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, maxHeight: 500)
                }
                
                if let en = question.filledSentence, !en.isEmpty {
                    Text("英文：「\(en)")
                        .font(.body)
                        .padding(.top, 4)
                }

                if let ja = question.filledSentenceJa, !ja.isEmpty, !(question.type == .word) {
                    Text("日本語訳：「\(ja)")
                        .font(.body)
                        .padding(.top, 4)
                }
                
                if let translations = question.choiceTranslationsJa, !translations.isEmpty {
                    ForEach(Array(displayIndex.enumerated()), id: \.offset) { index, choiceIndex in
                        Text("選択肢\(String(UnicodeScalar(65 + index)!))：「\(translations.indices.contains(choiceIndex) ? translations[choiceIndex] : "")")
                            .font(.body)
                            .padding(.top, 4)
                    }
                }

                if let onNext {
                    HStack {
                        Spacer()
                        Button(action: {
                            if let pending = pendingIsCorrect {
                                historyStore.save(questionId: question.id, isCorrect: pending)
                            }
                            // 次の問題の履歴は onChange(question.id) で読み込む
                            onNext()
                        }) {
                            Text("次へ")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.baseColor)
                        Spacer()
                    }
                    .padding(.top, 12)
                }
            }
        }
    }
}

#Preview("part5") {
    let sample1 = ToeicQuestion(
        id: UUID(),
        type: .partOfSpeech,
        prompt: "The manager was (____) satisfied with the quarterly results.",
        choices: ["extremely", "extreme", "extremes", "more"],
        answerIndex: 0,
        explanation: "『extremely』は副詞で形容詞『satisfied』を適切に修飾できる。『extreme』は形容詞、『extremes』は名詞複数、『more』は比較級を示す語でこの文法位置には不適切。",
        filledSentence: "The manager was extremely satisfied with the quarterly results.",
        filledSentenceJa: "マネージャーは四半期の結果に非常に満足していた。",
        choiceTranslationsJa: ["非常に", "極端な", "極端なもの", "より"]
    )
    SinglePracticeView(question: sample1, onSelect: { _, _ in })
}

#Preview("word") {
    let sample1 = ToeicQuestion(
        id: UUID(),
        type: .word,
        prompt: "We decided to invest more to accelerate company growth.",
        choices: ["投資する", "借りる", "節約する", "延期する"],
        answerIndex: 0,
        explanation: nil,
        filledSentence: nil,
        filledSentenceJa: "私たちは企業の成長を加速させるために、さらに投資することを決めた。",
        choiceTranslationsJa: nil,
        headword: "invest"
    )
    SinglePracticeView(question: sample1, onSelect: { _, _ in })
}
