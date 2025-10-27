import SwiftUI

struct SinglePracticeView: View {
    let question: ToeicQuestion
    @State private var selected: Int? = nil
    @State private var showExplanation: Bool = false
    @State private var displayIndex: [Int] = []
    var onSelect: (_ isCorrect: Bool, _ selectIndex: Int) -> Void
    var onNext: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
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

                }

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
                    if showExplanation, let s = selected {
                        Text(question.filledSentenceJa ?? "")
                            .font(.body)
                            .padding(.top, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
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
                    let textColor: Color = {
                        if isSelected { return .white }
                        return .primary
                    }()
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            selected = choiceIndex
                            showExplanation = true
                        }
                        let isCorrect = (choiceIndex == question.answerIndex)
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

                if showExplanation, let s = selected {
                    let isCorrect = (s == question.answerIndex)
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
                        Button(action: onNext) {
                            Text("次へ")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.baseColor)
                        .padding(.top, 12)
                    }
                }
                
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
            }
            .onChange(of: question.id) { _ in
                displayIndex = Array(0..<question.choices.count)
                displayIndex.shuffle()
                selected = nil
                showExplanation = false
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
